defmodule Crucible.Provider.ProviderError do
  @moduledoc """
  Standardized taxonomy of provider errors.
  """

  @derive Jason.Encoder
  defstruct [
    :type,
    :message,
    :provider_id,
    details: %{}
  ]

  @type error_type ::
          :compilation_failed
          | :resource_locked
          | :out_of_bounds_input
          | :telemetry_dropped
          | :internal_error
          | :unsupported_capability
          | :timeout

  @type t :: %__MODULE__{
          type: error_type(),
          message: binary(),
          provider_id: binary() | nil,
          details: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    {:ok, struct(__MODULE__, attrs)}
  end

  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, error} -> error
      {:error, reason} -> raise ArgumentError, "invalid ProviderError: #{inspect(reason)}"
    end
  end
end
