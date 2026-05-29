defmodule SymphonyElixirWeb.Presenter do
  @moduledoc """
  Shared projections for the observability API and dashboard.
  """

  alias SymphonyElixir.{ArtifactGate, Config, Orchestrator, StatusDashboard, TddWorkflow}
  alias SymphonyElixir.Linear.{Client, Issue, Project}

  @linear_state_groups [
    %{key: :todo, label: "확인필요"},
    %{key: :in_progress, label: "진행 중"},
    %{key: :done, label: "완료"}
  ]
  @spec state_payload(GenServer.name(), timeout()) :: map()
  def state_payload(orchestrator, snapshot_timeout_ms) do
    generated_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    case Orchestrator.snapshot(orchestrator, snapshot_timeout_ms) do
      %{} = snapshot ->
        %{
          generated_at: generated_at,
          counts: %{
            running: length(snapshot.running),
            retrying: length(snapshot.retrying)
          },
          running: Enum.map(snapshot.running, &running_entry_payload/1),
          retrying: Enum.map(snapshot.retrying, &retry_entry_payload/1),
          codex_totals: snapshot.codex_totals,
          rate_limits: snapshot.rate_limits
        }

      :timeout ->
        %{generated_at: generated_at, error: %{code: "snapshot_timeout", message: "Snapshot timed out"}}

      :unavailable ->
        %{generated_at: generated_at, error: %{code: "snapshot_unavailable", message: "Snapshot unavailable"}}
    end
  end

  @spec issue_payload(String.t(), GenServer.name(), timeout()) :: {:ok, map()} | {:error, :issue_not_found}
  def issue_payload(issue_identifier, orchestrator, snapshot_timeout_ms) when is_binary(issue_identifier) do
    case Orchestrator.snapshot(orchestrator, snapshot_timeout_ms) do
      %{} = snapshot ->
        running = Enum.find(snapshot.running, &(&1.identifier == issue_identifier))
        retry = Enum.find(snapshot.retrying, &(&1.identifier == issue_identifier))

        if is_nil(running) and is_nil(retry) do
          {:error, :issue_not_found}
        else
          {:ok, issue_payload_body(issue_identifier, running, retry)}
        end

      _ ->
        {:error, :issue_not_found}
    end
  end

  @spec refresh_payload(GenServer.name()) :: {:ok, map()} | {:error, :unavailable}
  def refresh_payload(orchestrator) do
    case Orchestrator.request_refresh(orchestrator) do
      :unavailable ->
        {:error, :unavailable}

      payload ->
        {:ok, Map.update!(payload, :requested_at, &DateTime.to_iso8601/1)}
    end
  end

  @spec linear_project_payload(atom() | String.t() | [Issue.t()] | map()) :: map()
  def linear_project_payload(status_group \\ :in_progress)

  def linear_project_payload(all_issues) when is_list(all_issues) do
    linear_project_payload(all_issues, :in_progress)
  end

  def linear_project_payload(%{} = source) do
    linear_project_payload(source, :in_progress)
  end

  def linear_project_payload(status_group) do
    selected_status_group = normalize_project_status_group(status_group)

    case linear_client_module().fetch_projects_with_issues(nil, status_group: :all) do
      {:ok, source} ->
        linear_project_payload(source, selected_status_group)

      {:error, reason} ->
        linear_project_error_payload(selected_status_group, reason)
    end
  end

  @spec linear_project_payload([Issue.t()] | map(), atom() | String.t()) :: map()
  def linear_project_payload(all_issues, status_group) when is_list(all_issues) do
    projects = projects_from_issues(all_issues)
    selected_project_key = projects |> List.first() |> project_key()

    linear_project_payload(projects, all_issues, status_group, selected_project_key)
  end

  def linear_project_payload(%{} = source, status_group) do
    linear_project_payload(
      Map.get(source, :projects, []),
      Map.get(source, :issues, []),
      status_group,
      Map.get(source, :selected_project_key)
    )
  end

  @spec linear_project_payload([Project.t()], [Issue.t()], atom() | String.t(), String.t() | nil) :: map()
  def linear_project_payload(projects, all_issues, status_group, selected_project_key \\ nil)

  def linear_project_payload(projects, all_issues, status_group, selected_project_key)
      when is_list(projects) and is_list(all_issues) do
    selected_status_group = normalize_project_status_group(status_group)
    visible_issues = filter_linear_issues(all_issues, selected_status_group)
    projects = Enum.filter(projects, &match?(%Project{}, &1))
    project_payloads = linear_projects(projects, all_issues, visible_issues, selected_status_group)
    selected_project = selected_linear_project(project_payloads, selected_project_key)

    %{
      status: :ok,
      selected_status_group: selected_status_group,
      selected_status_label: project_status_label(selected_status_group),
      selected_project_key: selected_project && selected_project.key,
      selected_project: selected_project,
      projects: project_payloads,
      fetched_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
  end

  @spec linear_project_payload_with_source(atom() | String.t(), String.t() | nil) :: {map(), map()}
  def linear_project_payload_with_source(status_group \\ :in_progress, selected_project_key \\ nil) do
    selected_status_group = normalize_project_status_group(status_group)

    case linear_client_module().fetch_projects_with_issues(selected_project_key, status_group: :all) do
      {:ok, source} ->
        {linear_project_payload(source, selected_status_group), source}

      {:error, reason} ->
        {linear_project_error_payload(selected_status_group, reason), empty_linear_project_source()}
    end
  end

  defp linear_project_error_payload(selected_status_group, reason) do
    %{
      status: :error,
      selected_status_group: selected_status_group,
      selected_status_label: project_status_label(selected_status_group),
      selected_project_key: nil,
      selected_project: nil,
      projects: [],
      error: %{code: "linear_project_unavailable", message: format_linear_error(reason)}
    }
  end

  defp filter_linear_issues(issues, selected_status_group) when is_list(issues) do
    Enum.filter(issues, &(linear_state_group(&1) == selected_status_group))
  end

  defp empty_linear_project_source do
    %{projects: [], selected_project_key: nil, issues: []}
  end

  defp linear_projects(projects, all_issues, visible_issues, selected_status_group)
       when is_list(projects) and is_list(all_issues) and is_list(visible_issues) do
    all_by_project = Enum.group_by(all_issues, &project_key/1)
    visible_by_project = Enum.group_by(visible_issues, &project_key/1)

    projects
    |> Enum.map(fn project ->
      project_key = project_key(project)

      linear_project(
        project,
        Map.get(all_by_project, project_key, []),
        Map.get(visible_by_project, project_key, []),
        selected_status_group
      )
    end)
    |> Enum.sort_by(&String.downcase(&1.name || ""))
  end

  defp linear_project(%Project{} = project, issues, visible_issues, selected_status_group) do
    grouped = Enum.group_by(issues, &linear_state_group/1)
    visible_issue_payloads = visible_issues |> sort_linear_issues() |> Enum.map(&linear_issue_payload/1)

    status_counts =
      Enum.map(@linear_state_groups, fn %{key: key, label: label} ->
        group_issues =
          grouped
          |> Map.get(key, [])
          |> sort_linear_issues()

        %{
          key: key,
          label: label,
          selected: key == selected_status_group,
          count: length(group_issues)
        }
      end)

    %{
      key: project_key(project),
      name: project.name || "Linear 프로젝트",
      slug: project.slug,
      url: project.url,
      total_count: length(issues),
      status_counts: status_counts,
      visible_status_group: selected_status_group,
      visible_status_label: project_status_label(selected_status_group),
      visible_title: project_visible_title(selected_status_group),
      visible_issues: visible_issue_payloads
    }
  end

  defp projects_from_issues(all_issues) when is_list(all_issues) do
    all_issues
    |> Enum.reduce({[], MapSet.new()}, fn
      %Issue{} = issue, {projects, seen} ->
        project = %Project{
          name: issue.project_name,
          slug: issue.project_slug,
          url: issue.project_url
        }

        key = project_key(project)

        if is_nil(key) or MapSet.member?(seen, key) do
          {projects, seen}
        else
          {[project | projects], MapSet.put(seen, key)}
        end

      _issue, acc ->
        acc
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp selected_linear_project(projects, selected_project_key) when is_list(projects) do
    selected_project_key = normalize_project_key(selected_project_key)

    Enum.find(projects, &(&1.key == selected_project_key)) ||
      List.first(projects)
  end

  defp project_status_label(:todo), do: "확인필요"
  defp project_status_label(:in_progress), do: "진행 중"
  defp project_status_label(:done), do: "완료"
  defp project_status_label(_status_group), do: "진행 중"

  defp project_visible_title(:todo), do: "확인필요 이슈"
  defp project_visible_title(:in_progress), do: "진행 중 워크플로우"
  defp project_visible_title(:done), do: "완료/종료 이슈"
  defp project_visible_title(_status_group), do: "진행 중 워크플로우"

  defp normalize_project_status_group(status_group)
       when status_group in [:todo, :in_progress, :done],
       do: status_group

  defp normalize_project_status_group(status_group) when is_binary(status_group) do
    case String.trim(status_group) do
      "todo" -> :todo
      "in_progress" -> :in_progress
      "done" -> :done
      _ -> :in_progress
    end
  end

  defp normalize_project_status_group(_status_group), do: :in_progress

  defp issue_payload_body(issue_identifier, running, retry) do
    %{
      issue_identifier: issue_identifier,
      issue_id: issue_id_from_entries(running, retry),
      status: issue_status(running, retry),
      workspace: %{
        path: workspace_path(issue_identifier, running, retry),
        host: workspace_host(running, retry)
      },
      attempts: %{
        restart_count: restart_count(retry),
        current_retry_attempt: retry_attempt(retry)
      },
      running: running && running_issue_payload(running),
      retry: retry && retry_issue_payload(retry),
      logs: %{
        codex_session_logs: []
      },
      recent_events: (running && recent_events_payload(running)) || [],
      last_error: retry && retry.error,
      tracked: %{}
    }
  end

  defp issue_id_from_entries(running, retry),
    do: (running && running.issue_id) || (retry && retry.issue_id)

  defp restart_count(retry), do: max(retry_attempt(retry) - 1, 0)
  defp retry_attempt(nil), do: 0
  defp retry_attempt(retry), do: retry.attempt || 0

  defp issue_status(_running, nil), do: "running"
  defp issue_status(nil, _retry), do: "retrying"
  defp issue_status(_running, _retry), do: "running"

  defp running_entry_payload(entry) do
    %{
      issue_id: entry.issue_id,
      issue_identifier: entry.identifier,
      state: entry.state,
      worker_host: Map.get(entry, :worker_host),
      workspace_path: Map.get(entry, :workspace_path),
      session_id: entry.session_id,
      turn_count: Map.get(entry, :turn_count, 0),
      last_event: entry.last_codex_event,
      last_message: summarize_message(entry.last_codex_message),
      started_at: iso8601(entry.started_at),
      last_event_at: iso8601(entry.last_codex_timestamp),
      tokens: %{
        input_tokens: entry.codex_input_tokens,
        output_tokens: entry.codex_output_tokens,
        total_tokens: entry.codex_total_tokens,
        usage_available: Map.get(entry, :codex_token_usage_available, false)
      }
    }
  end

  defp retry_entry_payload(entry) do
    %{
      issue_id: entry.issue_id,
      issue_identifier: entry.identifier,
      attempt: entry.attempt,
      due_at: due_at_iso8601(entry.due_in_ms),
      error: entry.error,
      worker_host: Map.get(entry, :worker_host),
      workspace_path: Map.get(entry, :workspace_path)
    }
  end

  defp running_issue_payload(running) do
    %{
      worker_host: Map.get(running, :worker_host),
      workspace_path: Map.get(running, :workspace_path),
      session_id: running.session_id,
      turn_count: Map.get(running, :turn_count, 0),
      state: running.state,
      started_at: iso8601(running.started_at),
      last_event: running.last_codex_event,
      last_message: summarize_message(running.last_codex_message),
      last_event_at: iso8601(running.last_codex_timestamp),
      tokens: %{
        input_tokens: running.codex_input_tokens,
        output_tokens: running.codex_output_tokens,
        total_tokens: running.codex_total_tokens,
        usage_available: Map.get(running, :codex_token_usage_available, false)
      }
    }
  end

  defp retry_issue_payload(retry) do
    %{
      attempt: retry.attempt,
      due_at: due_at_iso8601(retry.due_in_ms),
      error: retry.error,
      worker_host: Map.get(retry, :worker_host),
      workspace_path: Map.get(retry, :workspace_path)
    }
  end

  defp workspace_path(issue_identifier, running, retry) do
    (running && Map.get(running, :workspace_path)) ||
      (retry && Map.get(retry, :workspace_path)) ||
      Path.join(Config.settings!().workspace.root, issue_identifier)
  end

  defp workspace_host(running, retry) do
    (running && Map.get(running, :worker_host)) || (retry && Map.get(retry, :worker_host))
  end

  defp recent_events_payload(running) do
    [
      %{
        at: iso8601(running.last_codex_timestamp),
        event: running.last_codex_event,
        message: summarize_message(running.last_codex_message)
      }
    ]
    |> Enum.reject(&is_nil(&1.at))
  end

  defp summarize_message(nil), do: nil
  defp summarize_message(message), do: StatusDashboard.humanize_codex_message(message)

  defp due_at_iso8601(due_in_ms) when is_integer(due_in_ms) do
    DateTime.utc_now()
    |> DateTime.add(div(due_in_ms, 1_000), :second)
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp due_at_iso8601(_due_in_ms), do: nil

  defp project_key(%Project{slug: slug}) when is_binary(slug) and slug != "", do: String.trim(slug)
  defp project_key(%Project{id: id}) when is_binary(id) and id != "", do: String.trim(id)
  defp project_key(%Project{name: name}) when is_binary(name) and name != "", do: String.trim(name)
  defp project_key(%Issue{project_slug: slug}) when is_binary(slug) and slug != "", do: slug
  defp project_key(%Issue{project_name: name}) when is_binary(name) and name != "", do: name
  defp project_key(_issue), do: "linear-project"

  defp normalize_project_key(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_project_key(_value), do: nil

  defp sort_linear_issues(issues) do
    Enum.sort_by(issues, &issue_sort_value/1, :desc)
  end

  defp issue_sort_value(%Issue{updated_at: %DateTime{} = updated_at}), do: DateTime.to_unix(updated_at)
  defp issue_sort_value(%Issue{created_at: %DateTime{} = created_at}), do: DateTime.to_unix(created_at)
  defp issue_sort_value(_issue), do: 0

  defp linear_issue_payload(%Issue{} = issue) do
    workflow =
      issue
      |> workflow_payload()
      |> maybe_mark_linear_attention(issue)

    %{
      identifier: issue.identifier,
      title: issue.title || "(제목 없음)",
      url: issue.url,
      state: issue.state || "상태 없음",
      state_type: issue.state_type,
      assignee_name: issue.assignee_name,
      updated_at: iso8601(issue.updated_at),
      labels: issue.labels || [],
      workflow: workflow
    }
  end

  defp workflow_payload(%Issue{identifier: issue_identifier} = issue) when is_binary(issue_identifier) do
    issue_identifier
    |> workflow_payload_for_tier(ArtifactGate.workflow_tier(issue))
  end

  defp workflow_payload(issue_identifier) when is_binary(issue_identifier) do
    workflow_payload_for_tier(issue_identifier, :full)
  end

  defp workflow_payload(_issue_identifier) do
    stages = Enum.map(TddWorkflow.stages(), &workflow_stage_payload([], &1, %{}, %{}))

    %{
      artifact_root: nil,
      tier: :full,
      latest_run: nil,
      has_artifact_root: false,
      completed_count: 0,
      total_count: length(stages),
      current_stage: stages |> List.first() |> stage_label(),
      current_stage_number: stages |> List.first() |> stage_number(),
      gate_status: "산출물 대기",
      root_artifact_count: 0,
      stages: stages
    }
  end

  defp maybe_mark_linear_attention(workflow, %Issue{state: state}) do
    if linear_attention_state?(state) and workflow.latest_run == nil and workflow.completed_count == 0 do
      %{workflow | gate_status: "Linear 상태 확인 필요"}
    else
      workflow
    end
  end

  defp linear_attention_state?(state) do
    state
    |> normalize_linear_state()
    |> String.contains?(["확인", "blocked", "block", "failed", "fail", "error"])
  end

  defp workflow_payload_for_tier(issue_identifier, tier) do
    issue_root = Path.join(artifact_root(), issue_identifier)
    run_dirs = run_dirs(issue_root)
    latest_run = List.first(run_dirs)
    ledger_statuses = stage_ledger_statuses(run_dirs)
    decision_statuses = stage_decision_statuses(run_dirs)
    stage_contracts = workflow_display_stages(tier)
    stages = Enum.map(stage_contracts, &workflow_stage_payload(run_dirs, &1, ledger_statuses, decision_statuses))
    completed_count = Enum.count(stages, &(&1.status == :complete))
    attention_stage = Enum.find(stages, &(&1.status in [:missing, :blocked, :paused]))
    next_stage = attention_stage || Enum.find(stages, &(&1.status != :complete))

    %{
      artifact_root: display_artifact_path(issue_root),
      tier: tier,
      latest_run: latest_run && Path.basename(latest_run),
      has_artifact_root: File.dir?(issue_root),
      completed_count: completed_count,
      total_count: length(stages),
      current_stage: next_stage && next_stage.label,
      current_stage_number: next_stage && next_stage.number,
      gate_status: workflow_gate_status(stages, attention_stage),
      root_artifact_count: root_artifact_count(issue_root),
      stages: stages
    }
  end

  defp stage_label(%{label: label}), do: label
  defp stage_label(_stage), do: nil

  defp stage_number(%{number: number}), do: number
  defp stage_number(_stage), do: nil

  defp workflow_display_stages(:light) do
    [
      display_stage(1, "작업 판단", "executor", [{"legacy summary", ["run-summary.md"]}]),
      display_stage(2, "구현 결과", "executor", [
        {"legacy implementation/result evidence", ["07-implementation.md", "evidence/result.md", "evidence/verification-result.md"]}
      ]),
      display_stage(3, "검증/캡처", "verifier", [
        {"legacy build/smoke/capture evidence",
         [
           "evidence/green.md",
           "evidence/build.md",
           "evidence/smoke.md",
           "evidence/*capture*.md",
           "evidence/*screenshot*.md",
           "evidence/*.png",
           "evidence/*.jpg",
           "evidence/*.jpeg",
           "evidence/*.webp"
         ]}
      ]),
      display_stage(4, "PR/댓글", "git-master", [
        {"legacy PR evidence", ["11-mr.md", "evidence/pr.md", "evidence/linear-comment.md"]}
      ])
    ]
  end

  defp workflow_display_stages(:standard) do
    [
      display_stage(1, "요구/테스트 기준", "analyst, test-engineer", [
        {"requirements/test spec",
         [
           "01-requirements.md",
           "04-test-spec.md",
           "test-spec.md",
           "subagents/01-requirements.md",
           "subagents/04-test-spec.md",
           "subagents/*requirements*.md",
           "subagents/*test-spec*.md",
           "subagents/*spec*.md"
         ]}
      ]),
      display_stage(2, "구현", "executor", [
        {"implementation evidence",
         [
           "07-implementation.md",
           "evidence/result.md",
           "subagents/07-implementation.md",
           "subagents/*implementation*.md",
           "subagents/*executor-result*.md"
         ]}
      ]),
      display_stage(3, "Green/build", "test-engineer", [
        {"green/build evidence",
         [
           "evidence/green.md",
           "evidence/build.md",
           "evidence/smoke.md",
           "subagents/*green*.md",
           "subagents/*build*.md"
         ]}
      ]),
      display_stage(4, "검증", "verifier", [
        {"verification evidence",
         [
           "10-verification.md",
           "evidence/verify.md",
           "evidence/verification-result.md",
           "subagents/*verification*.md",
           "subagents/*verifier-result*.md"
         ]}
      ]),
      display_stage(5, "PR/댓글", "git-master", [
        {"11-mr.md 또는 PR evidence",
         [
           "11-mr.md",
           "evidence/pr.md",
           "evidence/linear-comment.md",
           "subagents/*mr*.md",
           "subagents/*pr*.md",
           "subagents/*git-master*.md"
         ]}
      ])
    ]
  end

  defp workflow_display_stages(_tier), do: TddWorkflow.stages()

  defp display_stage(number, label, owner, artifact_groups) do
    %{
      number: number,
      label: label,
      owner: owner,
      artifact_groups:
        Enum.map(artifact_groups, fn {group_label, patterns} ->
          %{label: group_label, patterns: patterns}
        end)
    }
  end

  defp workflow_stage_payload(run_dirs, stage, ledger_statuses, decision_statuses) do
    missing_artifacts = missing_stage_artifacts(run_dirs, stage.artifact_groups)
    artifact_path = first_present_stage_artifact(run_dirs, display_artifact_groups(stage))
    ledger_status = Map.get(ledger_statuses, stage.number)
    decision = Map.get(decision_statuses, stage.number)
    decision_status = decision && Map.get(decision, :status)
    missing_decision? = map_size(decision_statuses) > 0 and is_nil(decision)
    displayed_missing_artifacts = if missing_decision?, do: ["stage #{stage.number} 판단 기록"], else: missing_artifacts

    status =
      if missing_decision? do
        :missing
      else
        workflow_stage_status(missing_artifacts, ledger_status, artifact_path, decision_status)
      end

    path = (decision && Map.get(decision, :path)) || artifact_path

    %{
      number: stage.number,
      label: stage.label,
      owner: stage.owner,
      status: status,
      status_label: workflow_stage_status_label(status),
      present: status == :complete,
      path: path && display_artifact_path(path),
      missing_artifacts: workflow_stage_missing_artifacts(status, displayed_missing_artifacts),
      updated_at: path && file_updated_at(path)
    }
  end

  defp workflow_stage_status(_missing_artifacts, _ledger_status, _artifact_path, :blocked), do: :blocked
  defp workflow_stage_status(_missing_artifacts, _ledger_status, _artifact_path, :paused), do: :paused
  defp workflow_stage_status(_missing_artifacts, _ledger_status, _artifact_path, :complete), do: :complete
  defp workflow_stage_status(_missing_artifacts, :blocked, _artifact_path, _decision_status), do: :blocked
  defp workflow_stage_status(_missing_artifacts, :paused, _artifact_path, _decision_status), do: :paused
  defp workflow_stage_status(_missing_artifacts, :complete, _artifact_path, _decision_status), do: :complete
  defp workflow_stage_status([], _ledger_status, _artifact_path, _decision_status), do: :complete
  defp workflow_stage_status(_missing_artifacts, _ledger_status, artifact_path, _decision_status) when is_binary(artifact_path), do: :complete
  defp workflow_stage_status(_missing_artifacts, _ledger_status, _artifact_path, _decision_status), do: :missing

  defp workflow_stage_missing_artifacts(:complete, _missing_artifacts), do: []
  defp workflow_stage_missing_artifacts(_status, missing_artifacts), do: missing_artifacts

  defp display_artifact_groups(stage) do
    stage.artifact_groups ++ display_alias_artifact_groups(stage.number)
  end

  defp display_alias_artifact_groups(4) do
    [
      %{
        label: "test-spec.md 또는 spec evidence",
        patterns: ["test-spec.md", "*test-spec*.md", "subagents/*test-spec*.md", "subagents/*spec*.md"]
      }
    ]
  end

  defp display_alias_artifact_groups(8) do
    [
      %{
        label: "evidence/green.md 또는 build/smoke/capture evidence",
        patterns: [
          "evidence/green*.md",
          "evidence/*build*.md",
          "evidence/*smoke*.md",
          "evidence/*capture*.md",
          "evidence/*screenshot*.md",
          "evidence/*.png",
          "evidence/*.jpg",
          "evidence/*.jpeg",
          "evidence/*.webp"
        ]
      }
    ]
  end

  defp display_alias_artifact_groups(11) do
    [
      %{
        label: "11-mr.md 또는 PR/Linear evidence",
        patterns: [
          "11-mr.md",
          "11-knowledge.md",
          "evidence/*pr*.md",
          "evidence/*mr*.md",
          "evidence/*merge*.md",
          "evidence/*linear*.md",
          "evidence/*wiki*.md",
          "evidence/*graph*.md"
        ]
      }
    ]
  end

  defp display_alias_artifact_groups(_stage_number), do: []

  defp workflow_stage_status_label(:complete), do: "완료"
  defp workflow_stage_status_label(:blocked), do: "확인 필요"
  defp workflow_stage_status_label(:paused), do: "보류"
  defp workflow_stage_status_label(:missing), do: "산출물 없음"

  defp workflow_gate_status(_stages, %{status: :missing, label: label}), do: "#{label} 산출물 없음"
  defp workflow_gate_status(_stages, %{status: :blocked, label: label}), do: "#{label} blocker 기록"
  defp workflow_gate_status(_stages, %{status: :paused, label: label}), do: "#{label} 보류 기록"

  defp workflow_gate_status(stages, _blocked_stage) do
    if Enum.all?(stages, &(&1.status == :complete)) do
      "관측 기록 완료"
    else
      "관측 기록 진행 중"
    end
  end

  defp run_dirs(issue_root) do
    issue_root
    |> Path.join("run-*")
    |> Path.wildcard()
    |> Enum.filter(&File.dir?/1)
    |> Enum.sort_by(&run_sort_key/1, :desc)
  end

  defp run_sort_key(path) do
    path
    |> Path.basename()
    |> String.replace_prefix("run-", "")
    |> Integer.parse()
    |> case do
      {number, _rest} -> number
      :error -> 0
    end
  end

  defp first_present_stage_artifact([], _artifact_groups), do: nil

  defp first_present_stage_artifact(run_dirs, artifact_groups) do
    Enum.find_value(run_dirs, fn run_dir ->
      artifact_groups
      |> Enum.flat_map(&matching_artifacts(run_dir, &1.patterns))
      |> Enum.sort()
      |> List.first()
    end)
  end

  defp missing_stage_artifacts([], artifact_groups) do
    Enum.map(artifact_groups, & &1.label)
  end

  defp missing_stage_artifacts(run_dirs, artifact_groups) do
    artifact_groups
    |> Enum.reject(fn artifact_group ->
      Enum.any?(run_dirs, &(matching_artifacts(&1, artifact_group.patterns) != []))
    end)
    |> Enum.map(& &1.label)
  end

  defp matching_artifacts(latest_run, patterns) do
    patterns
    |> Enum.flat_map(fn pattern -> Path.wildcard(Path.join(latest_run, pattern)) end)
    |> Enum.filter(&File.regular?/1)
  end

  defp root_artifact_count(issue_root) do
    issue_root
    |> Path.join("*.md")
    |> Path.wildcard()
    |> Enum.count(&File.regular?/1)
  end

  defp artifact_root do
    Application.get_env(:symphony_elixir, :artifact_root) ||
      Config.settings!().workspace.root
      |> Path.expand()
      |> Path.dirname()
      |> Path.join(".omx/artifacts")
  end

  defp display_artifact_path(path) when is_binary(path) do
    root = artifact_root() |> Path.dirname() |> Path.dirname()
    Path.relative_to(path, root)
  end

  defp file_updated_at(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} ->
        mtime
        |> DateTime.from_unix!()
        |> iso8601()

      _ ->
        nil
    end
  end

  defp stage_decision_statuses([]), do: %{}

  defp stage_decision_statuses(run_dirs) do
    Enum.reduce(run_dirs, %{}, fn run_dir, acc ->
      run_dir
      |> stage_decision_entries()
      |> Enum.reduce(acc, fn decision, acc ->
        if is_integer(decision.number) and decision.status in [:complete, :blocked, :paused] do
          Map.put_new(acc, decision.number, decision)
        else
          acc
        end
      end)
    end)
  end

  defp stage_decision_entries(run_dir) do
    stage_decisions_json(Path.join(run_dir, "stage-decisions.json")) ++
      stage_decisions_jsonl(Path.join(run_dir, "run.jsonl"))
  end

  defp stage_decisions_json(path) do
    with {:ok, body} <- File.read(path),
         {:ok, decoded} <- Jason.decode(body) do
      decoded
      |> extract_stage_decisions()
      |> Enum.map(&normalize_stage_decision(&1, path))
    else
      _other -> []
    end
  end

  defp stage_decisions_jsonl(path) do
    if File.regular?(path) do
      path
      |> File.stream!()
      |> Enum.flat_map(fn line ->
        with {:ok, decoded} <- Jason.decode(line),
             true <- stage_decision_event?(decoded) do
          [normalize_stage_decision(decoded, path)]
        else
          _other -> []
        end
      end)
    else
      []
    end
  end

  defp extract_stage_decisions(%{"stages" => stages}) when is_list(stages), do: stages
  defp extract_stage_decisions(%{"stage_decisions" => stages}) when is_list(stages), do: stages
  defp extract_stage_decisions(%{"decisions" => stages}) when is_list(stages), do: stages

  defp extract_stage_decisions(%{"stages" => stages}) when is_map(stages) do
    Enum.map(stages, fn {number, decision} ->
      decision
      |> ensure_decision_map()
      |> Map.put_new("number", number)
    end)
  end

  defp extract_stage_decisions(stages) when is_list(stages), do: stages
  defp extract_stage_decisions(_decoded), do: []

  defp ensure_decision_map(decision) when is_map(decision), do: decision
  defp ensure_decision_map(status) when is_binary(status), do: %{"status" => status}
  defp ensure_decision_map(_decision), do: %{}

  defp stage_decision_event?(%{} = event) do
    has_stage? = not is_nil(stage_decision_number(event))
    has_status? = stage_decision_status_text(event) != ""

    event_name =
      event
      |> first_present(["event", :event])
      |> decision_text()
      |> String.downcase()

    has_stage? and has_status? and
      (String.contains?(event_name, "stage") or Map.has_key?(event, "stage") or Map.has_key?(event, "stage_number"))
  end

  defp stage_decision_event?(_event), do: false

  defp normalize_stage_decision(decision, path) do
    decision = ensure_decision_map(decision)

    %{
      number: stage_decision_number(decision),
      status: decision |> stage_decision_status_text() |> classify_stage_status(),
      path: path
    }
  end

  defp stage_decision_number(decision) when is_map(decision) do
    decision
    |> first_present(["number", "stage", "stage_number", "stageNumber", :number, :stage, :stage_number])
    |> case do
      nil -> nil
      value -> value |> to_string() |> positive_integer()
    end
    |> case do
      {:ok, number} -> number
      _other -> nil
    end
  end

  defp stage_decision_status_text(decision) when is_map(decision) do
    decision
    |> first_present(["status", "result", "outcome", :status, :result, :outcome])
    |> decision_text()
  end

  defp first_present(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.fetch(map, key) do
        {:ok, value} when not is_nil(value) -> value
        _other -> nil
      end
    end)
  end

  defp decision_text(nil), do: ""
  defp decision_text(value), do: value |> to_string() |> String.trim()

  defp stage_ledger_statuses([]), do: %{}

  defp stage_ledger_statuses(run_dirs) do
    run_dirs
    |> Enum.map(&Path.join(&1, "stage-ledger.md"))
    |> Enum.filter(&File.regular?/1)
    |> Enum.reduce(%{}, fn ledger_path, acc ->
      ledger_path
      |> File.stream!()
      |> Enum.reduce(acc, &put_stage_ledger_status/2)
    end)
  end

  defp put_stage_ledger_status(line, acc) do
    cells =
      line
      |> String.trim()
      |> String.trim_leading("|")
      |> String.trim_trailing("|")
      |> String.split("|")
      |> Enum.map(&String.trim/1)

    with {:ok, number} <- cells |> List.first() |> positive_integer(),
         status when not is_nil(status) <- cells |> stage_status_text() |> classify_stage_status() do
      Map.put_new(acc, number, status)
    else
      _other -> acc
    end
  end

  defp positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number >= 1 ->
        {:ok, number}

      {number, rest} when number >= 1 ->
        if String.trim(rest) == "" or String.starts_with?(String.trim(rest), ".") do
          {:ok, number}
        else
          :error
        end

      _other ->
        :error
    end
  end

  defp positive_integer(_value), do: :error

  defp stage_status_text(cells) when length(cells) >= 10, do: Enum.at(cells, 5)
  defp stage_status_text(cells) when length(cells) >= 5, do: List.last(cells)
  defp stage_status_text(cells) when length(cells) >= 2, do: Enum.at(cells, 1)
  defp stage_status_text(_cells), do: ""

  defp classify_stage_status(text) when is_binary(text) do
    normalized = text |> String.downcase()

    complete? =
      String.contains?(normalized, [
        "pass",
        "done",
        "complete",
        "completed",
        "ok",
        "완료",
        "통과",
        "approve",
        "merge 완료",
        "해당 없음",
        "해당없음",
        "불필요",
        "생략",
        "not applicable",
        "not_applicable",
        "skip"
      ]) or
        Regex.match?(~r/\bn\/a\b/, normalized)

    blocked? = String.contains?(normalized, ["fail", "failed", "blocked", "block", "needs", "실패", "확인 필요", "불가"])
    paused? = String.contains?(normalized, ["보류", "대기"])

    cond do
      complete? ->
        :complete

      blocked? ->
        :blocked

      paused? ->
        :paused

      true ->
        nil
    end
  end

  defp linear_state_group(%Issue{state: state}) do
    normalized_state = normalize_linear_state(state)

    cond do
      normalized_state == "done" -> :done
      normalized_state == "in progress" -> :in_progress
      true -> :todo
    end
  end

  defp normalize_linear_state(value) when is_binary(value) do
    value |> String.trim() |> String.downcase()
  end

  defp normalize_linear_state(_value), do: ""

  defp linear_client_module do
    Application.get_env(:symphony_elixir, :linear_client_module, Client)
  end

  defp format_linear_error(:missing_linear_api_token), do: "Linear API 키가 설정되어 있지 않습니다."
  defp format_linear_error(:missing_linear_api_endpoint), do: "Linear API endpoint가 설정되어 있지 않습니다."
  defp format_linear_error({:linear_api_request, :missing_linear_api_endpoint}), do: "Linear API endpoint가 설정되어 있지 않습니다."
  defp format_linear_error({:linear_graphql_errors, _errors}), do: "Linear GraphQL 응답에 오류가 있습니다."
  defp format_linear_error({:linear_api_status, status}), do: "Linear API가 HTTP #{status}로 응답했습니다."
  defp format_linear_error({:linear_api_request, reason}), do: "Linear API 요청에 실패했습니다: #{inspect(reason)}"
  defp format_linear_error(reason), do: inspect(reason)

  defp iso8601(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp iso8601(_datetime), do: nil
end
