defmodule SymphonyElixir.TrackerTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.Tracker.{GitHubIssues, Linear}

  test "normalizes GitHub issue payload" do
    issue =
      GitHubIssues.normalize_issue(%{
        "id" => 123,
        "number" => 42,
        "title" => "Add feature",
        "body" => "Body",
        "html_url" => "https://github.com/org/repo/issues/42",
        "state" => "open",
        "labels" => [%{"name" => "symphony-ready"}],
        "created_at" => "2026-05-29T00:00:00Z",
        "updated_at" => "2026-05-29T00:00:00Z"
      })

    assert issue.tracker == :github
    assert issue.identifier == "GH-42"
    assert issue.state == "Symphony Ready"
    assert issue.labels == ["symphony-ready"]
  end

  test "normalizes Linear issue payload" do
    issue =
      Linear.normalize_issue(%{
        "id" => "linear-id",
        "identifier" => "KTD-1",
        "title" => "Add feature",
        "description" => "Body",
        "priority" => 3,
        "url" => "https://linear.app/team/issue/KTD-1",
        "branchName" => "codex/ktd-1",
        "state" => %{"name" => "Symphony Ready"},
        "labels" => %{"nodes" => [%{"name" => "agent-worklog"}]}
      })

    assert issue.tracker == :linear
    assert issue.identifier == "KTD-1"
    assert issue.state == "Symphony Ready"
    assert issue.labels == ["agent-worklog"]
  end
end
