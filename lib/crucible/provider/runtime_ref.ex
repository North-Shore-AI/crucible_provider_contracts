defmodule Crucible.Provider.RuntimeRef do
  @moduledoc """
  Manages stateful pointers to providers, identifying them in the supervision registry.
  """

  @derive Jason.Encoder
  defstruct [
    :provider_id,
    :provider_kind,
    :pid,
    :backend,
    :model_ref,
    node: :nonode@nohost
  ]

  @type t :: %__MODULE__{
          provider_id: binary(),
          provider_kind:
            :model
            | :sim
            | :robot
            | :world_model
            | :replay
            | :external_trace
            | :safety,
          pid: pid() | nil,
          backend: atom(),
          model_ref: term() | nil,
          node: atom()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    {:ok, struct(__MODULE__, attrs)}
  end

  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, ref} -> ref
      {:error, reason} -> raise ArgumentError, "invalid RuntimeRef: #{inspect(reason)}"
    end
  end
end
