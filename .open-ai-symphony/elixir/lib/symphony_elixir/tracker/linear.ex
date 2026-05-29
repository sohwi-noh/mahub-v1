defmodule SymphonyElixir.Tracker.Linear do
  @moduledoc """
  Linear issue tracker adapter.
  """

  @behaviour SymphonyElixir.Tracker

  alias SymphonyElixir.{Issue, Tracker.HTTP}

  @candidate_query """
  query SymphonyIssues($stateNames: [String!], $assigneeId: String) {
    issues(
      first: 50
      filter: {
        state: { name: { in: $stateNames } }
        assignee: { id: { eq: $assigneeId } }
      }
      orderBy: updatedAt
    ) {
      nodes {
        id
        identifier
        title
        description
        priority
        url
        branchName
        createdAt
        updatedAt
        state { name }
        labels { nodes { name } }
        relations { nodes { type relatedIssue { id identifier state { name } } } }
      }
    }
  }
  """

  @issue_query """
  query SymphonyIssue($id: String!) {
    issue(id: $id) {
      id
      identifier
      title
      description
      priority
      url
      branchName
      createdAt
      updatedAt
      state { name }
      labels { nodes { name } }
      relations { nodes { type relatedIssue { id identifier state { name } } } }
    }
  }
  """

  @comment_mutation """
  mutation SymphonyComment($issueId: String!, $body: String!) {
    commentCreate(input: { issueId: $issueId, body: $body }) {
      success
    }
  }
  """

  @impl true
  def fetch_candidates(config) do
    variables = %{
      stateNames: Map.get(config, :active_states, ["Symphony Ready"]),
      assigneeId: normalize_assignee(Map.get(config, :assignee))
    }

    body = %{query: @candidate_query, variables: variables}

    with {:ok, payload} <- graphql(config, body) do
      issues =
        payload
        |> get_in(["data", "issues", "nodes"])
        |> List.wrap()
        |> Enum.map(&normalize_issue/1)

      {:ok, issues}
    end
  end

  @impl true
  def fetch_issue(config, issue) do
    id = issue_ref(issue)

    with {:ok, payload} <- graphql(config, %{query: @issue_query, variables: %{id: id}}) do
      case get_in(payload, ["data", "issue"]) do
        nil -> {:ok, nil}
        raw -> {:ok, normalize_issue(raw)}
      end
    end
  end

  @impl true
  def comment(config, issue, body) when is_binary(body) do
    id = issue_ref(issue)
    mutation = %{query: @comment_mutation, variables: %{issueId: id, body: body}}

    case graphql(config, mutation) do
      {:ok, _payload} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def transition(_config, _issue, _target_state) do
    {:error, :linear_transition_not_installed}
  end

  @spec normalize_issue(map()) :: Issue.t()
  def normalize_issue(raw) when is_map(raw) do
    %Issue{
      id: raw["id"],
      identifier: raw["identifier"],
      title: raw["title"],
      description: raw["description"],
      priority: raw["priority"],
      state: get_in(raw, ["state", "name"]),
      branch_name: raw["branchName"],
      url: raw["url"],
      tracker: :linear,
      labels: label_names(raw),
      blocked_by: blockers(raw),
      created_at: raw["createdAt"],
      updated_at: raw["updatedAt"],
      raw: raw
    }
  end

  defp graphql(config, body) do
    endpoint = Map.fetch!(config, :endpoint)
    api_key = Map.fetch!(config, :api_key)

    headers = [
      {"authorization", api_key},
      {"content-type", "application/json"}
    ]

    with {:ok, payload} <- HTTP.post_json(endpoint, headers, body) do
      case payload do
        %{"errors" => errors} -> {:error, {:linear_graphql_errors, errors}}
        _ -> {:ok, payload}
      end
    end
  end

  defp label_names(raw) do
    raw
    |> get_in(["labels", "nodes"])
    |> List.wrap()
    |> Enum.map(& &1["name"])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
  end

  defp blockers(raw) do
    raw
    |> get_in(["relations", "nodes"])
    |> List.wrap()
    |> Enum.filter(&(&1["type"] == "blocked_by"))
    |> Enum.map(fn relation ->
      related = relation["relatedIssue"] || %{}

      %{
        id: related["id"],
        identifier: related["identifier"],
        state: get_in(related, ["state", "name"])
      }
    end)
  end

  defp issue_ref(%Issue{id: id}) when not is_nil(id), do: id
  defp issue_ref(%Issue{identifier: identifier}), do: identifier
  defp issue_ref(value), do: to_string(value)

  defp normalize_assignee(nil), do: nil
  defp normalize_assignee(""), do: nil
  defp normalize_assignee("me"), do: nil
  defp normalize_assignee(value), do: value
end
