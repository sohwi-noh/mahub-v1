defmodule SymphonyElixir.WorkflowTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.Workflow

  test "parses YAML front matter and prompt body" do
    body = """
    ---
    tracker:
      kind: github
    ---

    Hello {{ issue.identifier }}
    """

    assert {:ok, config, prompt_template} = Workflow.parse(body)
    assert config["tracker"]["kind"] == "github"
    assert prompt_template == "\nHello {{ issue.identifier }}\n"
  end
end
