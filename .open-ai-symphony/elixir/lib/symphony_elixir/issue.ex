defmodule SymphonyElixir.Issue do
  @moduledoc """
  Normalized issue model used by tracker adapters and prompt rendering.
  """

  defstruct [
    :id,
    :identifier,
    :title,
    :description,
    :priority,
    :state,
    :branch_name,
    :url,
    :tracker,
    labels: [],
    blocked_by: [],
    created_at: nil,
    updated_at: nil,
    raw: nil
  ]

  @type t :: %__MODULE__{
          id: String.t() | integer() | nil,
          identifier: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          priority: integer() | nil,
          state: String.t() | nil,
          branch_name: String.t() | nil,
          url: String.t() | nil,
          tracker: :linear | :github | nil,
          labels: [String.t()],
          blocked_by: [map()],
          created_at: String.t() | nil,
          updated_at: String.t() | nil,
          raw: map() | nil
        }
end
