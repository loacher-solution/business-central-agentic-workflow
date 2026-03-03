# Business Central End-to-End Tests

This directory contains Business Central page script recordings for automated
end-to-end (E2E) testing using the `@microsoft/bc-replay` Playwright-based runner.

## What Are Page Scripts?

Business Central page scripts are YAML files that record user interactions with the
BC web client. They are played back using `bc-replay`, which drives a Playwright
browser to replay the exact same actions.

Scripts are recorded using the **Page Scripting** tool in Business Central:
> Settings (gear icon) → Page Scripting

## Directory Structure

```
tests/e2e/
├── README.md               # This file
├── includes/               # Reusable sub-scripts (included by other scripts)
│   └── login.yml           # Example: shared login steps
└── example-open-chart-of-accounts.yml   # Example test
```

## How to Run Tests

### Prerequisites

- Node.js 16.14.0 or later
- A running Business Central environment
- Set environment variables:
  - `BC_URL` — URL to the BC web client (e.g. `https://businesscentral.dynamics.com/tenant/sandbox/`)
  - `BC_USERNAME` — test user account (for AAD/UserPassword auth)
  - `BC_PASSWORD` — test user password (for AAD/UserPassword auth)
  - `BC_AUTH` — authentication type: `Windows`, `AAD`, or `UserPassword` (default: `UserPassword`)

### Install bc-replay

```bash
npm install
```

### Run all E2E tests

```bash
npm run test:e2e
```

Or directly:

```bash
npx replay "tests/e2e/*.yml" \
  -StartAddress "$BC_URL" \
  -Authentication UserPassword \
  -UserNameKey BC_USERNAME \
  -PasswordKey BC_PASSWORD \
  -ResultDir results
```

### Run a specific test

```bash
npx replay "tests/e2e/example-open-chart-of-accounts.yml" \
  -StartAddress "$BC_URL" \
  -Authentication UserPassword \
  -UserNameKey BC_USERNAME \
  -PasswordKey BC_PASSWORD \
  -ResultDir results
```

### View test results

```bash
npm run test:e2e:report
```

## Writing New Tests

### Option 1: Record in Business Central (recommended)

1. Open Business Central in your browser
2. Navigate to Settings → Page Scripting
3. Click **Start new** to begin recording
4. Perform the actions you want to test
5. Click **Stop**, then **Save** to download the YAML file
6. Place the YAML file in `tests/e2e/`

### Option 2: Write YAML manually

Page scripts follow this structure:

```yaml
name: my-test
description: What this test verifies
start:
  profile: BUSINESS MANAGER   # or: ORDER PROCESSOR, ACCOUNTANT, etc.
steps:
  - type: goto
    page: 26                   # Page ID (e.g. 26 = Customer List)
    description: Open Customer List

  - type: action
    target:
      - page: Customer List
    action: New
    description: Create a new customer

  - type: input
    target:
      - page: Customer Card
        runtimeRef: auto
      - field: Name
    value: "Test Customer E2E"
    description: Enter customer name

  - type: validate
    target:
      - page: Customer Card
        runtimeRef: auto
      - field: Name
    operator: Equals
    value: "Test Customer E2E"
    description: Verify customer name was saved
```

### Step Types

| Type       | Purpose                                    |
|------------|--------------------------------------------|
| `goto`     | Navigate to a page by ID or name           |
| `action`   | Trigger an action/button on a page         |
| `input`    | Type a value into a field                  |
| `validate` | Assert a field has an expected value       |
| `wait`     | Pause for N milliseconds                   |
| `include`  | Include and run another YAML script        |

### Parameters (for reusable scripts)

```yaml
parameters:
  CustomerName:
    type: string
    default: "Test Customer"
    description: Name of the customer to create

steps:
  - type: input
    target:
      - page: Customer Card
        runtimeRef: auto
      - field: Name
    value: =Parameters.'CustomerName'
    description: Enter customer name
```

### Conditional steps

```yaml
  - type: validate
    target:
      - page: Customer List
    operator: RowCount
    value: "0"
    condition: true
    description: Only proceed if list is empty
```

## Authentication

| Type           | When to use                                    |
|----------------|------------------------------------------------|
| `Windows`      | On-premises BC with Windows authentication     |
| `AAD`          | Business Central Online (Microsoft Entra ID)   |
| `UserPassword` | Sandbox/Docker environments with username+pwd  |

> **Note:** MFA (multi-factor authentication) is not supported. Create a dedicated
> test automation account without MFA enabled.

## CI/CD Integration

In GitHub Actions, set BC credentials as repository secrets and reference them:

```yaml
- name: Run E2E tests
  env:
    BC_URL: ${{ secrets.BC_URL }}
    BC_USERNAME: ${{ secrets.BC_USERNAME }}
    BC_PASSWORD: ${{ secrets.BC_PASSWORD }}
  run: npm run test:e2e
```

## Best Practices

- Start recordings from a consistent, known page (e.g. Role Center)
- Create test data dynamically — don't rely on pre-existing data
- Split long flows into smaller included scripts for reusability
- Use `validate` steps to assert expected outcomes, not just perform actions
- Use parameters to make scripts environment-agnostic
- Name files descriptively: `create-sales-order.yml`, `post-purchase-invoice.yml`
