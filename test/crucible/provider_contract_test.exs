defmodule Crucible.Provider.ContractVerificationTest do
  # Define a compliant mock provider within the test to exercise the shared test macro
  defmodule MockProvider do
    @behaviour Crucible.Provider

    def init(opts) do
      {:ok, %{opts: opts, ready: true}}
    end

    def surface(_state, _model_ref, _opts) do
      {:ok, :mock_surface}
    end

    def capabilities(_state) do
      {:ok, :mock_capabilities}
    end

    def compile(_state, _tap_plan, _surface, _opts) do
      {:ok, :mock_compiled_plan}
    end

    def forward(_state, _inputs, _compiled_plan, _opts) do
      {:ok, :mock_trace}
    end

    def generate(_state, _inputs, _compiled_plan, _opts) do
      {:ok, :mock_trace}
    end

    def ready?(state) do
      state.ready
    end

    def health(_state) do
      Crucible.Provider.ProviderHealth.new!(
        status: :ok,
        uptime_seconds: 42,
        last_latency_ms: 1.5,
        error_count: 0,
        memory_bytes: 1024,
        details: %{mode: :test}
      )
    end

    def provider_kind(_state) do
      :model
    end

    def model_ref(_state) do
      "mock-model-v1"
    end

    def backend(_state) do
      :mock_backend
    end

    def shutdown(_state, _reason) do
      :ok
    end
  end

  use ExUnit.Case, async: true

  # Exercise the shared contract test macro
  use Crucible.Provider.ContractTest,
    provider: MockProvider,
    init_opts: [backend: :mock_backend]

  test "struct creation: RuntimeRef" do
    ref =
      Crucible.Provider.RuntimeRef.new!(
        provider_id: "prov-1",
        provider_kind: :sim,
        pid: self(),
        backend: :mujoco,
        model_ref: nil,
        node: node()
      )

    assert ref.provider_id == "prov-1"
    assert ref.provider_kind == :sim
    assert ref.pid == self()
  end

  test "struct creation: ProviderError" do
    err =
      Crucible.Provider.ProviderError.new!(
        type: :compilation_failed,
        message: "Simulation compilation timed out",
        provider_id: "mujoco-1"
      )

    assert err.type == :compilation_failed
    assert err.message == "Simulation compilation timed out"
  end

  test "struct creation: TraceEmission" do
    emission =
      Crucible.Provider.TraceEmission.new!(
        trace_id: "trace-abc",
        episode_id: "ep-123",
        environment: :sim,
        realtime_clock_ns: 1_700_000_000_000_000,
        duration_ns: 15_000_000,
        temporal_ref: %{
          t_ns: 50_000_000,
          rate_hint_hz: 50.0,
          lease_id: "lease-xyz"
        },
        signals_count: 12
      )

    assert emission.trace_id == "trace-abc"
    assert emission.environment == :sim
    assert emission.temporal_ref.rate_hint_hz == 50.0
  end
end
