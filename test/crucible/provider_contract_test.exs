defmodule Crucible.Provider.ContractVerificationTest do
  # Define a compliant mock provider within the test to exercise the shared test macro
  defmodule MockProvider do
    @behaviour Crucible.Provider

    def init(opts) do
      {:ok, %{opts: opts, ready: true}}
    end

    def surface(_state, _model_ref, _opts) do
      {:ok, surface()}
    end

    def capabilities(_state) do
      {:ok,
       Crucible.CapabilityReport.new(
         provider_kind: :model,
         model_id: "mock-model-v1",
         model_family: :mock_transformer,
         backend: :mock_backend,
         supported: ["contract-final-logits"]
       )}
    end

    def compile(_state, tap_plan, surface, _opts) do
      case Crucible.CapabilityReport.negotiate(tap_plan, surface,
             provider_kind: :model,
             model_id: "mock-model-v1",
             backend: :mock_backend
           ) do
        {:ok, compiled, _report} -> {:ok, compiled}
        {:error, reason} -> {:error, reason}
      end
    end

    def forward(_state, _inputs, _compiled_plan, _opts) do
      {:ok, trace()}
    end

    def generate(_state, _inputs, _compiled_plan, _opts) do
      {:ok, trace()}
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

    defp surface do
      CrucibleTap.Surface.new!(
        adapter: :mock,
        model_family: :mock_transformer,
        metadata: %{surface_id: :mock_transformer},
        nodes: [
          [
            id: "lm_head.output",
            signal_type: :final_logits,
            layer_name: "lm_head.output",
            layer_index: :final,
            operations: [:read],
            capture_modes: [:summary]
          ]
        ]
      )
    end

    defp trace do
      trace_id = "trace-contract"
      run_id = "run-contract"
      logits = Nx.tensor([[0.1, 0.4, 0.2]], type: :f32)
      summary = Crucible.TensorSummary.compute(logits, entropy: true, top_k: 3)

      signal =
        Crucible.SignalRecord.new!(
          signal_id: "sig-contract-final-logits",
          trace_id: trace_id,
          run_id: run_id,
          signal_type: :final_logits,
          provider_kind: :model,
          model_id: "mock-model-v1",
          model_family: :mock_transformer,
          backend: :mock_backend,
          dtype: summary.dtype,
          shape: summary.shape,
          rank: summary.rank,
          node_name: "lm_head.output",
          capture_method: :contract_test,
          surface_id: :mock_transformer,
          capability_status: :captured,
          tensor_summary: summary,
          metadata: %{}
        )

      Crucible.ForwardTrace.new!(
        trace_id: trace_id,
        run_id: run_id,
        provider_kind: :model,
        model_id: "mock-model-v1",
        model_family: :mock_transformer,
        backend: :mock_backend,
        final_logits: signal,
        signals: [signal],
        status: :ok
      )
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
