defmodule SymphonyElixir.Linear.Project do
  @moduledoc """
  Normalized Linear project representation used to discover issue scopes from Linear.
  """

  defstruct [
    :id,
    :name,
    :slug,
    :url
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          slug: String.t() | nil,
          url: String.t() | nil
        }
end
