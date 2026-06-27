defmodule Crucible.Provider.MechInterpCapabilitiesTest do
  use ExUnit.Case, async: true

  alias Crucible.Provider.MechInterpCapabilities

  test "builds a runtime-neutral mech-interp capability report" do
    capabilities =
      MechInterpCapabilities.new!(
        provider: :emlx_qwen3,
        model_family: :qwen3,
        backend: :emlx,
        capture_groups: [:cache_metadata, :attention_qkv, :residual_streams],
        activations: %{
          "blocks.0.attn.hook_q" => %{axes: [:batch, :head, :position, :head_dim]},
          "unembed.hook_logits" => %{axes: [:batch, :d_vocab]}
        },
        generation_trace: true,
        cache_metadata: true,
        interventions: %{residual: true, head_ablation: false},
        lazy_tensors: true,
        unsupported: [:head_ablation_intervention],
        dependency: %{repo: "https://github.com/North-Shore-AI/emlx.git"}
      )

    assert capabilities.provider == :emlx_qwen3
    assert MechInterpCapabilities.supports?(capabilities, :generation_trace)
    assert MechInterpCapabilities.supports?(capabilities, :cache_metadata)
    assert MechInterpCapabilities.supports?(capabilities, :lazy_tensors)
    assert MechInterpCapabilities.supports?(capabilities, {:capture_group, :attention_qkv})
    assert MechInterpCapabilities.supports?(capabilities, {:activation, "blocks.0.attn.hook_q"})
    assert MechInterpCapabilities.supports?(capabilities, {:intervention, :residual})
    refute MechInterpCapabilities.supports?(capabilities, {:intervention, :head_ablation})
  end

  test "rejects claim-bearing fields with invalid shapes" do
    assert {:error, {:invalid_atom_list, :capture_groups}} =
             MechInterpCapabilities.new(capture_groups: ["attention_qkv"])

    assert {:error, {:invalid_boolean, :generation_trace}} =
             MechInterpCapabilities.new(generation_trace: :yes)

    assert {:error, :invalid_activations} =
             MechInterpCapabilities.new(activations: %{hook_logits: %{}})
  end
end
