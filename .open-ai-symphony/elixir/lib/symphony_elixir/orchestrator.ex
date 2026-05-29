defmodule SymphonyElixir.Orchestrator do
  @moduledoc """
  Minimal polling orchestrator.

  This is the SPEC coordination layer seed. It polls the selected tracker on the
  configured cadence and emits normalized candidate issue summaries. Agent
  execution is intentionally left for the next layer.
  """

  require Logger

  alias SymphonyElixir.{Config, Tracker}

  @spec run(Config.t()) :: no_return()
  def run(%Config{} = config) do
    Logger.info(
      "Starting Symphony orchestrator tracker=#{config.tracker_kind} interval_ms=#{config.poll_interval_ms}"
    )

    loop(config)
  end

  defp loop(%Config{} = config) do
    poll_once(config)
    Process.sleep(config.poll_interval_ms)
    loop(config)
  end

  @spec poll_once(Config.t()) :: :ok
  def poll_once(%Config{} = config) do
    adapter = Tracker.adapter!(config)

    case adapter.fetch_candidates(config.tracker_config) do
      {:ok, issues} ->
        Logger.info(
          "Tracker poll complete tracker=#{config.tracker_kind} candidate_count=#{length(issues)}"
        )

        Enum.each(issues, fn issue ->
          Logger.info(
            "Candidate issue tracker=#{issue.tracker} identifier=#{issue.identifier} state=#{issue.state} title=#{inspect(issue.title)}"
          )
        end)

      {:error, reason} ->
        Logger.warning(
          "Tracker poll failed tracker=#{config.tracker_kind} reason=#{inspect(reason)}"
        )
    end

    :ok
  end
end
