defmodule SymphonyElixir.Linear.Client do
  @moduledoc """
  Thin Linear GraphQL client for polling candidate issues.
  """

  require Logger
  alias SymphonyElixir.Config
  alias SymphonyElixir.Linear.{Issue, Project}

  @issue_page_size 50
  @project_page_size 50
  @project_limit 500
  @project_issue_limit 150
  @max_error_body_log_bytes 1_000

  @query """
  query SymphonyLinearPoll($projectSlug: String!, $stateNames: [String!]!, $first: Int!, $relationFirst: Int!, $after: String) {
    issues(filter: {project: {slugId: {eq: $projectSlug}}, state: {name: {in: $stateNames}}}, first: $first, after: $after) {
      nodes {
        id
        identifier
        title
        description
        priority
        state {
          name
          type
        }
        branchName
        url
        project {
          name
          slugId
          url
        }
        assignee {
          id
        }
        creator {
          id
          name
        }
        labels {
          nodes {
            name
          }
        }
        inverseRelations(first: $relationFirst) {
          nodes {
            type
            issue {
              id
              identifier
              state {
                name
                type
              }
            }
          }
        }
        createdAt
        updatedAt
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
  """

  @query_by_ids """
  query SymphonyLinearIssuesById($ids: [ID!]!, $first: Int!, $relationFirst: Int!) {
    issues(filter: {id: {in: $ids}}, first: $first) {
      nodes {
        id
        identifier
        title
        description
        priority
        state {
          name
          type
        }
        branchName
        url
        project {
          name
          slugId
          url
        }
        assignee {
          id
        }
        creator {
          id
          name
        }
        labels {
          nodes {
            name
          }
        }
        inverseRelations(first: $relationFirst) {
          nodes {
            type
            issue {
              id
              identifier
              state {
                name
              }
            }
          }
        }
        createdAt
        updatedAt
      }
    }
  }
  """

  @viewer_query """
  query SymphonyLinearViewer {
    viewer {
      id
    }
  }
  """

  @projects_query """
  query SymphonyLinearProjects($first: Int!, $after: String) {
    projects(first: $first, after: $after) {
      nodes {
        id
        name
        slugId
        url
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
  """

  @project_issues_query """
  query SymphonyLinearProjectIssues($projectSlug: String!, $first: Int!, $after: String) {
    issues(filter: {project: {slugId: {eq: $projectSlug}}}, first: $first, after: $after) {
      nodes {
        id
        identifier
        title
        priority
        state {
          name
          type
        }
        url
        project {
          name
          slugId
          url
        }
        assignee {
          id
          name
        }
        creator {
          id
          name
        }
        labels {
          nodes {
            name
          }
        }
        createdAt
        updatedAt
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
  """

  @spec fetch_candidate_issues() :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_candidate_issues do
    tracker = Config.settings!().tracker

    cond do
      is_nil(tracker.api_key) ->
        {:error, :missing_linear_api_token}

      true ->
        with {:ok, assignee_filter} <- routing_assignee_filter(),
             {:ok, projects} <- fetch_projects() do
          fetch_by_states_for_projects(projects, tracker.active_states, assignee_filter, &graphql/2)
        end
    end
  end

  @spec fetch_issues_by_states([String.t()]) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_issues_by_states(state_names) when is_list(state_names) do
    normalized_states = Enum.map(state_names, &to_string/1) |> Enum.uniq()

    if normalized_states == [] do
      {:ok, []}
    else
      tracker = Config.settings!().tracker

      cond do
        is_nil(tracker.api_key) ->
          {:error, :missing_linear_api_token}

        true ->
          with {:ok, projects} <- fetch_projects() do
            fetch_by_states_for_projects(projects, normalized_states, nil, &graphql/2)
          end
      end
    end
  end

  @spec fetch_projects() :: {:ok, [Project.t()]} | {:error, term()}
  def fetch_projects, do: fetch_projects([])

  @spec fetch_projects(keyword()) :: {:ok, [Project.t()]} | {:error, term()}
  def fetch_projects(opts) when is_list(opts) do
    tracker = Config.settings!().tracker
    limit = Keyword.get(opts, :limit, @project_limit)

    cond do
      limit == 0 ->
        {:ok, []}

      is_nil(tracker.api_key) ->
        {:error, :missing_linear_api_token}

      true ->
        do_fetch_projects(limit, &graphql/2)
    end
  end

  @spec fetch_project_issues() :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_project_issues, do: fetch_project_issues([])

  @spec fetch_project_issues(non_neg_integer() | keyword()) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_project_issues(limit) when is_integer(limit) and limit >= 0 do
    fetch_project_issues(limit: limit)
  end

  def fetch_project_issues(opts) when is_list(opts) do
    tracker = Config.settings!().tracker
    limit = Keyword.get(opts, :limit, @project_issue_limit)
    status_group = normalize_project_status_group(Keyword.get(opts, :status_group, :all))

    cond do
      limit == 0 ->
        {:ok, []}

      is_nil(tracker.api_key) ->
        {:error, :missing_linear_api_token}

      true ->
        with {:ok, projects} <- fetch_projects() do
          fetch_project_issues_for_projects(projects, limit, status_group, &graphql/2)
        end
    end
  end

  @spec fetch_projects_with_issues(String.t() | nil, keyword()) ::
          {:ok, %{projects: [Project.t()], selected_project_key: String.t() | nil, issues: [Issue.t()]}}
          | {:error, term()}
  def fetch_projects_with_issues(selected_project_key \\ nil, opts \\ []) when is_list(opts) do
    tracker = Config.settings!().tracker
    project_limit = Keyword.get(opts, :project_limit, @project_limit)
    issue_limit = Keyword.get(opts, :limit, @project_issue_limit)
    status_group = normalize_project_status_group(Keyword.get(opts, :status_group, :all))

    cond do
      is_nil(tracker.api_key) ->
        {:error, :missing_linear_api_token}

      true ->
        with {:ok, projects} <- fetch_projects(limit: project_limit),
             selected_project <- select_project(projects, selected_project_key),
             {:ok, issues} <- fetch_issues_for_selected_project(selected_project, issue_limit, status_group) do
          {:ok,
           %{
             projects: projects,
             selected_project_key: project_key(selected_project),
             issues: issues
           }}
        end
    end
  end

  @spec fetch_project_issues_for_project(Project.t() | nil, keyword()) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_project_issues_for_project(project, opts \\ [])

  def fetch_project_issues_for_project(nil, _opts), do: {:ok, []}

  def fetch_project_issues_for_project(%Project{} = project, opts) when is_list(opts) do
    tracker = Config.settings!().tracker
    limit = Keyword.get(opts, :limit, @project_issue_limit)
    status_group = normalize_project_status_group(Keyword.get(opts, :status_group, :all))

    cond do
      limit == 0 ->
        {:ok, []}

      is_nil(tracker.api_key) ->
        {:error, :missing_linear_api_token}

      is_nil(project_slug(project)) ->
        {:ok, []}

      true ->
        fetch_project_issues_for_projects([project], limit, status_group, &graphql/2)
    end
  end

  @spec fetch_issue_states_by_ids([String.t()]) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_issue_states_by_ids(issue_ids) when is_list(issue_ids) do
    ids = Enum.uniq(issue_ids)

    case ids do
      [] ->
        {:ok, []}

      ids ->
        with {:ok, assignee_filter} <- routing_assignee_filter() do
          do_fetch_issue_states(ids, assignee_filter)
        end
    end
  end

  @spec graphql(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def graphql(query, variables \\ %{}, opts \\ [])
      when is_binary(query) and is_map(variables) and is_list(opts) do
    payload = build_graphql_payload(query, variables, Keyword.get(opts, :operation_name))
    request_fun = Keyword.get(opts, :request_fun, &post_graphql_request/2)

    with {:ok, headers} <- graphql_headers(),
         {:ok, %{status: 200, body: body}} <- request_fun.(payload, headers) do
      {:ok, body}
    else
      {:ok, response} ->
        Logger.error(
          "Linear GraphQL request failed status=#{response.status}" <>
            linear_error_context(payload, response)
        )

        {:error, {:linear_api_status, response.status}}

      {:error, reason} ->
        Logger.error("Linear GraphQL request failed: #{inspect(reason)}")
        {:error, {:linear_api_request, reason}}
    end
  end

  @doc false
  @spec normalize_issue_for_test(map()) :: Issue.t() | nil
  def normalize_issue_for_test(issue) when is_map(issue) do
    normalize_issue(issue, nil)
  end

  @doc false
  @spec normalize_issue_for_test(map(), String.t() | nil) :: Issue.t() | nil
  def normalize_issue_for_test(issue, assignee) when is_map(issue) do
    assignee_filter =
      case assignee do
        value when is_binary(value) ->
          case build_assignee_filter(value) do
            {:ok, filter} -> filter
            {:error, _reason} -> nil
          end

        _ ->
          nil
      end

    normalize_issue(issue, assignee_filter)
  end

  @doc false
  @spec next_page_cursor_for_test(map()) :: {:ok, String.t()} | :done | {:error, term()}
  def next_page_cursor_for_test(page_info) when is_map(page_info), do: next_page_cursor(page_info)

  @doc false
  @spec merge_issue_pages_for_test([[Issue.t()]]) :: [Issue.t()]
  def merge_issue_pages_for_test(issue_pages) when is_list(issue_pages) do
    issue_pages
    |> Enum.reduce([], &prepend_page_issues/2)
    |> finalize_paginated_issues()
  end

  @doc false
  @spec fetch_projects_for_test(non_neg_integer(), (String.t(), map() -> {:ok, map()} | {:error, term()})) ::
          {:ok, [Project.t()]} | {:error, term()}
  def fetch_projects_for_test(limit, graphql_fun)
      when is_integer(limit) and limit >= 0 and is_function(graphql_fun, 2) do
    do_fetch_projects(limit, graphql_fun)
  end

  @doc false
  @spec fetch_issues_by_states_for_test(
          [Project.t()],
          [String.t()],
          (String.t(), map() -> {:ok, map()} | {:error, term()})
        ) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_issues_by_states_for_test(projects, state_names, graphql_fun)
      when is_list(projects) and is_list(state_names) and is_function(graphql_fun, 2) do
    fetch_by_states_for_projects(projects, state_names, nil, graphql_fun)
  end

  @doc false
  @spec fetch_issue_states_by_ids_for_test([String.t()], (String.t(), map() -> {:ok, map()} | {:error, term()})) ::
          {:ok, [Issue.t()]} | {:error, term()}
  def fetch_issue_states_by_ids_for_test(issue_ids, graphql_fun)
      when is_list(issue_ids) and is_function(graphql_fun, 2) do
    ids = Enum.uniq(issue_ids)

    case ids do
      [] ->
        {:ok, []}

      ids ->
        do_fetch_issue_states(ids, nil, graphql_fun)
    end
  end

  @doc false
  @spec fetch_project_issues_for_test(
          Project.t() | [Project.t()],
          non_neg_integer(),
          (String.t(), map() -> {:ok, map()} | {:error, term()})
        ) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_project_issues_for_test(%Project{} = project, limit, graphql_fun)
      when is_integer(limit) and limit >= 0 and is_function(graphql_fun, 2) do
    fetch_project_issues_for_test([project], limit, [], graphql_fun)
  end

  def fetch_project_issues_for_test(projects, limit, graphql_fun)
      when is_list(projects) and is_integer(limit) and limit >= 0 and is_function(graphql_fun, 2) do
    fetch_project_issues_for_test(projects, limit, [], graphql_fun)
  end

  @spec fetch_project_issues_for_test(
          Project.t() | [Project.t()],
          non_neg_integer(),
          keyword(),
          (String.t(), map() -> {:ok, map()} | {:error, term()})
        ) ::
          {:ok, [Issue.t()]} | {:error, term()}
  def fetch_project_issues_for_test(%Project{} = project, limit, opts, graphql_fun)
      when is_integer(limit) and limit >= 0 and is_list(opts) and is_function(graphql_fun, 2) do
    fetch_project_issues_for_test([project], limit, opts, graphql_fun)
  end

  def fetch_project_issues_for_test(projects, limit, opts, graphql_fun)
      when is_list(projects) and is_integer(limit) and limit >= 0 and is_list(opts) and is_function(graphql_fun, 2) do
    fetch_project_issues_for_projects(
      projects,
      limit,
      normalize_project_status_group(Keyword.get(opts, :status_group, :all)),
      graphql_fun
    )
  end

  defp do_fetch_projects(limit, graphql_fun) do
    do_fetch_projects_page(limit, graphql_fun, nil, [])
  end

  defp do_fetch_projects_page(remaining, _graphql_fun, _after_cursor, acc_projects)
       when remaining <= 0 do
    {:ok, acc_projects |> finalize_paginated_issues() |> dedupe_projects()}
  end

  defp do_fetch_projects_page(remaining, graphql_fun, after_cursor, acc_projects) do
    first = min(@project_page_size, remaining)

    case graphql_fun.(@projects_query, %{first: first, after: after_cursor}) do
      {:ok, body} ->
        with {:ok, projects, page_info} <- decode_project_page_response(body) do
          updated_acc = prepend_page_issues(projects, acc_projects)
          remaining = remaining - length(projects)

          case next_page_cursor(page_info) do
            {:ok, next_cursor} ->
              do_fetch_projects_page(remaining, graphql_fun, next_cursor, updated_acc)

            :done ->
              {:ok, updated_acc |> finalize_paginated_issues() |> dedupe_projects()}

            {:error, reason} ->
              {:error, reason}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_by_states_for_projects(projects, state_names, assignee_filter, graphql_fun) do
    projects
    |> project_slugs()
    |> fetch_for_project_slugs(fn project_slug ->
      do_fetch_by_states(project_slug, state_names, assignee_filter, graphql_fun)
    end)
  end

  defp do_fetch_by_states(project_slug, state_names, assignee_filter, graphql_fun) do
    do_fetch_by_states_page(project_slug, state_names, assignee_filter, graphql_fun, nil, [])
  end

  defp do_fetch_project_issues(project_slug, limit, status_group, graphql_fun) do
    do_fetch_project_issues_page(project_slug, limit, status_group, graphql_fun, nil, [])
  end

  defp fetch_project_issues_for_projects(projects, limit, status_group, graphql_fun) do
    projects
    |> project_slugs()
    |> fetch_for_project_slugs(fn project_slug ->
      do_fetch_project_issues(project_slug, limit, status_group, graphql_fun)
    end)
  end

  defp fetch_issues_for_selected_project(_project, 0, _status_group), do: {:ok, []}

  defp fetch_issues_for_selected_project(nil, _limit, _status_group), do: {:ok, []}

  defp fetch_issues_for_selected_project(%Project{} = project, limit, status_group) do
    if is_nil(project_slug(project)) do
      {:ok, []}
    else
      fetch_project_issues_for_projects([project], limit, status_group, &graphql/2)
    end
  end

  defp do_fetch_project_issues_page(_project_slug, remaining, status_group, _graphql_fun, _after_cursor, acc_issues)
       when remaining <= 0 do
    {:ok, acc_issues |> finalize_paginated_issues() |> filter_project_issues_by_status_group(status_group)}
  end

  defp do_fetch_project_issues_page(project_slug, remaining, status_group, graphql_fun, after_cursor, acc_issues) do
    first = min(@issue_page_size, remaining)

    case graphql_fun.(@project_issues_query, %{projectSlug: project_slug, first: first, after: after_cursor}) do
      {:ok, body} ->
        with {:ok, issues, page_info} <- decode_linear_page_response(body, nil) do
          updated_acc = prepend_page_issues(issues, acc_issues)
          remaining = remaining - length(issues)

          case next_page_cursor(page_info) do
            {:ok, next_cursor} ->
              do_fetch_project_issues_page(project_slug, remaining, status_group, graphql_fun, next_cursor, updated_acc)

            :done ->
              {:ok, updated_acc |> finalize_paginated_issues() |> filter_project_issues_by_status_group(status_group)}

            {:error, reason} ->
              {:error, reason}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_fetch_by_states_page(project_slug, state_names, assignee_filter, graphql_fun, after_cursor, acc_issues) do
    with {:ok, body} <-
           graphql_fun.(@query, %{
             projectSlug: project_slug,
             stateNames: state_names,
             first: @issue_page_size,
             relationFirst: @issue_page_size,
             after: after_cursor
           }),
         {:ok, issues, page_info} <- decode_linear_page_response(body, assignee_filter) do
      updated_acc = prepend_page_issues(issues, acc_issues)

      case next_page_cursor(page_info) do
        {:ok, next_cursor} ->
          do_fetch_by_states_page(project_slug, state_names, assignee_filter, graphql_fun, next_cursor, updated_acc)

        :done ->
          {:ok, finalize_paginated_issues(updated_acc)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp prepend_page_issues(issues, acc_issues) when is_list(issues) and is_list(acc_issues) do
    Enum.reverse(issues, acc_issues)
  end

  defp finalize_paginated_issues(acc_issues) when is_list(acc_issues), do: Enum.reverse(acc_issues)

  defp fetch_for_project_slugs(project_slugs, fetch_fun) when is_list(project_slugs) and is_function(fetch_fun, 1) do
    project_slugs
    |> Enum.reduce_while({:ok, []}, fn project_slug, {:ok, acc_issues} ->
      case fetch_fun.(project_slug) do
        {:ok, issues} ->
          {:cont, {:ok, acc_issues ++ issues}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp project_slugs(projects) when is_list(projects) do
    projects
    |> Enum.map(fn
      %Project{} = project -> project_slug(project) || ""
      _project -> ""
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp select_project(projects, selected_project_key) when is_list(projects) do
    selected_project_key = normalize_project_key(selected_project_key)

    Enum.find(projects, &(project_key(&1) == selected_project_key)) ||
      List.first(projects)
  end

  defp project_key(nil), do: nil
  defp project_key(%Project{slug: slug}) when is_binary(slug) and slug != "", do: String.trim(slug)
  defp project_key(%Project{id: id}) when is_binary(id) and id != "", do: String.trim(id)
  defp project_key(%Project{name: name}) when is_binary(name) and name != "", do: String.trim(name)
  defp project_key(_project), do: nil

  defp project_slug(%Project{slug: slug}) when is_binary(slug) do
    case String.trim(slug) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp project_slug(_project), do: nil

  defp normalize_project_key(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_project_key(_value), do: nil

  defp dedupe_projects(projects) when is_list(projects) do
    projects
    |> Enum.reduce({[], MapSet.new()}, fn
      %Project{slug: slug} = project, {acc, seen} when is_binary(slug) ->
        slug = String.trim(slug)

        if slug == "" or MapSet.member?(seen, slug) do
          {acc, seen}
        else
          {[%Project{project | slug: slug} | acc], MapSet.put(seen, slug)}
        end

      _project, state ->
        state
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp do_fetch_issue_states(ids, assignee_filter) do
    do_fetch_issue_states(ids, assignee_filter, &graphql/2)
  end

  defp do_fetch_issue_states(ids, assignee_filter, graphql_fun)
       when is_list(ids) and is_function(graphql_fun, 2) do
    issue_order_index = issue_order_index(ids)
    do_fetch_issue_states_page(ids, assignee_filter, graphql_fun, [], issue_order_index)
  end

  defp do_fetch_issue_states_page([], _assignee_filter, _graphql_fun, acc_issues, issue_order_index) do
    acc_issues
    |> finalize_paginated_issues()
    |> sort_issues_by_requested_ids(issue_order_index)
    |> then(&{:ok, &1})
  end

  defp do_fetch_issue_states_page(ids, assignee_filter, graphql_fun, acc_issues, issue_order_index) do
    {batch_ids, rest_ids} = Enum.split(ids, @issue_page_size)

    case graphql_fun.(@query_by_ids, %{
           ids: batch_ids,
           first: length(batch_ids),
           relationFirst: @issue_page_size
         }) do
      {:ok, body} ->
        with {:ok, issues} <- decode_linear_response(body, assignee_filter) do
          updated_acc = prepend_page_issues(issues, acc_issues)
          do_fetch_issue_states_page(rest_ids, assignee_filter, graphql_fun, updated_acc, issue_order_index)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp issue_order_index(ids) when is_list(ids) do
    ids
    |> Enum.with_index()
    |> Map.new()
  end

  defp sort_issues_by_requested_ids(issues, issue_order_index)
       when is_list(issues) and is_map(issue_order_index) do
    fallback_index = map_size(issue_order_index)

    Enum.sort_by(issues, fn
      %Issue{id: issue_id} -> Map.get(issue_order_index, issue_id, fallback_index)
      _ -> fallback_index
    end)
  end

  defp build_graphql_payload(query, variables, operation_name) do
    %{
      "query" => query,
      "variables" => variables
    }
    |> maybe_put_operation_name(operation_name)
  end

  defp maybe_put_operation_name(payload, operation_name) when is_binary(operation_name) do
    trimmed = String.trim(operation_name)

    if trimmed == "" do
      payload
    else
      Map.put(payload, "operationName", trimmed)
    end
  end

  defp maybe_put_operation_name(payload, _operation_name), do: payload

  defp linear_error_context(payload, response) when is_map(payload) do
    operation_name =
      case Map.get(payload, "operationName") do
        name when is_binary(name) and name != "" -> " operation=#{name}"
        _ -> ""
      end

    body =
      response
      |> Map.get(:body)
      |> summarize_error_body()

    operation_name <> " body=" <> body
  end

  defp summarize_error_body(body) when is_binary(body) do
    body
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> truncate_error_body()
    |> inspect()
  end

  defp summarize_error_body(body) do
    body
    |> inspect(limit: 20, printable_limit: @max_error_body_log_bytes)
    |> truncate_error_body()
  end

  defp truncate_error_body(body) when is_binary(body) do
    if byte_size(body) > @max_error_body_log_bytes do
      binary_part(body, 0, @max_error_body_log_bytes) <> "...<truncated>"
    else
      body
    end
  end

  defp graphql_headers do
    case Config.settings!().tracker.api_key do
      nil ->
        {:error, :missing_linear_api_token}

      token ->
        {:ok,
         [
           {"Authorization", token},
           {"Content-Type", "application/json"}
         ]}
    end
  end

  defp post_graphql_request(payload, headers) do
    case Config.settings!().tracker.endpoint do
      endpoint when is_binary(endpoint) ->
        Req.post(endpoint,
          headers: headers,
          json: payload,
          connect_options: [timeout: 30_000]
        )

      _ ->
        {:error, :missing_linear_api_endpoint}
    end
  end

  defp decode_project_page_response(%{
         "data" => %{
           "projects" => %{
             "nodes" => nodes,
             "pageInfo" => %{"hasNextPage" => has_next_page, "endCursor" => end_cursor}
           }
         }
       }) do
    projects =
      nodes
      |> Enum.map(&normalize_project/1)
      |> Enum.reject(&is_nil/1)

    {:ok, projects, %{has_next_page: has_next_page == true, end_cursor: end_cursor}}
  end

  defp decode_project_page_response(%{"errors" => errors}) do
    {:error, {:linear_graphql_errors, errors}}
  end

  defp decode_project_page_response(_unknown), do: {:error, :linear_unknown_project_payload}

  defp decode_linear_response(%{"data" => %{"issues" => %{"nodes" => nodes}}}, assignee_filter) do
    issues =
      nodes
      |> Enum.map(&normalize_issue(&1, assignee_filter))
      |> Enum.reject(&is_nil(&1))

    {:ok, issues}
  end

  defp decode_linear_response(%{"errors" => errors}, _assignee_filter) do
    {:error, {:linear_graphql_errors, errors}}
  end

  defp decode_linear_response(_unknown, _assignee_filter) do
    {:error, :linear_unknown_payload}
  end

  defp decode_linear_page_response(
         %{
           "data" => %{
             "issues" => %{
               "nodes" => nodes,
               "pageInfo" => %{"hasNextPage" => has_next_page, "endCursor" => end_cursor}
             }
           }
         },
         assignee_filter
       ) do
    with {:ok, issues} <- decode_linear_response(%{"data" => %{"issues" => %{"nodes" => nodes}}}, assignee_filter) do
      {:ok, issues, %{has_next_page: has_next_page == true, end_cursor: end_cursor}}
    end
  end

  defp decode_linear_page_response(response, assignee_filter), do: decode_linear_response(response, assignee_filter)

  defp next_page_cursor(%{has_next_page: true, end_cursor: end_cursor})
       when is_binary(end_cursor) and byte_size(end_cursor) > 0 do
    {:ok, end_cursor}
  end

  defp next_page_cursor(%{has_next_page: true}), do: {:error, :linear_missing_end_cursor}
  defp next_page_cursor(_), do: :done

  defp normalize_project(project) when is_map(project) do
    case project["slugId"] do
      slug when is_binary(slug) ->
        %Project{
          id: project["id"],
          name: project["name"],
          slug: slug,
          url: project["url"]
        }

      _ ->
        nil
    end
  end

  defp normalize_project(_project), do: nil

  defp normalize_issue(issue, assignee_filter) when is_map(issue) do
    assignee = issue["assignee"]
    creator = issue["creator"]

    %Issue{
      id: issue["id"],
      identifier: issue["identifier"],
      title: issue["title"],
      description: issue["description"],
      priority: parse_priority(issue["priority"]),
      state: get_in(issue, ["state", "name"]),
      state_type: get_in(issue, ["state", "type"]),
      branch_name: issue["branchName"],
      url: issue["url"],
      project_name: get_in(issue, ["project", "name"]),
      project_slug: get_in(issue, ["project", "slugId"]),
      project_url: get_in(issue, ["project", "url"]),
      assignee_id: assignee_field(assignee, "id"),
      assignee_name: assignee_field(assignee, "name"),
      creator_id: assignee_field(creator, "id"),
      creator_name: assignee_field(creator, "name"),
      blocked_by: extract_blockers(issue),
      labels: extract_labels(issue),
      assigned_to_worker: assigned_to_worker?(assignee, assignee_filter),
      created_at: parse_datetime(issue["createdAt"]),
      updated_at: parse_datetime(issue["updatedAt"])
    }
  end

  defp normalize_issue(_issue, _assignee_filter), do: nil

  defp normalize_project_status_group(status_group)
       when status_group in [:all, :todo, :in_progress, :done],
       do: status_group

  defp normalize_project_status_group(status_group) when is_binary(status_group) do
    case String.trim(status_group) do
      "todo" -> :todo
      "in_progress" -> :in_progress
      "done" -> :done
      "all" -> :all
      _ -> :all
    end
  end

  defp normalize_project_status_group(_status_group), do: :all

  defp filter_project_issues_by_status_group(issues, :all), do: issues

  defp filter_project_issues_by_status_group(issues, status_group) when is_list(issues) do
    Enum.filter(issues, &(project_issue_status_group(&1) == status_group))
  end

  defp project_issue_status_group(%Issue{state: state}) do
    normalized_state = normalize_issue_state_group_value(state)

    cond do
      normalized_state == "done" -> :done
      normalized_state == "in progress" -> :in_progress
      true -> :todo
    end
  end

  defp normalize_issue_state_group_value(value) when is_binary(value) do
    value |> String.trim() |> String.downcase()
  end

  defp normalize_issue_state_group_value(_value), do: ""

  defp assignee_field(%{} = assignee, field) when is_binary(field), do: assignee[field]
  defp assignee_field(_assignee, _field), do: nil

  defp assigned_to_worker?(_assignee, nil), do: true

  defp assigned_to_worker?(%{} = assignee, %{match_values: match_values})
       when is_struct(match_values, MapSet) do
    assignee
    |> assignee_id()
    |> then(fn
      nil -> false
      assignee_id -> MapSet.member?(match_values, assignee_id)
    end)
  end

  defp assigned_to_worker?(_assignee, _assignee_filter), do: false

  defp assignee_id(%{} = assignee), do: normalize_assignee_match_value(assignee["id"])

  defp routing_assignee_filter do
    case Config.settings!().tracker.assignee do
      nil ->
        {:ok, nil}

      assignee ->
        build_assignee_filter(assignee)
    end
  end

  defp build_assignee_filter(assignee) when is_binary(assignee) do
    case normalize_assignee_match_value(assignee) do
      nil ->
        {:ok, nil}

      "me" ->
        resolve_viewer_assignee_filter()

      normalized ->
        {:ok, %{configured_assignee: assignee, match_values: MapSet.new([normalized])}}
    end
  end

  defp resolve_viewer_assignee_filter do
    case graphql(@viewer_query, %{}) do
      {:ok, %{"data" => %{"viewer" => viewer}}} when is_map(viewer) ->
        case assignee_id(viewer) do
          nil ->
            {:error, :missing_linear_viewer_identity}

          viewer_id ->
            {:ok, %{configured_assignee: "me", match_values: MapSet.new([viewer_id])}}
        end

      {:ok, _body} ->
        {:error, :missing_linear_viewer_identity}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_assignee_match_value(value) when is_binary(value) do
    case value |> String.trim() do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_assignee_match_value(_value), do: nil

  defp extract_labels(%{"labels" => %{"nodes" => labels}}) when is_list(labels) do
    labels
    |> Enum.map(& &1["name"])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
  end

  defp extract_labels(_), do: []

  defp extract_blockers(%{"inverseRelations" => %{"nodes" => inverse_relations}})
       when is_list(inverse_relations) do
    inverse_relations
    |> Enum.flat_map(fn
      %{"type" => relation_type, "issue" => blocker_issue}
      when is_binary(relation_type) and is_map(blocker_issue) ->
        if String.downcase(String.trim(relation_type)) == "blocks" do
          [
            %{
              id: blocker_issue["id"],
              identifier: blocker_issue["identifier"],
              state: get_in(blocker_issue, ["state", "name"])
            }
          ]
        else
          []
        end

      _ ->
        []
    end)
  end

  defp extract_blockers(_), do: []

  defp parse_datetime(nil), do: nil

  defp parse_datetime(raw) do
    case DateTime.from_iso8601(raw) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_priority(priority) when is_integer(priority), do: priority
  defp parse_priority(_priority), do: nil
end
