# Developer Agent Memory

## Business Central Testing

This repo uses **`@microsoft/bc-replay`** for end-to-end testing of Business Central.

### Key facts
- Tests are YAML files in `tests/recordings/` (BC Page Script format)
- Run with: `cd tests && npm test` (requires BC env vars)
- Required env vars: `BC_START_ADDRESS`, `BC_USERNAME`, `BC_PASSWORD`
- YAML recordings are created by recording in the BC UI (Settings → Page Scripting)
- The CI workflow `bc-e2e-tests.yml` runs tests on recording changes

### When to write tests
- After implementing any BC feature, write a YAML recording for it
- Commit the YAML even without a live BC environment — it runs in CI

### References
- `tests/README.md` — full setup and usage documentation
- `docs/plans/2026-03-03-bc-playwright-e2e-design.md` — design decisions
- https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-page-scripting
