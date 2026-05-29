defmodule SymphonyElixir.Tracker do
  @moduledoc """
  Issue tracker adapter behaviour.

  SPEC names this layer `Issue Tracker Client`. Concrete adapters normalize
  external tracker payloads into `SymphonyElixir.Issue`.
  """

  alias SymphonyElixir.{Config, Issue}

  @callback fetch_candidates(map()) :: {:ok, [Issue.t()]} | {:error, term()}
  @callback fetch_issue(map(), Issue.t() | String.t() | integer()) ::
              {:ok, Issue.t() | nil} | {:error, term()}
  @callback comment(map(), Issue.t() | String.t() | integer(), String.t()) ::
              :ok | {:error, term()}
  @callback transition(map(), Issue.t() | String.t() | integer(), atom() | String.t()) ::
              :ok | {:error, term()}

  @spec adapter!(Config.t()) :: module()
  def adapter!(%Config{tracker_kind: :linear}), do: SymphonyElixir.Tracker.Linear
  def adapter!(%Config{tracker_kind: :github}), do: SymphonyElixir.Tracker.GitHubIssues
end
