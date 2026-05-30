defmodule Crucible.Provider do
  @moduledoc """
  Formal behaviour representing a Crucible runtime provider (e.g. models, simulators,
  world models, safety shields, and robotics bridges).
  """

  @type state :: term()
  @type opts :: keyword()
  @type model_ref :: term()
  @type inputs :: map()

  @doc """
  Initializes the provider state with given options.
  """
  @callback init(opts) :: {:ok, state} | {:error, term}

  @doc """
  Inspects and returns the available model surface (layers, parameters, tensors).
  """
  @callback surface(state, model_ref, opts) :: {:ok, term} | {:error, term}

  @doc """
  Retrieves the standard capability report from the provider.
  """
  @callback capabilities(state) :: {:ok, term} | {:error, term}

  @doc """
  Compiles a TapPlan against the model surface into a CompiledPlan.
  """
  @callback compile(state, term, term, opts) ::
              {:ok, term} | {:error, term}

  @doc """
  Executes a standard forward pass producing a ForwardTrace.
  """
  @callback forward(state, inputs, term, opts) ::
              {:ok, term} | {:error, term}

  @doc """
  Executes a text/token generation step producing a ForwardTrace.
  """
  @callback generate(state, inputs, term, opts) ::
              {:ok, term} | {:error, term}

  @doc """
  Returns true if the provider is fully ready to accept execution.
  """
  @callback ready?(state) :: boolean()

  @doc """
  Fetches a diagnostic health snapshot of the provider.
  """
  @callback health(state) :: Crucible.Provider.ProviderHealth.t()

  @doc """
  Returns the kind/classification of the provider.
  """
  @callback provider_kind(state) ::
              :model
              | :sim
              | :robot
              | :world_model
              | :replay
              | :external_trace
              | :safety

  @doc """
  Returns the underlying model reference if applicable, or nil.
  """
  @callback model_ref(state) :: model_ref | nil

  @doc """
  Returns the backend atom representing the execution runtime.
  """
  @callback backend(state) :: atom()

  @doc """
  Teardown the provider state and release any external resource locks.
  """
  @callback shutdown(state, reason :: term()) :: :ok
end
