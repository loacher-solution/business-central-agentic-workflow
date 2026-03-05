# Page Script YAML Format Reference

Reference for writing BC page scripts that run via `@microsoft/bc-replay`.

## Basic Structure

```yaml
name: my-test-name
description: What this test validates
start:
  page: Role Center          # Starting page (optional, defaults to role center)
  profile: ORDER PROCESSOR   # BC profile/role (optional)
steps:
  - type: action
    # ... step definition
```

## Step Types

### action — Click a button or action

```yaml
- type: action
  target:
  - page: Customer Card
  - action: New
  description: Click the New action
```

### input — Set a field value

```yaml
- type: input
  target:
  - page: Customer Card
  - field: Name
  value: My Customer Name
  description: Enter customer name
```

### validate — Assert a field value

```yaml
- type: validate
  target:
  - page: Customer Card
  - field: Name
  value: My Customer Name
  description: Verify the name field
```

Operators (in Properties):
- `is` (default) — equals
- `is not` — not equals
- `contains` — substring match
- `does not contain`

### wait — Pause between steps

```yaml
- type: wait
  time: 2000
  description: Wait 2 seconds
```

### include — Run another script

```yaml
- type: include
  name: Setup Customer
  file: ./includes/setup-customer.yml
  description: Run customer setup script
```

## Target Selectors

Targets identify UI elements using a chain of selectors:

```yaml
target:
- page: Customer Card        # The page
- field: Name                 # A field on the page
- action: New                 # An action/button
- part: Lines                 # A page part (subpage)
- group: General              # A field group
- filter: Name                # A filter field
```

### Nested targets (field in a part)

```yaml
target:
- page: Sales Order
- part: SalesLines
- field: Quantity
```

## Conditional Steps

Run steps only when a condition is met:

```yaml
- type: conditional
  target:
  - page: Customer List
  - field: "No."
  condition:
    operator: is not
    value: ""
  description: When customer number is not empty
  steps:
    - type: action
      target:
      - page: Customer List
      - action: Edit
      description: Open customer for editing
```

### Row count conditions

```yaml
- type: conditional
  target:
  - page: Customer List
  condition:
    property: rowCount
    operator: is
    value: 0
  description: When list is empty
  steps:
    - type: action
      target:
      - page: Customer List
      - action: New
      description: Create first customer
```

## Parameters

Define reusable input values:

```yaml
parameters:
  CustomerName:
    type: string
    default: Test Customer
    description: Name of the customer to create
  DocumentDate:
    type: string
    default: 3/4/2026

steps:
  - type: input
    target:
    - page: Customer Card
    - field: Name
    value: =Parameters.'CustomerName'
    description: Set customer name from parameter
```

Parameters without defaults prompt for input during replay.

## Power Fx Expressions

Values prefixed with `=` are Power Fx expressions:

```yaml
# Current date
value: =Today()

# Concatenation
value: ="Customer " & Today()

# Clipboard reference (from a previous copy step)
value: =Clipboard.'Customer.No.'

# Arithmetic
value: =Clipboard.'Line Amount' + 100

# Session info
value: =Session.'User ID'

# Parameter reference
value: =Parameters.'CustomerName'
```

## Optional Pages

Mark a page as optional if it might not appear during replay (e.g. confirmation dialogs):

```yaml
- type: page
  target:
  - page: Confirm
  optional: true
  description: Handle optional confirmation dialog
  steps:
    - type: action
      target:
      - page: Confirm
      - action: "Yes"
      description: Confirm the action
```

## Common Patterns

### Open a page and verify it loaded

```yaml
steps:
  - type: action
    target:
    - page: Role Center
    - action: Customers
    description: Navigate to Customer List
  - type: validate
    target:
    - page: Customer List
    condition:
      property: isOpen
      operator: is
      value: true
    description: Verify Customer List opened
```

### Create a new record

```yaml
steps:
  - type: action
    target:
    - page: Customer List
    - action: New
    description: Click New
  - type: input
    target:
    - page: Customer Card
    - field: Name
    value: =Parameters.'CustomerName'
    description: Set name
  - type: input
    target:
    - page: Customer Card
    - field: Address
    value: 123 Test Street
    description: Set address
  - type: action
    target:
    - page: Customer Card
    - action: OK
    description: Save and close
```

### Validate field visibility

```yaml
- type: validate
  target:
  - page: Customer Card
  - field: "Credit Limit (LCY)"
  condition:
    property: visible
    operator: is
    value: true
  description: Credit limit field should be visible
```

## File Organization

Recommended structure:
```
e2e/
├── recordings/
│   ├── smoke-test.yml           # Quick sanity check
│   ├── customer-crud.yml        # Customer create/read/update/delete
│   ├── sales-order-flow.yml     # Full sales order process
│   └── includes/
│       ├── setup-customer.yml   # Reusable: create a test customer
│       └── cleanup.yml          # Reusable: delete test data
└── results/                     # Playwright reports (gitignored)
```
