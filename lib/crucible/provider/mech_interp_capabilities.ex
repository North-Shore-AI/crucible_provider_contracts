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
            required_capture_groups: [],
            activations: %{},
            required_activations: [],
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
          required_capture_groups: [atom()],
          activations: %{optional(binary()) => map()},
          required_activations: [binary()],
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
         :ok <- validate_atoms(normalized.required_capture_groups, :required_capture_groups),
         :ok <- validate_atoms(normalized.unsupported, :unsupported),
         :ok <- validate_boolean(normalized.generation_trace, :generation_trace),
         :ok <- validate_boolean(normalized.cache_metadata, :cache_metadata),
         :ok <- validate_boolean(normalized.lazy_tensors, :lazy_tensors),
         :ok <- validate_strings(normalized.required_activations, :required_activations),
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

  @doc """
  Validates that a provider emission satisfies the capability report.

  By default this checks `required_activations` and `required_capture_groups`.
  Pass `require_claimed_activations?: true` when contract tests need every
  advertised activation in `activations` to appear in a concrete emission.
  """
  @spec validate_emissions(t(), term(), keyword()) ::
          :ok | {:error, {:capability_emission_mismatch, [term()]}}
  def validate_emissions(%__MODULE__{} = capabilities, emissions, opts \\ []) do
    emitted = MapSet.new(emitted_activation_names(emissions))

    required_activations =
      capabilities.required_activations ++ labels(Keyword.get(opts, :required_activations, []))

    claimed_activations =
      if Keyword.get(opts, :require_claimed_activations?, false) do
        Map.keys(capabilities.activations)
      else
        []
      end

    required_capture_groups =
      capabilities.required_capture_groups ++
        atom_labels(Keyword.get(opts, :required_capture_groups, []))

    reasons =
      []
      |> maybe_missing(:missing_required_activations, missing(required_activations, emitted))
      |> maybe_missing(:missing_claimed_activations, missing(claimed_activations, emitted))
      |> maybe_missing(
        :unsupported_required_capture_groups,
        unsupported_capture_groups(capabilities, required_capture_groups)
      )
      |> Enum.reverse()

    case reasons do
      [] -> :ok
      reasons -> {:error, {:capability_emission_mismatch, reasons}}
    end
  end

  defp normalize(attrs) do
    %__MODULE__{
      provider: Map.get(attrs, :provider),
      model_family: Map.get(attrs, :model_family),
      backend: Map.get(attrs, :backend),
      capture_groups: Map.get(attrs, :capture_groups, []),
      required_capture_groups: Map.get(attrs, :required_capture_groups, []),
      activations: Map.get(attrs, :activations, %{}),
      required_activations: labels(Map.get(attrs, :required_activations, [])),
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

  defp validate_strings(list, field) when is_list(list) do
    if Enum.all?(list, &is_binary/1), do: :ok, else: {:error, {:invalid_string_list, field}}
  end

  defp validate_strings(_other, field), do: {:error, {:invalid_string_list, field}}

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

  defp emitted_activation_names(%_{} = struct),
    do: emitted_activation_names(Map.from_struct(struct))

  defp emitted_activation_names(emissions) when is_list(emissions) do
    emissions
    |> Enum.flat_map(fn
      value when is_binary(value) -> [value]
      value when is_atom(value) -> [Atom.to_string(value)]
      value when is_map(value) -> emitted_activation_names(value)
      _other -> []
    end)
    |> Enum.uniq()
  end

  defp emitted_activation_names(%{} = emission) do
    cond do
      is_map(Map.get(emission, :activations)) ->
        emission |> Map.fetch!(:activations) |> Map.keys() |> labels()

      is_map(Map.get(emission, "activations")) ->
        emission |> Map.fetch!("activations") |> Map.keys() |> labels()

      is_list(Map.get(emission, :signals)) ->
        emission |> Map.fetch!(:signals) |> emitted_activation_names()

      is_list(Map.get(emission, "signals")) ->
        emission |> Map.fetch!("signals") |> emitted_activation_names()

      true ->
        activation_name(emission)
        |> List.wrap()
        |> Enum.reject(&is_nil/1)
    end
  end

  defp emitted_activation_names(_other), do: []

  defp activation_name(emission) when is_map(emission) do
    Map.get(emission, :activation_name) ||
      Map.get(emission, "activation_name") ||
      get_in(emission, [:metadata, :activation_name]) ||
      get_in(emission, ["metadata", "activation_name"])
  end

  defp missing(required, emitted) do
    required
    |> Enum.uniq()
    |> Enum.reject(&MapSet.member?(emitted, &1))
  end

  defp unsupported_capture_groups(%__MODULE__{} = capabilities, required_groups) do
    required_groups
    |> Enum.uniq()
    |> Enum.reject(&supports?(capabilities, {:capture_group, &1}))
  end

  defp maybe_missing(reasons, _kind, []), do: reasons
  defp maybe_missing(reasons, kind, values), do: [{kind, values} | reasons]

  defp labels(values) when is_list(values),
    do: values |> Enum.map(&label/1) |> Enum.reject(&is_nil/1)

  defp labels(nil), do: []
  defp labels(value), do: [label(value)]

  defp label(nil), do: nil
  defp label(value) when is_atom(value), do: Atom.to_string(value)
  defp label(value) when is_binary(value), do: value
  defp label(value), do: to_string(value)

  defp atom_labels(values) when is_list(values),
    do: values |> Enum.map(&atom_label/1) |> Enum.reject(&is_nil/1)

  defp atom_labels(nil), do: []
  defp atom_labels(value), do: [atom_label(value)]

  defp atom_label(nil), do: nil
  defp atom_label(value) when is_atom(value), do: value
  defp atom_label(value) when is_binary(value), do: String.to_atom(value)
end
