defmodule Crucible.Provider.ContractTest do
  @moduledoc """
  A shared contract test suite that custom providers can use to ensure compliance with the Crucible Provider behaviour and ABI.

  ## Usage

      defmodule MyProviderTest do
        use ExUnit.Case, async: true
        use Crucible.Provider.ContractTest,
          provider: MyProvider,
          init_opts: [some: "option"]
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @provider Keyword.fetch!(opts, :provider)
      @init_opts Keyword.get(opts, :init_opts, [])
      @model_ref Keyword.get(opts, :model_ref, nil)
      @tap_plan Keyword.get(opts, :tap_plan)
      @input Keyword.get(opts, :input, %{})
      @forward_opts Keyword.get(opts, :forward_opts, [])
      @generate_opts Keyword.get(opts, :generate_opts, [])
      @skip_generate? Keyword.get(opts, :skip_generate?, false)

      describe "#{inspect(@provider)} - Crucible.Provider contract compliance" do
        test "implements the Crucible.Provider behaviour" do
          behaviours = @provider.__info__(:attributes)[:behaviour] || []

          assert Crucible.Provider in behaviours,
                 "#{inspect(@provider)} must declare `@behaviour Crucible.Provider`"
        end

        test "exposes all required callbacks" do
          exports = @provider.__info__(:functions)

          required_callbacks = [
            init: 1,
            surface: 3,
            capabilities: 1,
            compile: 4,
            forward: 4,
            generate: 4,
            ready?: 1,
            health: 1,
            provider_kind: 1,
            model_ref: 1,
            backend: 1,
            shutdown: 2
          ]

          for {fun, arity} <- required_callbacks do
            assert Keyword.get(exports, fun) == arity,
                   "#{inspect(@provider)} does not export #{fun}/#{arity}"
          end
        end

        test "lifecycle compliance: init -> ready? -> health -> shutdown" do
          # 1. Initialize
          case @provider.init(@init_opts) do
            {:ok, state} ->
              # 2. Check ready?
              ready = @provider.ready?(state)
              assert is_boolean(ready), "ready?/1 must return a boolean"

              # 3. Check health
              health = @provider.health(state)

              assert %Crucible.Provider.ProviderHealth{} = health,
                     "health/1 must return a ProviderHealth struct"

              assert health.status in [:ok, :degraded, :failed, :initializing],
                     "health.status must be valid"

              # 4. Check kind
              kind = @provider.provider_kind(state)

              assert kind in [
                       :model,
                       :sim,
                       :robot,
                       :world_model,
                       :replay,
                       :external_trace,
                       :safety
                     ],
                     "provider_kind/1 must return a valid kind atom"

              # 5. Check backend and model_ref
              assert is_atom(@provider.backend(state)), "backend/1 must return an atom"
              _model_ref = @provider.model_ref(state)

              # 6. Graceful shutdown
              assert :ok == @provider.shutdown(state, :normal), "shutdown/2 must return :ok"

            {:error, reason} ->
              flunk("Failed to initialize provider: #{inspect(reason)}")
          end
        end

        test "tap ABI compliance: surface -> capabilities -> compile -> forward" do
          state = init_provider!(@provider, @init_opts)
          tap_plan = contract_tap_plan(@tap_plan)

          assert {:ok, %CrucibleTap.Surface{} = surface} =
                   @provider.surface(state, @model_ref, [])

          assert {:ok, capabilities} = @provider.capabilities(state)

          assert capability_report?(capabilities),
                 "capabilities/1 must return a capability report or map"

          assert {:ok, compiled_plan} = @provider.compile(state, tap_plan, surface, [])
          assert compiled_plan != nil, "compile/4 must return a non-nil compiled plan"

          assert {:ok, %Crucible.ForwardTrace{} = trace} =
                   @provider.forward(state, @input, compiled_plan, @forward_opts)

          assert trace.trace_id not in [nil, ""], "forward/4 trace must include trace_id"
          assert trace.status in [nil, :ok], "forward/4 trace status must be nil or :ok"

          assert :ok == @provider.shutdown(state, :normal)
        end

        if not @skip_generate? do
          test "generation ABI compliance" do
            state = init_provider!(@provider, @init_opts)
            tap_plan = contract_tap_plan(@tap_plan)

            assert {:ok, %CrucibleTap.Surface{} = surface} =
                     @provider.surface(state, @model_ref, [])

            assert {:ok, compiled_plan} = @provider.compile(state, tap_plan, surface, [])

            assert {:ok, result} =
                     @provider.generate(state, @input, compiled_plan, @generate_opts)

            assert result != nil, "generate/4 must return a non-nil provider result"

            assert :ok == @provider.shutdown(state, :normal)
          end
        end

        defp init_provider!(provider, init_opts) do
          case provider.init(init_opts) do
            {:ok, state} -> state
            {:error, reason} -> flunk("Failed to initialize provider: #{inspect(reason)}")
          end
        end

        defp contract_tap_plan(plan) do
          case plan do
            %CrucibleTap.TapPlan{} = plan ->
              plan

            nil ->
              CrucibleTap.TapPlan.new!(
                [
                  [
                    id: "contract-final-logits",
                    signal_type: :final_logits,
                    layers: [:final],
                    selector: %{layer_name: "lm_head.output"},
                    required?: true
                  ]
                ],
                plan_id: "contract-provider-final-logits"
              )
          end
        end

        defp capability_report?(%Crucible.CapabilityReport{}), do: true
        defp capability_report?(report) when is_map(report), do: true
        defp capability_report?(_report), do: false
      end
    end
  end
end
