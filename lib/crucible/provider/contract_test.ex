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
      end
    end
  end
end
