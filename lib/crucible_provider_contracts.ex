defmodule CrucibleProviderContracts do
  @moduledoc """
  Formal Provider behaviour, ABI specifications, shared structs, and contract test suites for Crucible.
  """

  @version Mix.Project.config()[:version]

  @doc "Returns the package version."
  def version, do: @version

  @doc "Returns the standard list of supported provider kinds."
  def provider_kinds do
    [
      :model,
      :sim,
      :robot,
      :world_model,
      :replay,
      :external_trace,
      :safety
    ]
  end
end
