defmodule SymphonyElixir.CLI do
  @moduledoc """
  Minimal CLI for the SPEC-based default installation.
  """

  alias SymphonyElixir.{Config, Tracker}

  @spec main([String.t()]) :: :ok
  def main(argv) do
    case argv do
      ["doctor", workflow_path] -> doctor(workflow_path)
      ["poll", workflow_path] -> poll(workflow_path)
      ["serve", workflow_path] -> serve(workflow_path)
      [workflow_path] -> doctor(workflow_path)
      _ -> usage()
    end
  end

  defp doctor(workflow_path) do
    case Config.load(workflow_path) do
      {:ok, config} ->
        IO.puts("workflow=#{workflow_path}")
        IO.puts("tracker=#{config.tracker_kind}")
        IO.puts("workspace_root=#{config.workspace_root}")
        IO.puts("poll_interval_ms=#{config.poll_interval_ms}")

      {:error, reason} ->
        IO.puts(:stderr, "config error: #{inspect(reason)}")
        System.halt(78)
    end
  end

  defp poll(workflow_path) do
    with {:ok, config} <- Config.load(workflow_path),
         adapter <- Tracker.adapter!(config),
         {:ok, issues} <- adapter.fetch_candidates(config.tracker_config) do
      IO.puts(
        Jason.encode!(%{tracker: config.tracker_kind, count: length(issues), issues: issues},
          pretty: true
        )
      )
    else
      {:error, reason} ->
        IO.puts(:stderr, "poll error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp serve(workflow_path) do
    case Config.load(workflow_path) do
      {:ok, config} ->
        SymphonyElixir.Orchestrator.run(config)

      {:error, reason} ->
        IO.puts(:stderr, "config error: #{inspect(reason)}")
        System.halt(78)
    end
  end

  defp usage do
    IO.puts(
      :stderr,
      "usage: symphony doctor <WORKFLOW.md> | poll <WORKFLOW.md> | serve <WORKFLOW.md>"
    )

    System.halt(64)
  end
end
