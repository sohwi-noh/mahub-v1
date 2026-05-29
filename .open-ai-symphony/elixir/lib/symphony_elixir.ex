defmodule SymphonyElixir do
  @moduledoc """
  SPEC-based Symphony runtime entry module.
  """

  alias SymphonyElixir.{Config, Tracker}

  @spec load(String.t()) :: {:ok, Config.t()} | {:error, term()}
  def load(workflow_path), do: Config.load(workflow_path)

  @spec tracker(Config.t()) :: module()
  def tracker(%Config{} = config), do: Tracker.adapter!(config)
end
