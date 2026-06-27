<p align="center">
  <img src="assets/crucible_provider_contracts.svg" width="200" height="200" alt="crucible_provider_contracts logo" />
</p>

<p align="center">
  <a href="https://github.com/North-Shore-AI/crucible_provider_contracts">
    <img alt="GitHub: crucible_provider_contracts" src="https://img.shields.io/badge/GitHub-crucible__provider__contracts-0b0f14?logo=github" />
  </a>
  <a href="https://github.com/North-Shore-AI/crucible_provider_contracts/blob/main/LICENSE">
    <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-0b0f14.svg" />
  </a>
</p>

# CrucibleProviderContracts

Formal Provider behaviour, ABI specifications, shared structs, and contract test suites for Crucible model and robotics providers. Standardizes initializations, capabilities, plan compilation, and execution for simulation, model serving, physical robots, and safety systems within the Crucible architecture.

## Stack Position

`crucible_provider_contracts` is the formal interface boundary package of the Crucible forward-pass substrate. It sits directly above `crucible_signal` and `crucible_tap`, freezing the Application Binary Interface (ABI) for all downstream models, simulator runtimes (Isaac Lab, MuJoCo, Drake), safety-shield layers, and device bridges (ROS 2, physical arms).

By establishing a rigid, formal contract, it prevents runtime providers from developing ad-hoc interfaces, eliminating the risk of creating a fragile "glue universe" inside Elixir.

## Installation

```elixir
def deps do
  [
    {:crucible_provider_contracts, "~> 0.1.0"}
  ]
end
```

## Boundary

This package defines:
- **`Crucible.Provider`**: The central callback specification that every model, simulator, world model, and safety shield must implement.
- **Shared Structs**: Struct definitions for managing runtime stateful pointers, error taxonomy, health diagnostics, and emission obligations.
- **Contract Test Suite**: A standard verification engine using Mox-style principles to validate provider conformance before they are registered by the supervisor runtime.

---

## The Provider Behaviour

Every provider implements the `Crucible.Provider` behaviour:

```elixir
defmodule Crucible.Provider do
  @moduledoc """
  Formal behaviour representing a Crucible runtime provider.
  """

  @type state :: term()
  @type opts :: keyword()
  @type model_ref :: term()
  @type inputs :: map()

  @doc "Initializes the provider state with given options."
  @callback init(opts) :: {:ok, state} | {:error, term}

  @doc "Inspects and returns the available model surface (layers, parameters, tensors)."
  @callback surface(state, model_ref, opts) ::
              {:ok, CrucibleTap.Surface.t()} | {:error, term}

  @doc "Retrieves the standard capability report from the provider."
  @callback capabilities(state) :: {:ok, Crucible.CapabilityReport.t()} | {:error, term}

  @doc "Compiles a TapPlan against the model surface into a CompiledPlan."
  @callback compile(state, CrucibleTap.TapPlan.t(), CrucibleTap.Surface.t(), opts) ::
              {:ok, CrucibleTap.CompiledPlan.t()} | {:error, term}

  @doc "Executes a standard forward pass producing a ForwardTrace."
  @callback forward(state, inputs, CrucibleTap.CompiledPlan.t() | nil, opts) ::
              {:ok, Crucible.ForwardTrace.t()} | {:error, term}

  @doc "Executes a text/token generation step producing a provider result."
  @callback generate(state, inputs, CrucibleTap.CompiledPlan.t() | nil, opts) ::
              {:ok, Crucible.ForwardTrace.t() | term()} | {:error, term}

  @doc "Returns true if the provider is fully ready to accept execution."
  @callback ready?(state) :: boolean()

  @doc "Fetches a diagnostic health snapshot of the provider."
  @callback health(state) :: Crucible.Provider.ProviderHealth.t()

  @doc "Returns the kind/classification of the provider."
  @callback provider_kind(state) ::
              :model
              | :sim
              | :robot
              | :world_model
              | :replay
              | :external_trace
              | :safety

  @doc "Returns the underlying model reference if applicable, or nil."
  @callback model_ref(state) :: model_ref | nil

  @doc "Returns the backend atom representing the execution runtime."
  @callback backend(state) :: atom()

  @doc "Teardown the provider state and release any external resource locks."
  @callback shutdown(state, reason :: term()) :: :ok
end
```

---

## Struct Taxonomy

To ensure robust data boundaries across provider implementations, `CrucibleProviderContracts` includes standard structs:

1. **`Crucible.Provider.RuntimeRef`**: Manages stateful pointers to providers, identifying them in the supervision registry.
2. **`Crucible.Provider.ProviderHealth`**: Stores uptime, latencies, memory pressure, and status logs.
3. **`Crucible.Provider.ProviderError`**: Formally maps errors into a standard taxonomy (e.g., `:compilation_failed`, `:resource_locked`, `:out_of_bounds_input`, `:telemetry_dropped`).
4. **`Crucible.Provider.TraceEmission`**: Encapsulates tracing obligations, ensuring output traces contain mandatory temporal annotations and source environment tags (`:sim`, `:real`, etc.).

---

## Contract Verification Suite

Every new provider must pass the standard contract test suite to be accepted by the self-hosted inference core (`SHIC`). The verification suite ensures:

- Proper response to initialization parameters and graceful shutdown.
- Canonical `CrucibleTap.Surface`, `Crucible.CapabilityReport`,
  `CrucibleTap.CompiledPlan`, and `Crucible.ForwardTrace` return shapes.
- Sound emission of trace identifiers and final forward-pass trace records.

For example, when writing a custom MuJoCo simulator provider, you can mix in the contract tests:

```elixir
defmodule Crucible.Provider.MujocoProviderTest do
  use ExUnit.Case, async: true
  
  # Inject standard compliance assertions
use Crucible.Provider.ContractTest,
  provider: Crucible.Provider.Mujoco,
  init_opts: [scene: :double_pendulum],
  model_ref: "mujoco:double_pendulum",
  input: %{state: [0.0, 0.0]}
end
```

See [Provider ABI Migration](guides/provider_abi_migration.md) for callback
shape requirements and adapter guidance.

## Testing

- Run standard tests: `mix test`
- Format check and full gate: `mix ci`
