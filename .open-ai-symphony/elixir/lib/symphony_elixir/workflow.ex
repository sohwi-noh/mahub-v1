defmodule SymphonyElixir.Workflow do
  @moduledoc """
  Loads a SPEC-style WORKFLOW.md file with YAML front matter and Markdown prompt body.
  """

  defstruct [:path, config: %{}, prompt_template: ""]

  @type t :: %__MODULE__{path: String.t(), config: map(), prompt_template: String.t()}

  @spec load(String.t()) :: {:ok, t()} | {:error, term()}
  def load(path) when is_binary(path) do
    with {:ok, body} <- File.read(path),
         {:ok, config, prompt} <- parse(body) do
      {:ok, %__MODULE__{path: path, config: config, prompt_template: String.trim(prompt)}}
    end
  end

  @spec parse(String.t()) :: {:ok, map(), String.t()} | {:error, term()}
  def parse("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [yaml, prompt] ->
        parse_yaml(yaml, prompt)

      _ ->
        {:error, :missing_front_matter_end}
    end
  end

  def parse(_body), do: {:error, :missing_front_matter}

  defp parse_yaml(yaml, prompt) do
    case YamlElixir.read_from_string(yaml) do
      {:ok, config} when is_map(config) -> {:ok, config, prompt}
      {:ok, _other} -> {:error, :workflow_config_must_be_map}
      {:error, reason} -> {:error, {:invalid_yaml, reason}}
    end
  end
end
