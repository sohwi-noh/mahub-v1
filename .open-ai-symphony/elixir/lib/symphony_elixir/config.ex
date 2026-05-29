defmodule SymphonyElixir.Config do
  @moduledoc """
  Typed configuration view derived from WORKFLOW.md and environment variables.
  """

  alias SymphonyElixir.Workflow

  defstruct [
    :workflow,
    :tracker_kind,
    :tracker_config,
    :poll_interval_ms,
    :workspace_root,
    :agent,
    :codex
  ]

  @type tracker_kind :: :linear | :github

  @type t :: %__MODULE__{
          workflow: Workflow.t(),
          tracker_kind: tracker_kind(),
          tracker_config: map(),
          poll_interval_ms: pos_integer(),
          workspace_root: String.t(),
          agent: map(),
          codex: map()
        }

  @spec load(String.t()) :: {:ok, t()} | {:error, term()}
  def load(path) do
    with {:ok, workflow} <- Workflow.load(path) do
      from_workflow(workflow)
    end
  end

  @spec from_workflow(Workflow.t()) :: {:ok, t()} | {:error, term()}
  def from_workflow(%Workflow{} = workflow) do
    tracker = map_get(workflow.config, "tracker", %{})
    kind = tracker |> map_get("kind", "linear") |> resolve_env() |> normalize_tracker_kind()

    with {:ok, tracker_kind} <- kind,
         {:ok, tracker_config} <- tracker_config(tracker_kind, tracker) do
      polling = map_get(workflow.config, "polling", %{})
      workspace = map_get(workflow.config, "workspace", %{})

      {:ok,
       %__MODULE__{
         workflow: workflow,
         tracker_kind: tracker_kind,
         tracker_config: tracker_config,
         poll_interval_ms: polling |> map_get("interval_ms", 15_000) |> int_value(15_000),
         workspace_root:
           workspace
           |> map_get("root", ".symphony-workspaces")
           |> resolve_env(".symphony-workspaces"),
         agent: map_get(workflow.config, "agent", %{}),
         codex: map_get(workflow.config, "codex", %{})
       }}
    end
  end

  defp tracker_config(:linear, tracker) do
    linear = map_get(tracker, "linear", %{})

    config = %{
      endpoint:
        linear
        |> map_get("endpoint", "https://api.linear.app/graphql")
        |> resolve_env("https://api.linear.app/graphql"),
      api_key: linear |> map_get("api_key", "$LINEAR_API_KEY") |> resolve_env(),
      assignee: linear |> map_get("assignee", nil) |> resolve_env(),
      active_states: map_get(tracker, "active_states", ["Symphony Ready"]),
      terminal_states:
        map_get(tracker, "terminal_states", [
          "Done",
          "Closed",
          "Cancelled",
          "Canceled",
          "Duplicate"
        ])
    }

    require_keys(config, [:endpoint, :api_key])
  end

  defp tracker_config(:github, tracker) do
    github = map_get(tracker, "github", %{})

    config = %{
      token: github |> map_get("token", "$SYMPHONY_GITHUB_TOKEN") |> resolve_env(),
      owner: github |> map_get("owner", "$SYMPHONY_GITHUB_OWNER") |> resolve_env(),
      repo: github |> map_get("repo", "$SYMPHONY_GITHUB_REPO") |> resolve_env(),
      assignee: github |> map_get("assignee", nil) |> resolve_env(),
      ready_label:
        github |> map_get("ready_label", "symphony-ready") |> resolve_env("symphony-ready"),
      running_label:
        github |> map_get("running_label", "symphony-running") |> resolve_env("symphony-running"),
      review_label: github |> map_get("review_label", "in-review") |> resolve_env("in-review"),
      done_label: github |> map_get("done_label", "done") |> resolve_env("done")
    }

    require_keys(config, [:token, :owner, :repo, :ready_label])
  end

  defp require_keys(config, keys) do
    missing =
      Enum.filter(keys, fn key ->
        value = Map.get(config, key)
        is_nil(value) or value == ""
      end)

    case missing do
      [] -> {:ok, config}
      _ -> {:error, {:missing_tracker_config, missing}}
    end
  end

  defp normalize_tracker_kind(value) when is_binary(value) do
    case value |> String.trim() |> String.downcase() do
      "linear" -> {:ok, :linear}
      "github" -> {:ok, :github}
      "github_issues" -> {:ok, :github}
      other -> {:error, {:unsupported_tracker_kind, other}}
    end
  end

  defp normalize_tracker_kind(value) when value in [:linear, :github], do: {:ok, value}
  defp normalize_tracker_kind(value), do: {:error, {:unsupported_tracker_kind, value}}

  @spec resolve_env(term(), term()) :: term()
  def resolve_env(value, fallback \\ nil)
  def resolve_env("$" <> name, fallback), do: System.get_env(name) || fallback
  def resolve_env(nil, fallback), do: fallback
  def resolve_env(value, _fallback), do: value

  defp int_value(value, _default) when is_integer(value), do: value

  defp int_value(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp int_value(_value, default), do: default

  defp map_get(map, key, default) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key)) || default
  end

  defp map_get(_map, _key, default), do: default
end
