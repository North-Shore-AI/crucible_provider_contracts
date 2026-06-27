# Provider ABI Migration

This guide describes the concrete callback shapes expected by
`Crucible.Provider`. Providers must pass the shared contract suite with real
surface, capability, compiled-plan, and trace data. Placeholder atoms and
smoke-only callbacks are not contract-compliant.

## Required Callback Flow

1. `init/1` returns `{:ok, state}` only after the provider has enough state to
   answer lifecycle and metadata callbacks.
2. `surface/3` returns `{:ok, %CrucibleTap.Surface{}}`. The surface must include
   observable `CrucibleTap.SurfaceNode` entries for every supported tap class.
3. `capabilities/1` returns `{:ok, %Crucible.CapabilityReport{}}` or a
   backwards-compatible map. New providers should return the struct.
4. `compile/4` negotiates a `%CrucibleTap.TapPlan{}` against the supplied
   surface and returns `{:ok, %CrucibleTap.CompiledPlan{}}` or a real provider
   compilation artifact. Required unsupported taps must fail closed with
   `{:error, {:tap_compile_failed, %Crucible.CapabilityReport{}}}`.
5. `forward/4` returns `{:ok, %Crucible.ForwardTrace{}}`; traces must contain a
   non-empty `trace_id` and canonical signal records for captured tensors.
6. `generate/4` returns `{:ok, result}` or `{:error, reason}`. When generation
   produces model-internal evidence, prefer a `%Crucible.ForwardTrace{}`.

## Contract Test Usage

```elixir
defmodule MyProviderContractTest do
  use ExUnit.Case, async: true

  use Crucible.Provider.ContractTest,
    provider: MyProvider,
    init_opts: [model_id: "model:real"],
    model_ref: "model:real",
    input: %{prompt: "hello"},
    skip_generate?: false
end
```

Use `skip_generate?: true` only for provider classes that intentionally do not
support generation, such as replay-only trace providers or pure simulator
providers.

## Runtime Adapter Guidance

Runtime supervisors may keep local provider behaviours during migration, but the
adapter boundary should preserve the formal ABI:

- Convert local surface callbacks into `%CrucibleTap.Surface{}`.
- Compile `tap_plan` before execution when one is supplied.
- Keep provider-specific backend options inside provider packages, not in
  `crucible_tap`.
- Propagate canonical capability reports into emitted traces.
- Fail closed for unsupported required taps; optional taps may degrade with
  evidence recorded in `optional_dropped`.
