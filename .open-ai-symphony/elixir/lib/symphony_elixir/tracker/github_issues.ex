defmodule SymphonyElixir.Tracker.GitHubIssues do
  @moduledoc """
  GitHub Issues tracker adapter.

  GitHub Issues does not expose Linear-style workflow states, so this adapter
  treats labels as the workflow state source.
  """

  @behaviour SymphonyElixir.Tracker

  alias SymphonyElixir.{Issue, Tracker.HTTP}

  @github_api "https://api.github.com"

  @impl true
  def fetch_candidates(config) do
    url =
      config
      |> issues_url()
      |> add_query(%{
        "state" => "open",
        "labels" => Map.fetch!(config, :ready_label),
        "assignee" => Map.get(config, :assignee)
      })

    with {:ok, payload} <- HTTP.get_json(url, headers(config)) do
      issues =
        payload
        |> List.wrap()
        |> Enum.reject(&Map.has_key?(&1, "pull_request"))
        |> Enum.map(&normalize_issue/1)

      {:ok, issues}
    end
  end

  @impl true
  def fetch_issue(config, issue) do
    number = issue_number(issue)
    url = "#{issues_url(config)}/#{number}"

    with {:ok, payload} <- HTTP.get_json(url, headers(config)) do
      {:ok, normalize_issue(payload)}
    end
  end

  @impl true
  def comment(config, issue, body) when is_binary(body) do
    number = issue_number(issue)
    url = "#{issues_url(config)}/#{number}/comments"

    case HTTP.post_json(url, headers(config), %{body: body}) do
      {:ok, _payload} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def transition(config, issue, target_state) do
    label =
      case normalize_target_state(target_state) do
        :running -> Map.fetch!(config, :running_label)
        :review -> Map.fetch!(config, :review_label)
        :done -> Map.fetch!(config, :done_label)
        other -> to_string(other)
      end

    number = issue_number(issue)
    url = "#{issues_url(config)}/#{number}/labels"

    case HTTP.post_json(url, headers(config), %{labels: [label]}) do
      {:ok, _payload} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec normalize_issue(map()) :: Issue.t()
  def normalize_issue(raw) when is_map(raw) do
    number = raw["number"]

    %Issue{
      id: raw["id"],
      identifier: if(number, do: "GH-#{number}"),
      title: raw["title"],
      description: raw["body"],
      priority: nil,
      state: github_state(raw),
      branch_name: nil,
      url: raw["html_url"],
      tracker: :github,
      labels: label_names(raw),
      blocked_by: [],
      created_at: raw["created_at"],
      updated_at: raw["updated_at"],
      raw: raw
    }
  end

  defp github_state(raw) do
    labels = label_names(raw)

    cond do
      "done" in labels -> "Done"
      "in-review" in labels -> "In Review"
      "symphony-running" in labels -> "In Progress"
      "symphony-ready" in labels -> "Symphony Ready"
      true -> raw["state"]
    end
  end

  defp label_names(raw) do
    raw
    |> Map.get("labels", [])
    |> List.wrap()
    |> Enum.map(fn
      %{"name" => name} -> name
      name when is_binary(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
  end

  defp issues_url(config) do
    owner = Map.fetch!(config, :owner)
    repo = Map.fetch!(config, :repo)
    "#{@github_api}/repos/#{owner}/#{repo}/issues"
  end

  defp headers(config) do
    [
      {"accept", "application/vnd.github+json"},
      {"authorization", "Bearer #{Map.fetch!(config, :token)}"},
      {"x-github-api-version", "2022-11-28"},
      {"user-agent", "symphony-elixir"}
    ]
  end

  defp add_query(url, params) do
    query =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> URI.encode_query()

    if query == "", do: url, else: "#{url}?#{query}"
  end

  defp issue_number(%Issue{identifier: "GH-" <> number}), do: number
  defp issue_number(%Issue{raw: %{"number" => number}}), do: number
  defp issue_number(value), do: to_string(value)

  defp normalize_target_state(value) when is_atom(value), do: value

  defp normalize_target_state(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "running" -> :running
      "in_progress" -> :running
      "in progress" -> :running
      "review" -> :review
      "in_review" -> :review
      "in review" -> :review
      "done" -> :done
      other -> other
    end
  end
end
