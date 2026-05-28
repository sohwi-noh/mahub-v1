defmodule SymphonyElixir.TddWorkflow do
  @moduledoc """
  Loads the canonical TDD subagent workflow stage contract from the repository document.
  """

  alias SymphonyElixir.Config

  @contract_relative_path "docs/tdd-subagent-workflow.md"

  @type artifact_group :: %{
          label: String.t(),
          patterns: [String.t()]
        }

  @type stage :: %{
          number: pos_integer(),
          label: String.t(),
          owner: String.t(),
          artifact_groups: [artifact_group()]
        }

  @spec stages() :: [stage()]
  def stages do
    contract_path()
    |> stages()
  end

  @spec stages(Path.t()) :: [stage()]
  def stages(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> parse_stages(content)
      {:error, _reason} -> []
    end
  end

  @spec contract_path() :: Path.t()
  def contract_path do
    candidate_contract_paths()
    |> Enum.find(&File.regular?/1)
    |> case do
      nil -> hd(candidate_contract_paths())
      path -> path
    end
  end

  defp candidate_contract_paths do
    configured_path = Application.get_env(:symphony_elixir, :tdd_workflow_contract_path)

    [
      configured_path,
      artifact_root_contract_path(),
      workspace_root_contract_path(),
      Path.expand(@contract_relative_path, File.cwd!()),
      Path.expand("../../../../#{@contract_relative_path}", __DIR__)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp artifact_root_contract_path do
    case Application.get_env(:symphony_elixir, :artifact_root) do
      nil -> nil
      artifact_root -> artifact_root |> Path.expand() |> Path.dirname() |> Path.dirname() |> Path.join(@contract_relative_path)
    end
  end

  defp workspace_root_contract_path do
    workspace_root = Config.settings!().workspace.root
    workspace_root |> Path.expand() |> Path.dirname() |> Path.join(@contract_relative_path)
  rescue
    _error -> nil
  end

  defp parse_stages(content) do
    summary_stages = parse_summary_stages(content)
    subagent_artifacts_by_stage = parse_subagent_artifacts_by_stage(content)

    summary_stages
    |> Enum.map(fn stage ->
      extra_artifact_groups = Map.get(subagent_artifacts_by_stage, stage.number, [])
      %{stage | artifact_groups: merge_artifact_groups(stage.artifact_groups ++ extra_artifact_groups)}
    end)
    |> Enum.sort_by(& &1.number)
  end

  defp parse_summary_stages(content) do
    content
    |> String.split("\n")
    |> table_rows(&summary_header?/1)
    |> Enum.flat_map(&summary_stage_from_row/1)
  end

  defp parse_subagent_artifacts_by_stage(content) do
    content
    |> String.split("\n")
    |> table_rows(&subagent_header?/1)
    |> Enum.reduce(%{}, fn row, acc ->
      case subagent_stage_artifacts_from_row(row) do
        nil -> acc
        {stage_number, artifact_groups} -> Map.update(acc, stage_number, artifact_groups, &(&1 ++ artifact_groups))
      end
    end)
  end

  defp table_rows(lines, header_predicate) do
    lines
    |> Enum.drop_while(fn line -> not header_predicate.(line) end)
    |> case do
      [] -> []
      [_header, _separator | rows] -> Enum.take_while(rows, &table_row?/1)
      [_header | rows] -> Enum.take_while(rows, &table_row?/1)
    end
    |> Enum.map(&split_table_row/1)
    |> Enum.reject(&separator_cells?/1)
  end

  defp summary_header?(line) do
    cells = split_table_row(line)
    length(cells) >= 5 and Enum.at(cells, 0) == "단계" and Enum.at(cells, 4) in ["산출물", "판단"]
  end

  defp subagent_header?(line) do
    cells = split_table_row(line)
    length(cells) >= 5 and Enum.at(cells, 0) == "Stage" and Enum.at(cells, 3) == "Run-local subagent 산출물"
  end

  defp table_row?(line), do: line |> String.trim() |> String.starts_with?("|")

  defp split_table_row(row) do
    row
    |> String.trim()
    |> String.trim_leading("|")
    |> String.trim_trailing("|")
    |> String.split("|")
    |> Enum.map(&String.trim/1)
  end

  defp separator_cells?(cells) do
    cells != [] and Enum.all?(cells, &Regex.match?(~r/^:?-{3,}:?$/, &1))
  end

  defp summary_stage_from_row(cells) when length(cells) >= 5 do
    with {:ok, number} when number > 0 <- stage_number(cells |> Enum.at(0)) do
      artifact_groups =
        case cells |> Enum.at(4) |> artifact_groups_from_cell() do
          [] -> [stage_decision_artifact_group()]
          groups -> groups
        end

      [
        %{
          number: number,
          label: Enum.at(cells, 1),
          owner: cells |> Enum.at(2) |> owner_text(),
          artifact_groups: artifact_groups
        }
      ]
    else
      _other -> []
    end
  end

  defp summary_stage_from_row(_cells), do: []

  defp subagent_stage_artifacts_from_row(cells) when length(cells) >= 5 do
    case stage_number(cells |> Enum.at(0)) do
      {:ok, number} when number > 0 ->
        artifact_groups =
          [Enum.at(cells, 2), Enum.at(cells, 3), Enum.at(cells, 4)]
          |> Enum.flat_map(&artifact_groups_from_cell/1)

        {number, artifact_groups}

      _other ->
        nil
    end
  end

  defp subagent_stage_artifacts_from_row(_cells), do: nil

  defp stage_number(value) when is_binary(value) do
    value
    |> String.trim()
    |> Integer.parse()
    |> case do
      {number, ""} -> {:ok, number}
      _other -> :error
    end
  end

  defp owner_text(cell) do
    case extract_code_spans(cell) do
      [] -> cell |> String.replace("`", "") |> String.trim()
      owners -> Enum.join(owners, ", ")
    end
  end

  defp artifact_groups_from_cell(nil), do: []

  defp artifact_groups_from_cell(cell) do
    trimmed = String.trim(cell || "")

    cond do
      trimmed == "" or trimmed == "없음" ->
        []

      String.contains?(trimmed, "또는") ->
        artifact_groups_from_alternatives(trimmed)

      true ->
        trimmed
        |> extract_artifact_codes()
        |> Enum.map(&artifact_group/1)
    end
  end

  defp artifact_groups_from_alternatives(cell) do
    alternatives =
      cell
      |> String.split(~r/\s+또는\s+/u)
      |> Enum.map(&extract_artifact_codes/1)
      |> Enum.reject(&(&1 == []))

    lengths = Enum.map(alternatives, &length/1) |> Enum.uniq()

    cond do
      alternatives == [] ->
        []

      length(alternatives) > 1 and length(lengths) == 1 ->
        alternatives
        |> Enum.zip()
        |> Enum.map(fn codes -> codes |> Tuple.to_list() |> artifact_group() end)

      true ->
        alternatives
        |> List.flatten()
        |> Enum.map(&artifact_group/1)
    end
  end

  defp extract_artifact_codes(cell) do
    cell
    |> extract_code_spans()
    |> Enum.filter(&artifact_code?/1)
  end

  defp extract_code_spans(cell) do
    ~r/`([^`]+)`/
    |> Regex.scan(cell || "")
    |> Enum.map(fn [_match, value] -> String.trim(value) end)
  end

  defp artifact_code?(code) do
    String.contains?(code, ["/", "*", ".md"])
  end

  defp artifact_group(code) when is_binary(code), do: artifact_group([code])

  defp artifact_group(codes) when is_list(codes) do
    %{
      label: Enum.join(codes, " 또는 "),
      patterns: codes |> Enum.flat_map(&patterns_for_code/1) |> Enum.uniq()
    }
  end

  defp stage_decision_artifact_group do
    %{
      label: "stage 판단 기록",
      patterns: ["stage-decisions.json"]
    }
  end

  defp patterns_for_code(code) do
    if String.contains?(code, "/") do
      [code]
    else
      [code, Path.join("subagents", code)]
    end
  end

  defp merge_artifact_groups(artifact_groups) do
    {order, groups_by_label} =
      Enum.reduce(artifact_groups, {[], %{}}, &put_artifact_group/2)

    Enum.map(order, &Map.fetch!(groups_by_label, &1))
  end

  defp put_artifact_group(artifact_group, {order, groups_by_label}) do
    if Map.has_key?(groups_by_label, artifact_group.label) do
      {order, update_artifact_group_patterns(groups_by_label, artifact_group)}
    else
      {order ++ [artifact_group.label], Map.put(groups_by_label, artifact_group.label, artifact_group)}
    end
  end

  defp update_artifact_group_patterns(groups_by_label, artifact_group) do
    Map.update!(groups_by_label, artifact_group.label, fn existing_group ->
      %{existing_group | patterns: Enum.uniq(existing_group.patterns ++ artifact_group.patterns)}
    end)
  end
end
