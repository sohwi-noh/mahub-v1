defmodule SymphonyElixir.ConfigTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.{Config, Workflow}

  test "selects github tracker from env" do
    System.put_env("SYMPHONY_TRACKER_KIND", "github")
    System.put_env("SYMPHONY_GITHUB_TOKEN", "token")
    System.put_env("SYMPHONY_GITHUB_OWNER", "owner")
    System.put_env("SYMPHONY_GITHUB_REPO", "repo")

    workflow = %Workflow{
      path: "WORKFLOW.md",
      prompt_template: "",
      config: %{
        "tracker" => %{
          "kind" => "$SYMPHONY_TRACKER_KIND",
          "github" => %{
            "token" => "$SYMPHONY_GITHUB_TOKEN",
            "owner" => "$SYMPHONY_GITHUB_OWNER",
            "repo" => "$SYMPHONY_GITHUB_REPO",
            "ready_label" => "symphony-ready"
          }
        },
        "workspace" => %{"root" => ".workspaces"}
      }
    }

    assert {:ok, config} = Config.from_workflow(workflow)
    assert config.tracker_kind == :github
    assert config.tracker_config.owner == "owner"
    assert config.tracker_config.ready_label == "symphony-ready"
  after
    System.delete_env("SYMPHONY_TRACKER_KIND")
    System.delete_env("SYMPHONY_GITHUB_TOKEN")
    System.delete_env("SYMPHONY_GITHUB_OWNER")
    System.delete_env("SYMPHONY_GITHUB_REPO")
  end
end
