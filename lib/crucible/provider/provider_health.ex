defmodule Crucible.Provider.ProviderHealth do
  @moduledoc """
  Stores diagnostic and health snapshots of a provider.
  """

  @derive Jason.Encoder
  defstruct [
    :status,
    :uptime_seconds,
    :last_latency_ms,
    :error_count,
    :memory_bytes,
    details: %{}
  ]

  @type t :: %__MODULE__{
          status: :ok | :degraded | :failed | :initializing,
          uptime_seconds: non_neg_integer(),
          last_latency_ms: number() | nil,
          error_count: non_neg_integer(),
          memory_bytes: non_neg_integer() | nil,
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
      {:ok, health} -> health
      {:error, reason} -> raise ArgumentError, "invalid ProviderHealth: #{inspect(reason)}"
    end
  end
end
