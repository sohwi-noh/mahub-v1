defmodule SymphonyElixir.Workspace do
  @moduledoc """
  Deterministic per-issue workspace management.
  """

  alias SymphonyElixir.Issue

  @spec path_for_issue(String.t(), Issue.t()) :: String.t()
  def path_for_issue(root, %Issue{} = issue) do
    Path.join(root, safe_identifier(issue.identifier || to_string(issue.id || "issue")))
  end

  @spec ensure_for_issue(String.t(), Issue.t()) :: {:ok, String.t()} | {:error, term()}
  def ensure_for_issue(root, %Issue{} = issue) do
    path = path_for_issue(root, issue)

    case File.mkdir_p(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_identifier(identifier) do
    identifier
    |> String.replace(~r/[^a-zA-Z0-9._-]/, "_")
    |> String.trim("_")
    |> case do
      "" -> "issue"
      value -> value
    end
  end
end
