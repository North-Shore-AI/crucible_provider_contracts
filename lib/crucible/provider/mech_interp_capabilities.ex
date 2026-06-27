defmodule Crucible.Provider.MechInterpCapabilities do
  @moduledoc """
  Standard capability report for model-internals providers.

  This struct is intentionally runtime-neutral. Bumblebee, EMLX, EXLA, Torchx,
  replay providers, and external trace providers can all report the same capture,
  intervention, cache, and generation-trace surface without depending on one
  another.
  """

  @derive Jason.Encoder
  defstruct provider: nil,
            model_family: nil,
            backend: nil,
            capture_groups: [],
            activations: %{},
            generation_trace: false,
            cache_metadata: false,
            interventions: %{},
            lazy_tensors: false,
            unsupported: [],
            dependency: nil,
            metadata: %{}

  @type t :: %__MODULE__{
          provider: atom() | nil,
          model_family: atom() | nil,
          backend: atom() | nil,
          capture_groups: [atom()],
          activations: %{optional(binary()) => map()},
          generation_trace: boolean(),
          cache_metadata: boolean(),
          interventions: %{optional(atom()) => boolean()},
          lazy_tensors: boolean(),
          unsupported: [atom()],
          dependency: map() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    normalized = normalize(attrs)

    with :ok <- validate_atoms(normalized.capture_groups, :capture_groups),
         :ok <- validate_atoms(normalized.unsupported, :unsupported),
         :ok <- validate_boolean(normalized.generation_trace, :generation_trace),
         :ok <- validate_boolean(normalized.cache_metadata, :cache_metadata),
         :ok <- validate_boolean(normalized.lazy_tensors, :lazy_tensors),
         :ok <- validate_interventions(normalized.interventions),
         :ok <- validate_activations(normalized.activations) do
      {:ok, normalized}
    end
  end

  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, capabilities} ->
        capabilities

      {:error, reason} ->
        raise ArgumentError, "invalid MechInterpCapabilities: #{inspect(reason)}"
    end
  end

  @doc "Returns true when the capability report supports the requested feature."
  @spec supports?(t(), atom() | tuple()) :: boolean()
  def supports?(%__MODULE__{generation_trace: enabled?}, :generation_trace), do: enabled?
  def supports?(%__MODULE__{cache_metadata: enabled?}, :cache_metadata), do: enabled?
  def supports?(%__MODULE__{lazy_tensors: enabled?}, :lazy_tensors), do: enabled?

  def supports?(%__MODULE__{capture_groups: groups}, {:capture_group, group})
      when is_atom(group) do
    group in groups
  end

  def supports?(%__MODULE__{activations: activations}, {:activation, activation_name})
      when is_binary(activation_name) do
    Map.has_key?(activations, activation_name)
  end

  def supports?(%__MODULE__{interventions: interventions}, {:intervention, kind})
      when is_atom(kind) do
    Map.get(interventions, kind, false)
  end

  def supports?(_capabilities, _feature), do: false

  defp normalize(attrs) do
    %__MODULE__{
      provider: Map.get(attrs, :provider),
      model_family: Map.get(attrs, :model_family),
      backend: Map.get(attrs, :backend),
      capture_groups: Map.get(attrs, :capture_groups, []),
      activations: Map.get(attrs, :activations, %{}),
      generation_trace: Map.get(attrs, :generation_trace, false),
      cache_metadata: Map.get(attrs, :cache_metadata, false),
      interventions: Map.get(attrs, :interventions, %{}),
      lazy_tensors: Map.get(attrs, :lazy_tensors, false),
      unsupported: Map.get(attrs, :unsupported, []),
      dependency: Map.get(attrs, :dependency),
      metadata: Map.get(attrs, :metadata, %{})
    }
  end

  defp validate_atoms(list, field) when is_list(list) do
    if Enum.all?(list, &is_atom/1), do: :ok, else: {:error, {:invalid_atom_list, field}}
  end

  defp validate_atoms(_other, field), do: {:error, {:invalid_atom_list, field}}

  defp validate_boolean(value, _field) when is_boolean(value), do: :ok
  defp validate_boolean(_value, field), do: {:error, {:invalid_boolean, field}}

  defp validate_interventions(interventions) when is_map(interventions) do
    if Enum.all?(interventions, fn {key, value} -> is_atom(key) and is_boolean(value) end) do
      :ok
    else
      {:error, :invalid_interventions}
    end
  end

  defp validate_interventions(_other), do: {:error, :invalid_interventions}

  defp validate_activations(activations) when is_map(activations) do
    if Enum.all?(activations, fn {key, value} -> is_binary(key) and is_map(value) end) do
      :ok
    else
      {:error, :invalid_activations}
    end
  end

  defp validate_activations(_other), do: {:error, :invalid_activations}
end
