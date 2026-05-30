defmodule CrucibleProviderContractsTest do
  use ExUnit.Case, async: true

  test "returns the correct version" do
    assert is_binary(CrucibleProviderContracts.version())
  end

  test "returns the standard provider kinds" do
    kinds = CrucibleProviderContracts.provider_kinds()
    assert is_list(kinds)
    assert :model in kinds
    assert :sim in kinds
    assert :robot in kinds
  end
end
