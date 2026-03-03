# Business Central End-to-End Tests

This directory contains end-to-end tests for Business Central using the
[`@microsoft/bc-replay`](https://www.npmjs.com/package/@microsoft/bc-replay) package,
which is based on Playwright.

## How It Works

Business Central's **Page Scripting** tool lets you record your interactions with the
UI and save them as YAML files. These recordings can then be replayed automatically
via `bc-replay` — a Playwright-based test runner from Microsoft.

```
BC UI (record) → YAML file → bc-replay → Playwright → Test results
```

## Directory Structure

```
tests/
├── recordings/          # YAML page script recordings (the actual test files)
│   └── example-customer-list.yml
├── results/             # Test run output (git-ignored)
├── package.json         # npm package with bc-replay dependency
├── run-tests.js         # Test runner script
└── README.md            # This file
```

## Prerequisites

- Node.js 16.14.0 or later
- A Business Central environment (on-premises, online, or Docker)
- A BC user account with `PAGESCRIPTING - PLAY` permission set

## Setup

```bash
cd tests
npm install
```

## Creating Test Recordings

1. Open Business Central in your browser
2. Click the **Settings** gear icon → **Page Scripting**
3. Click **Start new** to begin recording
4. Perform the business process you want to test
5. Click **Stop**, then **Save** to download the YAML file
6. Place the YAML file in `tests/recordings/`

For more details, see the [BC Page Scripting documentation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-page-scripting).

## Running Tests

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BC_START_ADDRESS` | **Yes** | — | BC web client URL (e.g. `https://mybc.example.com/BC/`) |
| `BC_AUTH` | No | `UserPassword` | Auth type: `Windows`, `AAD`, or `UserPassword` |
| `BC_USERNAME` | Yes* | — | BC username (*when using UserPassword or AAD auth) |
| `BC_PASSWORD` | Yes* | — | BC password (*when using UserPassword or AAD auth) |
| `BC_USERNAME_KEY` | No | `BC_USERNAME` | Env var name for the username |
| `BC_PASSWORD_KEY` | No | `BC_PASSWORD` | Env var name for the password |
| `BC_TESTS_GLOB` | No | `recordings/*.yml` | Glob pattern for test files |
| `BC_RESULT_DIR` | No | `results` | Directory for test results |
| `BC_HEADED` | No | `false` | Set to `true` to show the browser |

### Run all tests

```bash
cd tests
export BC_START_ADDRESS=https://mybc.example.com/BC/
export BC_USERNAME=testuser@example.com
export BC_PASSWORD=MySecurePassword

npm test
```

### View results

```bash
npm run report
```

### Run headed (watch the browser)

```bash
npm run test:headed
```

## Writing Tests (for Agents)

When implementing a Business Central feature as an agent, you should:

1. **Record a test** in the BC UI that exercises the feature you implemented
2. **Save the YAML** to `tests/recordings/<feature-name>.yml`
3. **Run the test** locally to verify it passes (requires a BC environment)
4. **Commit the YAML** alongside your feature code

### Example workflow

After implementing a new sales order creation feature:

1. Record: Open BC → create a sales order → save recording as `create-sales-order.yml`
2. Place in `tests/recordings/create-sales-order.yml`
3. Run: `npm test` (with a test BC environment configured)
4. Commit the recording with the feature code

### Tips for good recordings

- Start from a **well-known location** like the role center
- Create **new test data** in each recording — don't depend on existing data
- Use **parameters** for environment-specific values (dates, IDs)
- Break large tests into **smaller reusable recordings** using `include` steps
- Add **validate steps** to assert expected outcomes

## CI Integration

Tests run automatically in the `bc-e2e-tests` GitHub Actions workflow when:
- YAML files in `tests/recordings/` are modified, or
- The workflow is triggered manually

Secrets required in the repository/environment:
- `BC_START_ADDRESS` — Business Central URL
- `BC_USERNAME` — Test automation user
- `BC_PASSWORD` — Test automation password
