defmodule SymphonyElixirWeb.DashboardLive do
  @moduledoc """
  Live observability dashboard for Symphony.
  """

  use Phoenix.LiveView, layout: {SymphonyElixirWeb.Layouts, :app}

  alias SymphonyElixir.Config
  alias SymphonyElixirWeb.{Endpoint, ObservabilityPubSub, Presenter}
  @runtime_tick_ms 1_000

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:payload, load_payload())
      |> assign(:linear_issue_filter, :in_progress)
      |> assign(:linear_selected_project_key, nil)
      |> assign(:linear_project_source, empty_linear_project_source())
      |> assign(:linear_projects, empty_linear_projects(:in_progress))
      |> assign(:now, DateTime.utc_now())

    socket =
      if connected?(socket) do
        :ok = ObservabilityPubSub.subscribe()
        schedule_runtime_tick()
        refresh_linear_projects(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_info(:runtime_tick, socket) do
    schedule_runtime_tick()
    {:noreply, assign(socket, :now, DateTime.utc_now())}
  end

  @impl true
  def handle_info(:observability_updated, socket) do
    {:noreply,
     socket
     |> assign(:payload, load_payload())
     |> assign(:now, DateTime.utc_now())}
  end

  @impl true
  def handle_event("refresh_linear_projects", _params, socket) do
    {:noreply, refresh_linear_projects(socket)}
  end

  @impl true
  def handle_event("select_linear_status", %{"status" => status}, socket) do
    status_group = linear_status_group(status)

    {:noreply,
     socket
     |> assign(:linear_issue_filter, status_group)
     |> assign(
       :linear_projects,
       filter_linear_projects(
         socket.assigns.linear_project_source,
         status_group,
         socket.assigns.linear_projects[:fetched_at]
       )
     )}
  end

  @impl true
  def handle_event("select_linear_project", %{"project" => project_key}, socket) do
    {:noreply,
     socket
     |> assign(:linear_selected_project_key, project_key)
     |> refresh_linear_projects()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="dashboard-shell">
      <header class="hero-card">
        <div class="hero-grid">
          <div>
            <p class="eyebrow">
              Symphony 관측
            </p>
            <h1 class="hero-title">
              운영 대시보드
            </h1>
            <p class="hero-copy">
              현재 이슈 상태, 재시도 대기, 토큰 사용량, Symphony 실행 상태를 한 화면에서 봅니다.
            </p>
          </div>

          <div class="status-stack">
            <span class="status-badge status-badge-runtime">
              <span class="status-badge-dot"></span>
              <%= runtime_mode_label() %>
            </span>
            <span class="status-badge status-badge-live">
              <span class="status-badge-dot"></span>
              연결됨
            </span>
            <span class="status-badge status-badge-offline">
              <span class="status-badge-dot"></span>
              오프라인
            </span>
          </div>
        </div>
      </header>

      <%= if @payload[:error] do %>
        <section class="error-card">
          <h2 class="error-title">
            스냅샷을 불러오지 못했습니다
          </h2>
          <p class="error-copy">
            <strong><%= @payload.error.code %>:</strong> <%= error_display_message(@payload.error) %>
          </p>
        </section>
      <% else %>
        <section class="metric-grid">
          <article class="metric-card">
            <p class="metric-label">실행 중</p>
            <p class="metric-value numeric"><%= @payload.counts.running %></p>
            <p class="metric-detail">현재 처리 중인 이슈 세션입니다.</p>
          </article>

          <article class="metric-card">
            <p class="metric-label">재시도 대기</p>
            <p class="metric-value numeric"><%= @payload.counts.retrying %></p>
            <p class="metric-detail">다음 재시도 시간을 기다리는 이슈입니다.</p>
          </article>

          <article class="metric-card">
            <p class="metric-label">전체 토큰</p>
            <p class="metric-value numeric"><%= format_int(@payload.codex_totals.total_tokens) %></p>
            <p class="metric-detail numeric">
              입력 <%= format_int(@payload.codex_totals.input_tokens) %> / 출력 <%= format_int(@payload.codex_totals.output_tokens) %>
            </p>
          </article>

          <article class="metric-card">
            <p class="metric-label">누적 작업 시간</p>
            <p class="metric-value numeric"><%= format_runtime_seconds(total_runtime_seconds(@payload, @now)) %></p>
            <p class="metric-detail">이번 Symphony 시작 이후 완료+진행 세션의 벽시계 시간입니다.</p>
          </article>
        </section>

        <.running_sessions_section payload={@payload} now={@now} />

        <section class="section-card status-guide-card">
          <div class="status-guide-layout">
            <article class="status-guide-item">
              <h3 class="status-guide-title">
                <%= if url = linear_web_url() do %>
                  <a href={url} target="_blank" rel="noreferrer">Linear 상태</a>
                <% else %>
                  Linear 상태
                <% end %>
              </h3>
              <p class="status-guide-copy">
                프로젝트별 확인필요, 진행 중, 완료 개수는 Linear API 기준입니다. 상태 카드를 누르면 최초 조회 결과에서 해당 상태의 이슈만 필터링합니다.
              </p>
            </article>

            <article class="status-guide-item">
              <h3 class="status-guide-title">Symphony 실행</h3>
              <p class="status-guide-copy">
                Symphony가 자동으로 잡는 Linear 상태는 WORKFLOW.md의 tracker.active_states 기준입니다.
              </p>
              <div class="status-guide-state-list" aria-label="Symphony pickup 대상 상태">
                <span :for={state <- tracker_active_states()} class={state_badge_class(state)}>
                  <%= state %>
                </span>
              </div>
              <div class="status-guide-rule-list">
                <p>
                  <strong>확인 필요 기준</strong>
                  <span>산출물 누락은 작업 중단 gate가 아닙니다. 권한 부족, 해결 불가한 build 실패, PR 생성 실패, 사람 판단이 필요한 blocker일 때만 <span class={state_badge_class(tracker_retry_exhausted_state())}><%= tracker_retry_exhausted_state() %></span>로 멈춥니다.</span>
                </p>
              </div>
            </article>
          </div>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">Linear 프로젝트 현황</h2>
              <p class="section-copy">프로젝트 목록은 Linear API에서 조회하고, 선택한 프로젝트의 이슈만 표시합니다.</p>
            </div>
            <div class="section-actions">
              <span :if={@linear_projects[:fetched_at]} class="section-meta mono numeric">
                갱신 <%= format_kst_datetime(@linear_projects.fetched_at) %>
              </span>
              <button type="button" class="subtle-button" phx-click="refresh_linear_projects">
                새로고침
              </button>
            </div>
          </div>

          <%= if @linear_projects.status == :error do %>
            <p class="inline-error">
              <strong><%= @linear_projects.error.code %>:</strong> <%= @linear_projects.error.message %>
            </p>
          <% else %>
            <%= if @linear_projects.projects == [] do %>
              <p class="empty-state">조회된 Linear 프로젝트가 없습니다.</p>
            <% else %>
              <div class="linear-project-controls">
                <label class="project-select-label" for="linear-project-select">프로젝트</label>
                <form phx-change="select_linear_project">
                  <select id="linear-project-select" name="project" class="project-select">
                    <option
                      :for={project <- @linear_projects.projects}
                      value={project.key}
                      selected={project.key == @linear_projects.selected_project_key}
                    >
                      <%= project.name %>
                    </option>
                  </select>
                </form>
              </div>

              <% project = @linear_projects.selected_project %>
              <div class="linear-project-stack">
                <%= if is_nil(project) do %>
                  <p class="empty-state">선택된 Linear 프로젝트가 없습니다.</p>
                <% else %>
                  <article class="linear-project">
                    <div class="linear-project-header">
                      <div>
                        <h3 class="linear-project-title">
                          <%= if project.url do %>
                            <a href={project.url} target="_blank" rel="noreferrer"><%= project.name %></a>
                          <% else %>
                            <%= project.name %>
                          <% end %>
                        </h3>
                        <p class="linear-project-meta">
                          <span><%= project.slug || "slug 없음" %></span>
                          <span class="numeric">총 <%= format_int(project.total_count) %>개</span>
                        </p>
                      </div>
                    </div>

                    <div class="project-status-grid" aria-label="프로젝트 상태별 개수">
                      <button
                        :for={group <- project.status_counts}
                        type="button"
                        class={project_status_class(group.key, @linear_issue_filter)}
                        phx-click="select_linear_status"
                        phx-value-status={group.key}
                      >
                        <span class="project-status-label"><%= group.label %></span>
                        <strong class="project-status-count numeric"><%= format_int(group.count) %></strong>
                      </button>
                    </div>

                    <div class="active-workflow-block">
                      <div class="active-workflow-header">
                        <div>
                          <h4 class="active-workflow-title"><%= project.visible_title %></h4>
                          <p class="active-workflow-caption">
                            선택한 프로젝트의 Linear 이슈를 상태와 stage 판단 기준으로 보여줍니다.
                          </p>
                        </div>
                        <span class="active-workflow-count numeric"><%= format_int(length(project.visible_issues)) %>개</span>
                      </div>

                      <%= if project.visible_issues == [] do %>
                        <p class="empty-state">현재 Linear 기준 <%= project.visible_status_label %> 이슈가 없습니다.</p>
                      <% else %>
                        <section class="workflow-issue-panel">
                          <.workflow_issue_table issues={project.visible_issues} />
                        </section>
                      <% end %>
                    </div>
                  </article>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">사용량 제한</h2>
              <p class="section-copy">사용 가능한 경우 마지막 사용량 제한 스냅샷을 표시합니다.</p>
            </div>
          </div>

          <pre class="code-panel"><%= pretty_value(@payload.rate_limits) %></pre>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">재시도 대기열</h2>
              <p class="section-copy">다음 재시도 시간을 기다리는 이슈입니다.</p>
            </div>
          </div>

          <%= if @payload.retrying == [] do %>
            <p class="empty-state">현재 재시도 대기 중인 이슈가 없습니다.</p>
          <% else %>
            <div class="table-wrap">
              <table class="data-table" style="min-width: 680px;">
                <thead>
                  <tr>
                    <th>이슈</th>
                    <th>시도</th>
                    <th>재시도 예정</th>
                    <th>오류</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @payload.retrying}>
                    <td>
                      <div class="issue-stack">
                        <span class="issue-id"><%= entry.issue_identifier %></span>
                        <a class="issue-link" href={"/api/v1/#{entry.issue_identifier}"}>JSON 상세</a>
                      </div>
                    </td>
                    <td><%= entry.attempt %></td>
                    <td class="mono"><%= entry.due_at || "없음" %></td>
                    <td><%= entry.error || "없음" %></td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>
      <% end %>
    </section>
    """
  end

  defp running_sessions_section(assigns) do
    ~H"""
    <section class="section-card">
      <div class="section-header">
        <div>
          <h2 class="section-title">실행 중 세션</h2>
          <p class="section-copy">현재 처리 중인 이슈, 마지막 에이전트 활동, 토큰 사용량입니다.</p>
        </div>
        <div class="section-actions">
          <span class="section-meta"><%= runtime_mode_description() %></span>
        </div>
      </div>

      <%= if @payload.running == [] do %>
        <p class="empty-state">현재 실행 중인 세션이 없습니다.</p>
      <% else %>
        <div class="table-wrap">
          <table class="data-table data-table-running">
            <colgroup>
              <col style="width: 12rem;" />
              <col style="width: 8rem;" />
              <col style="width: 7.5rem;" />
              <col style="width: 8.5rem;" />
              <col />
              <col style="width: 10rem;" />
            </colgroup>
            <thead>
              <tr>
                <th>이슈</th>
                <th>상태</th>
                <th>세션</th>
                <th>소요 시간 / 턴</th>
                <th>Codex 업데이트</th>
                <th>토큰</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={entry <- @payload.running}>
                <td>
                  <div class="issue-stack">
                    <span class="issue-id"><%= entry.issue_identifier %></span>
                    <a class="issue-link" href={"/api/v1/#{entry.issue_identifier}"}>JSON 상세</a>
                  </div>
                </td>
                <td>
                  <span class={state_badge_class(entry.state)}>
                    <%= status_label(entry.state) %>
                  </span>
                </td>
                <td>
                  <div class="session-stack">
                    <%= if entry.session_id do %>
                      <button
                        type="button"
                        class="subtle-button"
                        data-label="ID 복사"
                        data-copy={entry.session_id}
                        onclick="navigator.clipboard.writeText(this.dataset.copy); this.textContent = '복사됨'; clearTimeout(this._copyTimer); this._copyTimer = setTimeout(() => { this.textContent = this.dataset.label }, 1200);"
                      >
                        ID 복사
                      </button>
                    <% else %>
                      <span class="muted">없음</span>
                    <% end %>
                  </div>
                </td>
                <td class="numeric"><%= format_runtime_and_turns(entry.started_at, entry.turn_count, @now) %></td>
                <td>
                  <div class="detail-stack">
                    <span
                      class="event-text"
                      title={entry.last_message || to_string(entry.last_event || "없음")}
                    ><%= entry.last_message || to_string(entry.last_event || "없음") %></span>
                    <span class="muted event-meta">
                      <%= entry.last_event || "없음" %>
                      <%= if entry.last_event_at do %>
                        · <span class="mono numeric"><%= entry.last_event_at %></span>
                      <% end %>
                    </span>
                  </div>
                </td>
                <td>
                  <div class="token-stack numeric">
                    <span>합계: <%= format_int(entry.tokens.total_tokens) %></span>
                    <span class="muted">입력 <%= format_int(entry.tokens.input_tokens) %> / 출력 <%= format_int(entry.tokens.output_tokens) %></span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </section>
    """
  end

  defp load_payload do
    Presenter.state_payload(orchestrator(), snapshot_timeout_ms())
  end

  defp refresh_linear_projects(socket) do
    {linear_projects, linear_project_source} =
      Presenter.linear_project_payload_with_source(
        socket.assigns.linear_issue_filter,
        socket.assigns.linear_selected_project_key
      )

    socket
    |> assign(:linear_projects, linear_projects)
    |> assign(:linear_project_source, linear_project_source)
    |> assign(:linear_selected_project_key, linear_projects[:selected_project_key])
  end

  defp filter_linear_projects(%{} = linear_project_source, status_group, fetched_at) do
    linear_project_source
    |> Presenter.linear_project_payload(status_group)
    |> put_cached_fetched_at(fetched_at)
  end

  defp filter_linear_projects(linear_project_issues, status_group, fetched_at) when is_list(linear_project_issues) do
    linear_project_issues
    |> Presenter.linear_project_payload(status_group)
    |> put_cached_fetched_at(fetched_at)
  end

  defp put_cached_fetched_at(linear_projects, fetched_at) when is_binary(fetched_at) do
    Map.put(linear_projects, :fetched_at, fetched_at)
  end

  defp put_cached_fetched_at(linear_projects, _fetched_at) do
    Map.delete(linear_projects, :fetched_at)
  end

  defp empty_linear_projects(status_group) do
    selected_status_group = linear_status_group(status_group)

    %{
      status: :ok,
      selected_status_group: selected_status_group,
      selected_status_label: linear_status_label(selected_status_group),
      selected_project_key: nil,
      selected_project: nil,
      projects: []
    }
  end

  defp empty_linear_project_source do
    %{projects: [], selected_project_key: nil, issues: []}
  end

  defp workflow_issue_table(assigns) do
    ~H"""
    <div class="workflow-table-wrap">
      <table class="workflow-table">
        <colgroup>
          <col style="width: 20rem;" />
          <col style="width: 7.5rem;" />
          <col style="width: 15rem;" />
          <col />
        </colgroup>
        <thead>
          <tr>
            <th>이슈</th>
            <th>Linear</th>
            <th>현재 게이트</th>
            <th>Stage 판단</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={issue <- @issues}>
            <td>
              <div class="workflow-issue-cell">
                <%= if issue.url do %>
                  <a class="linear-issue-id" href={issue.url} target="_blank" rel="noreferrer"><%= issue.identifier %></a>
                <% else %>
                  <span class="linear-issue-id"><%= issue.identifier %></span>
                <% end %>
                <p class="linear-issue-title" title={issue.title}><%= issue.title %></p>
                <p class="linear-issue-meta">
                  <span><%= issue.assignee_name || "담당 없음" %></span>
                  <span :if={issue.updated_at} class="mono numeric">업데이트 <%= format_kst_datetime(issue.updated_at) %></span>
                </p>
              </div>
            </td>
            <td>
              <span class={state_badge_class(issue.state)}><%= issue.state %></span>
            </td>
            <td>
              <div class="workflow-gate-cell">
                <span class={workflow_gate_class(issue.workflow)}><%= issue.workflow.gate_status %></span>
                <span :if={issue.workflow.current_stage} class="workflow-current-stage">
                  현재 <%= issue.workflow.current_stage_number %>. <%= issue.workflow.current_stage %>
                </span>
              </div>
            </td>
            <td>
              <div class="workflow-progress-cell">
                <div class="workflow-progress-summary">
                  <strong class="numeric">완료 <%= issue.workflow.completed_count %>/<%= issue.workflow.total_count %></strong>
                  <span><%= workflow_run_label(issue.workflow) %></span>
                </div>

                <div class="workflow-stage-strip" aria-label="workflow 증거 단계">
                  <span
                    :for={stage <- issue.workflow.stages}
                    class={workflow_stage_class(stage)}
                    title={workflow_stage_title(stage)}
                  >
                    <%= stage.number %>
                  </span>
                </div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp orchestrator do
    Endpoint.config(:orchestrator) || SymphonyElixir.Orchestrator
  end

  defp snapshot_timeout_ms do
    Endpoint.config(:snapshot_timeout_ms) || 15_000
  end

  defp completed_runtime_seconds(payload) do
    payload.codex_totals.seconds_running || 0
  end

  defp total_runtime_seconds(payload, now) do
    completed_runtime_seconds(payload) +
      Enum.reduce(payload.running, 0, fn entry, total ->
        total + runtime_seconds_from_started_at(entry.started_at, now)
      end)
  end

  defp format_runtime_and_turns(started_at, turn_count, now) when is_integer(turn_count) and turn_count > 0 do
    "#{format_runtime_seconds(runtime_seconds_from_started_at(started_at, now))} / #{turn_count}턴"
  end

  defp format_runtime_and_turns(started_at, _turn_count, now),
    do: format_runtime_seconds(runtime_seconds_from_started_at(started_at, now))

  defp format_runtime_seconds(seconds) when is_number(seconds) do
    whole_seconds = max(trunc(seconds), 0)
    mins = div(whole_seconds, 60)
    secs = rem(whole_seconds, 60)
    "#{mins}분 #{secs}초"
  end

  defp runtime_seconds_from_started_at(%DateTime{} = started_at, %DateTime{} = now) do
    DateTime.diff(now, started_at, :second)
  end

  defp runtime_seconds_from_started_at(started_at, %DateTime{} = now) when is_binary(started_at) do
    case DateTime.from_iso8601(started_at) do
      {:ok, parsed, _offset} -> runtime_seconds_from_started_at(parsed, now)
      _ -> 0
    end
  end

  defp runtime_seconds_from_started_at(_started_at, _now), do: 0

  defp format_int(value) when is_integer(value) do
    value
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0,")
    |> String.reverse()
  end

  defp format_int(_value), do: "없음"

  defp error_display_message(%{code: "snapshot_timeout"}), do: "스냅샷 응답 시간이 초과되었습니다."
  defp error_display_message(%{code: "snapshot_unavailable"}), do: "스냅샷을 사용할 수 없습니다."
  defp error_display_message(%{message: message}) when is_binary(message), do: message
  defp error_display_message(_error), do: "알 수 없는 오류입니다."

  defp state_badge_class(state) do
    base = "state-badge"
    normalized = state |> to_string() |> String.downcase()

    cond do
      String.contains?(normalized, ["progress", "running", "active"]) -> "#{base} state-badge-active"
      String.contains?(normalized, ["blocked", "error", "failed", "확인"]) -> "#{base} state-badge-danger"
      String.contains?(normalized, ["todo", "queued", "pending", "retry"]) -> "#{base} state-badge-warning"
      true -> base
    end
  end

  defp tracker_active_states do
    Config.settings!().tracker.active_states
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp tracker_retry_exhausted_state do
    case Config.settings!().tracker.retry_exhausted_state do
      state when is_binary(state) and state != "" -> state
      _ -> "확인 필요"
    end
  end

  defp runtime_mode_label do
    case tracker_assignee() do
      nil -> "공유 큐"
      "me" -> "로컬 · 내 담당"
      _assignee -> "로컬 · 담당자 필터"
    end
  end

  defp runtime_mode_description do
    case tracker_assignee() do
      nil -> "개발/shared 환경은 담당자 필터 없이 active 상태의 공유 큐를 처리합니다."
      "me" -> "로컬 환경은 Linear viewer 기준으로 내 계정 담당 이슈만 처리합니다."
      _assignee -> "로컬 환경은 설정된 담당자 값과 일치하는 이슈만 처리합니다."
    end
  end

  defp linear_web_url do
    case System.get_env("LINEAR_WEB_URL") do
      value when is_binary(value) ->
        value
        |> String.trim()
        |> then(fn
          "" -> nil
          trimmed -> trimmed
        end)

      _ ->
        nil
    end
  end

  defp tracker_assignee do
    case Config.settings!().tracker.assignee do
      value when is_binary(value) ->
        value
        |> String.trim()
        |> then(fn
          "" -> nil
          trimmed -> trimmed
        end)

      _ ->
        nil
    end
  end

  defp status_label(nil), do: "없음"

  defp status_label(status) do
    normalized = status |> to_string() |> String.downcase()

    cond do
      normalized in ["retrying", "retry"] -> "재시도 대기"
      normalized in ["running", "active"] -> "실행 중"
      normalized in ["in progress", "progress"] -> "진행 중"
      normalized in ["blocked"] -> "확인 필요"
      normalized in ["failed", "error"] -> "실패"
      true -> to_string(status)
    end
  end

  defp linear_status_group("todo"), do: :todo
  defp linear_status_group("in_progress"), do: :in_progress
  defp linear_status_group("done"), do: :done
  defp linear_status_group(:todo), do: :todo
  defp linear_status_group(:in_progress), do: :in_progress
  defp linear_status_group(:done), do: :done
  defp linear_status_group(_status), do: :in_progress

  defp linear_status_label(:todo), do: "확인필요"
  defp linear_status_label(:in_progress), do: "진행 중"
  defp linear_status_label(:done), do: "완료"
  defp linear_status_label(_status_group), do: "진행 중"

  defp project_status_class(group, selected_group) do
    base =
      case group do
        :todo -> "project-status-card project-status-todo"
        :in_progress -> "project-status-card project-status-progress"
        :done -> "project-status-card project-status-done"
        _ -> "project-status-card"
      end

    if group == selected_group do
      base <> " project-status-selected"
    else
      base
    end
  end

  defp workflow_stage_class(%{status: :complete}), do: "workflow-stage-dot workflow-stage-complete"
  defp workflow_stage_class(%{status: :blocked}), do: "workflow-stage-dot workflow-stage-blocked"
  defp workflow_stage_class(%{status: :missing}), do: "workflow-stage-dot workflow-stage-missing"
  defp workflow_stage_class(%{status: :paused}), do: "workflow-stage-dot workflow-stage-paused"
  defp workflow_stage_class(_stage), do: "workflow-stage-dot"

  defp workflow_stage_title(stage) do
    missing =
      case Map.get(stage, :missing_artifacts, []) do
        [] -> ""
        missing_artifacts -> " · 없음: #{Enum.join(missing_artifacts, ", ")}"
      end

    "#{stage.number}. #{stage.label} · #{stage.status_label}#{missing}"
  end

  defp workflow_run_label(%{latest_run: latest_run}) when is_binary(latest_run), do: latest_run
  defp workflow_run_label(%{has_artifact_root: true}), do: "canonical run 없음"
  defp workflow_run_label(_workflow), do: "산출물 없음"

  defp workflow_gate_class(%{gate_status: gate_status}) do
    normalized = gate_status |> to_string() |> String.downcase()

    cond do
      String.contains?(normalized, ["확인", "fail", "block"]) -> "workflow-gate workflow-gate-blocked"
      String.contains?(normalized, ["보류", "대기"]) -> "workflow-gate workflow-gate-paused"
      String.contains?(normalized, ["완료"]) -> "workflow-gate workflow-gate-complete"
      true -> "workflow-gate"
    end
  end

  defp format_kst_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime
        |> DateTime.add(9 * 60 * 60, :second)
        |> format_datetime_fields()
        |> Kernel.<>(" KST")

      _ ->
        value
    end
  end

  defp format_kst_datetime(_value), do: "없음"

  defp format_datetime_fields(datetime) do
    "#{datetime.year}-#{pad2(datetime.month)}-#{pad2(datetime.day)} #{pad2(datetime.hour)}:#{pad2(datetime.minute)}"
  end

  defp pad2(value) when is_integer(value) and value < 10, do: "0#{value}"
  defp pad2(value) when is_integer(value), do: Integer.to_string(value)

  defp schedule_runtime_tick do
    Process.send_after(self(), :runtime_tick, @runtime_tick_ms)
  end

  defp pretty_value(nil), do: "없음"
  defp pretty_value(value), do: inspect(value, pretty: true, limit: :infinity)
end
