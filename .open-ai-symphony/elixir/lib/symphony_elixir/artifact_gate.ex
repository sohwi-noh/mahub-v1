defmodule SymphonyElixir.ArtifactGate do
  @moduledoc """
  Validates the canonical per-issue workflow artifacts after an agent turn.
  """

  alias SymphonyElixir.{Config, TddWorkflow}
  alias SymphonyElixir.Linear.Issue

  @required_run_files ["run.jsonl", "run-summary.md", "stage-ledger.md"]
  @light_keywords ~w[
    banner 배너 copy 카피 text 문구 color 색상 spacing 간격 align alignment 정렬
    static 정적 mockup 목업 css scss style 스타일
  ]
  @full_keywords ~w[
    backend 백엔드 db database 데이터베이스 schema 스키마 migration 마이그레이션
    auth 인증 authorization 권한 security 보안 e2e integration 통합 api
    queue worker batch 배치 infra 인프라
  ]
  @light_minimum_artifact_groups [
    {"run-summary.md", ["run-summary.md"]},
    {"implementation/result evidence", ["07-implementation.md", "evidence/result.md", "evidence/verification-result.md"]},
    {"build/smoke evidence", ["evidence/green.md", "evidence/build.md", "evidence/smoke.md"]},
    {"capture/result evidence",
     [
       "evidence/*capture*.md",
       "evidence/*screenshot*.md",
       "evidence/*result*.md",
       "evidence/*verification*.md",
       "evidence/*.png",
       "evidence/*.jpg",
       "evidence/*.jpeg",
       "evidence/*.webp"
     ]},
    {"PR evidence", ["11-mr.md", "evidence/pr.md", "evidence/linear-comment.md"]}
  ]
  @standard_minimum_artifact_groups [
    {"run-summary.md", ["run-summary.md"]},
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
     ]},
    {"implementation evidence",
     [
       "07-implementation.md",
       "evidence/result.md",
       "subagents/07-implementation.md",
       "subagents/*implementation*.md",
       "subagents/*executor-result*.md"
     ]},
    {"green/build evidence",
     [
       "evidence/green.md",
       "evidence/build.md",
       "evidence/smoke.md",
       "subagents/*green*.md",
       "subagents/*build*.md"
     ]},
    {"verification evidence",
     [
       "10-verification.md",
       "evidence/verify.md",
       "evidence/verification-result.md",
       "subagents/*verification*.md",
       "subagents/*verifier-result*.md"
     ]},
    {"PR evidence",
     [
       "11-mr.md",
       "evidence/pr.md",
       "evidence/linear-comment.md",
       "subagents/*mr*.md",
       "subagents/*pr*.md",
       "subagents/*git-master*.md"
     ]}
  ]

  @type failure_reason ::
          {:missing_issue_artifact_root, Path.t()}
          | {:missing_canonical_run, Path.t()}
          | {:missing_stage_decisions, Path.t(), atom(), [pos_integer()]}
          | {:blocked_stage_decisions, Path.t(), atom(), [map()]}
          | {:missing_required_artifacts, Path.t(), [String.t()]}
          | {:missing_subagent_artifacts, Path.t()}
          | {:missing_minimum_artifacts, Path.t(), atom(), [String.t()]}
          | {:missing_tdd_stage_artifacts, Path.t(), [map()]}
          | {:missing_tdd_workflow_contract, Path.t()}
          | {:unknown_tdd_stage, term()}
          | {:missing_issue_identifier, term()}

  @spec canonical_run_status(Issue.t() | String.t()) :: :ok | {:error, failure_reason()}
  def canonical_run_status(%Issue{identifier: identifier} = issue) do
    case workflow_tier(issue) do
      :light ->
        decision_or_legacy_run_status(identifier, :light, fn ->
          minimum_run_status(identifier, :light, @light_minimum_artifact_groups)
        end)

      :standard ->
        decision_or_legacy_run_status(identifier, :standard, fn ->
          minimum_run_status(identifier, :standard, @standard_minimum_artifact_groups)
        end)

      :full ->
        decision_or_legacy_run_status(identifier, :full, fn ->
          canonical_run_status(identifier)
        end)
    end
  end

  def canonical_run_status(identifier) when is_binary(identifier) and identifier != "" do
    issue_root = Path.join(artifact_root(), identifier)

    with :ok <- ensure_issue_root(issue_root),
         {:ok, run_dir} <- latest_run_dir(issue_root),
         :ok <- ensure_required_run_files(run_dir),
         :ok <- ensure_subagent_artifacts(run_dir) do
      ensure_tdd_stage_artifacts(run_dir)
    end
  end

  def canonical_run_status(identifier), do: {:error, {:missing_issue_identifier, identifier}}

  @spec next_stage_gate(Issue.t() | String.t()) :: {:ok, map()} | {:error, failure_reason()}
  def next_stage_gate(%Issue{} = issue) do
    {:ok, %{status: :complete, tier: workflow_tier(issue)}}
  end

  def next_stage_gate(identifier) when is_binary(identifier) and identifier != "" do
    issue_root = Path.join(artifact_root(), identifier)

    with :ok <- ensure_issue_root(issue_root),
         {:ok, run_dir} <- latest_run_dir(issue_root) do
      {:ok, next_stage_gate_for_run(run_dir)}
    else
      {:error, {:missing_issue_artifact_root, ^issue_root}} ->
        stage_gate_for_missing_run()

      {:error, {:missing_canonical_run, ^issue_root}} ->
        stage_gate_for_missing_run()

      {:error, reason} ->
        {:error, reason}
    end
  end

  def next_stage_gate(identifier), do: {:error, {:missing_issue_identifier, identifier}}

  @spec stage_gate_status(Issue.t() | String.t(), pos_integer()) :: :ok | {:error, failure_reason()}
  def stage_gate_status(%Issue{}, _stage_number), do: :ok

  def stage_gate_status(identifier, stage_number) when is_binary(identifier) and identifier != "" do
    with {:ok, stage} <- stage_by_number(stage_number),
         issue_root = Path.join(artifact_root(), identifier),
         :ok <- ensure_issue_root(issue_root),
         {:ok, run_dir} <- latest_run_dir(issue_root),
         :ok <- ensure_required_run_files(run_dir),
         :ok <- ensure_subagent_artifacts(run_dir) do
      case missing_stage_artifact_payload(run_dir, stage) do
        nil -> :ok
        missing_stage -> {:error, {:missing_tdd_stage_artifacts, run_dir, [missing_stage]}}
      end
    end
  end

  def stage_gate_status(identifier, _stage_number), do: {:error, {:missing_issue_identifier, identifier}}

  @spec describe_error(failure_reason()) :: String.t()
  def describe_error({:missing_issue_artifact_root, issue_root}) do
    "이슈 artifact root가 없습니다: #{display_path(issue_root)}"
  end

  def describe_error({:missing_canonical_run, issue_root}) do
    "canonical run 디렉터리가 없습니다: #{display_path(Path.join(issue_root, "run-<NNN>"))}"
  end

  def describe_error({:missing_stage_decisions, run_dir, tier, missing_stages}) do
    stages = Enum.map_join(missing_stages, ", ", &to_string/1)
    "workflow #{tier} stage 판단 기록이 없습니다: #{display_path(run_dir)} / stage #{stages}"
  end

  def describe_error({:blocked_stage_decisions, run_dir, tier, blocked_stages}) do
    stages =
      Enum.map_join(blocked_stages, " / ", fn stage ->
        reason = Map.get(stage, :reason) || "사유 없음"
        "#{stage.number}: #{reason}"
      end)

    "workflow #{tier} stage 판단이 확인 필요입니다: #{display_path(run_dir)} / #{stages}"
  end

  def describe_error({:missing_required_artifacts, run_dir, missing_files}) do
    "canonical run 필수 파일이 없습니다: #{display_path(run_dir)} / #{Enum.join(missing_files, ", ")}"
  end

  def describe_error({:missing_subagent_artifacts, run_dir}) do
    "subagent 산출물이 없습니다: #{display_path(Path.join([run_dir, "subagents", "*.md"]))}"
  end

  def describe_error({:missing_minimum_artifacts, run_dir, tier, missing_groups}) do
    "workflow #{tier} 최소 증거가 없습니다: #{display_path(run_dir)} / #{Enum.join(missing_groups, ", ")}"
  end

  def describe_error({:missing_tdd_stage_artifacts, run_dir, missing_stages}) do
    missing =
      Enum.map_join(missing_stages, " / ", fn stage ->
        "#{stage.number}. #{stage.label}: #{Enum.join(stage.missing_artifacts, ", ")}"
      end)

    "TDD workflow 단계 산출물이 없습니다: #{display_path(run_dir)} / #{missing}"
  end

  def describe_error({:missing_tdd_workflow_contract, contract_path}) do
    "TDD workflow contract 문서를 읽을 수 없습니다: #{display_path(contract_path)}"
  end

  def describe_error({:unknown_tdd_stage, stage_number}) do
    "알 수 없는 TDD workflow 단계입니다: #{inspect(stage_number)}"
  end

  def describe_error({:missing_issue_identifier, identifier}) do
    "이슈 identifier가 없어 canonical run 산출물 위치를 계산할 수 없습니다: #{inspect(identifier)}"
  end

  @spec artifact_root() :: Path.t()
  def artifact_root do
    Application.get_env(:symphony_elixir, :artifact_root) ||
      Config.settings!().workspace.root
      |> Path.expand()
      |> Path.dirname()
      |> Path.join(".omx/artifacts")
  end

  @spec display_path(Path.t()) :: String.t()
  def display_path(path) when is_binary(path) do
    root = artifact_root() |> Path.dirname() |> Path.dirname()
    Path.relative_to(path, root)
  end

  defp ensure_issue_root(issue_root) do
    if File.dir?(issue_root) do
      :ok
    else
      {:error, {:missing_issue_artifact_root, issue_root}}
    end
  end

  defp latest_run_dir(issue_root) do
    case run_dirs(issue_root) do
      {:ok, [run_dir | _rest]} -> {:ok, run_dir}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_dirs(issue_root) do
    run_dirs =
      issue_root
      |> Path.join("run-*")
      |> Path.wildcard()
      |> Enum.filter(&File.dir?/1)
      |> Enum.sort_by(&run_sort_key/1, :desc)

    if run_dirs == [] do
      {:error, {:missing_canonical_run, issue_root}}
    else
      {:ok, run_dirs}
    end
  end

  defp ensure_required_run_files(run_dir) do
    missing_files =
      Enum.reject(@required_run_files, fn file_name ->
        File.regular?(Path.join(run_dir, file_name))
      end)

    if missing_files == [] do
      :ok
    else
      {:error, {:missing_required_artifacts, run_dir, missing_files}}
    end
  end

  defp ensure_subagent_artifacts(run_dir) do
    has_subagent_artifact? =
      run_dir
      |> Path.join("subagents/*.md")
      |> Path.wildcard()
      |> Enum.any?(&File.regular?/1)

    if has_subagent_artifact? do
      :ok
    else
      {:error, {:missing_subagent_artifacts, run_dir}}
    end
  end

  defp decision_or_legacy_run_status(identifier, _tier, _legacy_fun)
       when not (is_binary(identifier) and identifier != "") do
    {:error, {:missing_issue_identifier, identifier}}
  end

  defp decision_or_legacy_run_status(identifier, tier, legacy_fun) do
    issue_root = Path.join(artifact_root(), identifier)

    with :ok <- ensure_issue_root(issue_root),
         {:ok, run_dirs} <- run_dirs(issue_root) do
      cond do
        Enum.any?(run_dirs, &(stage_decisions_status(&1, tier) == :ok)) ->
          :ok

        true ->
          case legacy_fun.() do
            :ok ->
              :ok

            {:error, _legacy_reason} ->
              run_dir = List.first(run_dirs)

              case stage_decisions_status(run_dir, tier) do
                {:error, {:blocked_stage_decisions, _run_dir, _tier, _blocked} = reason} ->
                  {:error, reason}

                {:error, {:missing_stage_decisions, _run_dir, _tier, _missing} = reason} ->
                  {:error, reason}

                _other ->
                  {:error, {:missing_stage_decisions, run_dir, tier, decision_stage_numbers(tier)}}
              end
          end
      end
    end
  end

  defp stage_decisions_status(run_dir, tier) do
    required_numbers = decision_stage_numbers(tier)
    decision_map = stage_decision_map(run_dir)

    blocked_stages =
      required_numbers
      |> Enum.map(&Map.get(decision_map, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&decision_blocked?/1)

    complete_numbers =
      decision_map
      |> Enum.filter(fn {number, decision} ->
        number in required_numbers and decision_complete?(decision)
      end)
      |> Enum.map(fn {number, _decision} -> number end)

    missing_numbers = required_numbers -- complete_numbers

    cond do
      blocked_stages != [] ->
        {:error, {:blocked_stage_decisions, run_dir, tier, blocked_stages}}

      missing_numbers == [] ->
        :ok

      true ->
        {:error, {:missing_stage_decisions, run_dir, tier, missing_numbers}}
    end
  end

  defp decision_stage_numbers(:light), do: Enum.to_list(1..4)
  defp decision_stage_numbers(:standard), do: Enum.to_list(1..5)

  defp decision_stage_numbers(:full) do
    case TddWorkflow.stages() do
      [] -> Enum.to_list(1..11)
      stages -> Enum.map(stages, & &1.number)
    end
  end

  defp stage_decision_map(run_dir) do
    run_dir
    |> stage_decisions()
    |> Enum.reject(&(is_nil(&1.number) or is_nil(&1.status)))
    |> Enum.reduce(%{}, fn decision, acc ->
      Map.put(acc, decision.number, decision)
    end)
  end

  defp stage_decisions(run_dir) do
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
    has_stage? = not is_nil(stage_number(event))
    has_status? = decision_status(event) != ""

    event_name =
      event
      |> Map.get("event", Map.get(event, :event, ""))
      |> to_string()
      |> String.downcase()

    has_stage? and has_status? and
      (String.contains?(event_name, "stage") or Map.has_key?(event, "stage") or Map.has_key?(event, "stage_number"))
  end

  defp stage_decision_event?(_event), do: false

  defp normalize_stage_decision(decision, path) do
    decision = ensure_decision_map(decision)

    %{
      number: stage_number(decision),
      status: decision_status(decision),
      reason: decision_reason(decision),
      path: path
    }
  end

  defp stage_number(decision) when is_map(decision) do
    decision
    |> first_present(["number", "stage", "stage_number", "stageNumber", :number, :stage, :stage_number])
    |> parse_positive_integer()
  end

  defp decision_status(decision) when is_map(decision) do
    decision
    |> first_present(["status", "result", "outcome", :status, :result, :outcome])
    |> decision_text()
    |> String.downcase()
  end

  defp decision_reason(decision) when is_map(decision) do
    decision
    |> first_present(["reason", "notes", "note", "summary", :reason, :notes, :note, :summary])
    |> decision_text()
    |> empty_to_nil()
  end

  defp first_present(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.fetch(map, key) do
        {:ok, value} when not is_nil(value) -> value
        _other -> nil
      end
    end)
  end

  defp parse_positive_integer(value) when is_integer(value) and value >= 1, do: value

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {number, _rest} when number >= 1 -> number
      _other -> nil
    end
  end

  defp parse_positive_integer(_value), do: nil

  defp decision_text(nil), do: ""
  defp decision_text(value), do: value |> to_string() |> String.trim()
  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp decision_complete?(%{status: status}) do
    String.contains?(status, [
      "done",
      "complete",
      "completed",
      "pass",
      "passed",
      "ok",
      "skip",
      "skipped",
      "not_applicable",
      "not applicable",
      "n/a",
      "na",
      "해당 없음",
      "해당없음",
      "생략",
      "불필요",
      "완료",
      "통과"
    ])
  end

  defp decision_blocked?(%{status: status}) do
    String.contains?(status, [
      "blocked",
      "block",
      "fail",
      "failed",
      "needs_check",
      "needs check",
      "needs-info",
      "needs info",
      "확인 필요",
      "확인필요",
      "보류",
      "불가",
      "실패"
    ])
  end

  defp minimum_run_status(identifier, _tier, _artifact_groups)
       when not (is_binary(identifier) and identifier != "") do
    {:error, {:missing_issue_identifier, identifier}}
  end

  defp minimum_run_status(identifier, tier, artifact_groups) do
    issue_root = Path.join(artifact_root(), identifier)

    with :ok <- ensure_issue_root(issue_root),
         {:ok, run_dirs} <- run_dirs(issue_root) do
      case Enum.find(run_dirs, &(missing_minimum_artifact_groups(&1, artifact_groups) == [])) do
        nil ->
          latest_run_dir = List.first(run_dirs)
          missing_groups = missing_minimum_artifact_groups(latest_run_dir, artifact_groups)
          {:error, {:missing_minimum_artifacts, latest_run_dir, tier, missing_groups}}

        _run_dir ->
          :ok
      end
    end
  end

  defp missing_minimum_artifact_groups(run_dir, artifact_groups) do
    artifact_groups
    |> Enum.reject(fn {_label, patterns} ->
      Enum.any?(patterns, &has_artifact_pattern?(run_dir, &1))
    end)
    |> Enum.map(fn {label, _patterns} -> label end)
  end

  defp has_artifact_pattern?(run_dir, pattern) do
    run_dir
    |> Path.join(pattern)
    |> Path.wildcard()
    |> Enum.any?(&File.regular?/1)
  end

  defp ensure_tdd_stage_artifacts(run_dir) do
    with {:ok, stages} <- tdd_stages() do
      missing_stages =
        stages
        |> Enum.map(&missing_stage_artifact_payload(run_dir, &1))
        |> Enum.reject(&is_nil/1)

      if missing_stages == [] do
        :ok
      else
        {:error, {:missing_tdd_stage_artifacts, run_dir, missing_stages}}
      end
    end
  end

  defp next_stage_gate_for_run(run_dir) do
    with {:ok, stages} <- tdd_stages() do
      common_missing = missing_required_run_files(run_dir) ++ missing_subagent_marker(run_dir)

      if common_missing == [] do
        next_missing_stage_gate(run_dir, stages)
      else
        stage_gate_payload(run_dir, List.first(stages), missing_common_artifacts: common_missing)
      end
    end
  end

  defp next_missing_stage_gate(run_dir, stages) do
    stages
    |> Enum.find_value(&missing_stage_gate(run_dir, &1))
    |> case do
      nil -> complete_stage_gate(stages)
      stage_gate -> stage_gate
    end
  end

  defp missing_stage_gate(run_dir, stage) do
    case missing_stage_artifact_payload(run_dir, stage) do
      nil -> nil
      missing_stage -> stage_gate_payload(run_dir, stage, missing_artifacts: missing_stage.missing_artifacts)
    end
  end

  defp complete_stage_gate(stages) do
    %{
      status: :complete,
      completed_count: length(stages),
      total_count: length(stages)
    }
  end

  defp stage_gate_payload(run_dir, stage, opts) do
    missing_artifacts =
      Keyword.get_lazy(opts, :missing_artifacts, fn ->
        default_missing_stage_artifacts(run_dir, stage)
      end)

    missing_common_artifacts = Keyword.get(opts, :missing_common_artifacts, [])

    %{
      status: :missing,
      number: stage.number,
      label: stage.label,
      owner: stage.owner,
      required_artifacts: Enum.map(stage.artifact_groups, & &1.label),
      missing_artifacts: missing_artifacts,
      missing_common_artifacts: missing_common_artifacts,
      run_dir: run_dir && display_path(run_dir)
    }
  end

  defp default_missing_stage_artifacts(run_dir, stage) when is_binary(run_dir) do
    case missing_stage_artifact_payload(run_dir, stage) do
      nil -> []
      missing_stage -> missing_stage.missing_artifacts
    end
  end

  defp default_missing_stage_artifacts(_run_dir, stage) do
    Enum.map(stage.artifact_groups, & &1.label)
  end

  defp missing_stage_artifact_payload(run_dir, stage) do
    missing_artifacts =
      stage.artifact_groups
      |> Enum.reject(fn artifact_group ->
        artifact_group.patterns
        |> Enum.flat_map(fn pattern -> Path.wildcard(Path.join(run_dir, pattern)) end)
        |> Enum.any?(&File.regular?/1)
      end)
      |> Enum.map(& &1.label)

    if missing_artifacts == [] do
      nil
    else
      %{
        number: stage.number,
        label: stage.label,
        missing_artifacts: missing_artifacts
      }
    end
  end

  defp missing_required_run_files(run_dir) do
    Enum.reject(@required_run_files, fn file_name ->
      File.regular?(Path.join(run_dir, file_name))
    end)
  end

  defp missing_subagent_marker(run_dir) do
    has_subagent_artifact? =
      run_dir
      |> Path.join("subagents/*.md")
      |> Path.wildcard()
      |> Enum.any?(&File.regular?/1)

    if has_subagent_artifact?, do: [], else: ["subagents/*.md"]
  end

  defp stage_gate_for_missing_run do
    with {:ok, [first_stage | _rest]} <- tdd_stages() do
      {:ok, stage_gate_payload(nil, first_stage, missing_common_artifacts: ["run-<NNN>/"])}
    end
  end

  defp tdd_stages do
    case TddWorkflow.stages() do
      [] -> {:error, {:missing_tdd_workflow_contract, TddWorkflow.contract_path()}}
      stages -> {:ok, stages}
    end
  end

  @spec workflow_tier(Issue.t()) :: :light | :standard | :full
  def workflow_tier(%Issue{} = issue) do
    text = issue_tier_text(issue)

    cond do
      explicit_tier?(text, "light") ->
        :light

      explicit_tier?(text, "full") ->
        :full

      contains_any_keyword?(text, @full_keywords) ->
        :full

      contains_any_keyword?(text, @light_keywords) ->
        :light

      true ->
        :standard
    end
  end

  defp issue_tier_text(%Issue{} = issue) do
    [
      issue.title,
      issue.description,
      issue.labels
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
    |> Enum.join("\n")
    |> String.downcase()
  end

  defp explicit_tier?(text, tier) do
    String.contains?(text, ["workflow-tier: #{tier}", "workflow tier: #{tier}", "tier: #{tier}", "##{tier}"])
  end

  defp contains_any_keyword?(text, keywords) do
    Enum.any?(keywords, &String.contains?(text, &1))
  end

  defp stage_by_number(stage_number) when is_integer(stage_number) do
    with {:ok, stages} <- tdd_stages() do
      case Enum.find(stages, &(&1.number == stage_number)) do
        nil -> {:error, {:unknown_tdd_stage, stage_number}}
        stage -> {:ok, stage}
      end
    end
  end

  defp stage_by_number(stage_number), do: {:error, {:unknown_tdd_stage, stage_number}}

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
end
