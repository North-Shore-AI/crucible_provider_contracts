# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

- Initial release of the formal Crucible Provider contract and ABI validation specification.
- Added `Crucible.Provider` behaviour defining standard callbacks for initialization, capability reporting, model surface inspection, compile planning, execution flow (`forward`/`generate`), health checks, and lifecycle teardown.
- Implemented core shared structs:
  - `Crucible.Provider.RuntimeRef` for managing stateful provider pointers.
  - `Crucible.Provider.ProviderHealth` for detailed diagnostic snapshots.
  - `Crucible.Provider.ProviderError` standardizing error taxonomy.
  - `Crucible.Provider.TraceEmission` outlining compliance obligations for forward/generation-pass results.
- Added a reusable contract compliance test suite to systematically validate custom providers (sim, models, world-models, and edge hardware).
