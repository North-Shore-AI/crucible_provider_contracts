defmodule Crucible.Provider.TraceEmission do
  @moduledoc """
  Encapsulates tracing obligations, ensuring output traces contain mandatory temporal annotations and source environment tags.
  """

  @derive Jason.Encoder
  defstruct [
    :trace_id,
    :episode_id,
    :environment,
    :realtime_clock_ns,
    :duration_ns,
    :temporal_ref,
    :signals_count
  ]

  @type environment :: :sim | :sim_dr | :real | :replay | :imagination

  @type temporal_ref :: %{
          t_ns: integer(),
          rate_hint_hz: number(),
          lease_id: binary() | nil
        }

  @type t :: %__MODULE__{
          trace_id: binary(),
          episode_id: binary() | nil,
          environment: environment(),
          realtime_clock_ns: integer(),
          duration_ns: integer(),
          temporal_ref: temporal_ref(),
          signals_count: non_neg_integer()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    {:ok, struct(__MODULE__, attrs)}
  end

  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, emission} -> emission
      {:error, reason} -> raise ArgumentError, "invalid TraceEmission: #{inspect(reason)}"
    end
  end
end
