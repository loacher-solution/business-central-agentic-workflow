# AL Syntax Basics

## Variables

```al
var
    myInt: Integer;
    myText: Text[100];
    myCode: Code[20];
    myBool: Boolean;
    myDate: Date;
    myDateTime: DateTime;
    myDecimal: Decimal;
    myGuid: Guid;
```

Multiple variables of the same type:
```al
var
    x, y, z: Integer;
    isValid, doCheck: Boolean;
```

## Assignments

```al
Count := 1;
Amount := 2 * Price;
Name := 'Hello ' + 'World';

// Shorthand
Counter += 1;   // instead of Counter := Counter + 1
Counter -= 1;
Counter *= 2;
Counter /= 2;
```

## Operators

| Operator | Description |
|----------|-------------|
| `:=` | Assignment |
| `=` | Equal (comparison) |
| `<>` | Not equal |
| `<`, `>`, `<=`, `>=` | Comparisons |
| `+`, `-`, `*`, `/` | Arithmetic |
| `div` | Integer division |
| `mod` | Modulo |
| `and`, `or`, `not`, `xor` | Logical |

## Control Structures

### If-Then-Else

```al
if Amount < 1000 then
    Total := Total + Amount;

if Amount < 1000 then begin
    Total := Total + Amount;
    Count += 1;
end;

if x = y then
    x := x + 1
else
    x := -x - 1;

// Multi-line
if (Amount > 1000) and
   (Customer."Credit Limit" > 0)
then begin
    // ...
end else begin
    // ...
end;
```

### Case

```al
case Number of
    1, 2, 9:
        Message('1, 2, or 9.');
    10..100:
        Message('Between 10 and 100.');
    else
        Message('Other number.');
end;

case Field of
    Field::A:
        begin
            x := x + 1;
            y := -y - 1;
        end;
    Field::B:
        x := y;
    Field::C,
    Field::D:
        y := x;
    else
        Error('Unknown field');
end;
```

### For Loop

```al
for i := 1 to 10 do
    Total += i;

for i := 10 downto 1 do
    Message(Format(i));

// With begin-end
for i := 1 to 5 do begin
    Total += i;
    Count += 1;
end;
```

### Foreach

```al
foreach CustomerName in CustomerNames do
    Message(CustomerName);
```

### While

```al
while i < 1000 do
    i := i + 1;

while (Condition1) and
      (Condition2)
do begin
    // ...
end;
```

### Repeat-Until

```al
repeat
    Count += 1;
    ProcessRecord();
until Count = 100;

// Typical: iterate over records
if Customer.FindSet() then
    repeat
        ProcessCustomer(Customer);
    until Customer.Next() = 0;
```

### Exit, Break, Continue

```al
// Exit method (with optional return value)
exit;
exit(true);
exit(42);

// Break out of loop
if Count = 10 then
    break;

// Skip to next iteration (BC 2025+)
if (Count mod 42 = 0) then
    continue;
```

## Methods/Procedures

```al
procedure CalculateTotal(Amount: Decimal; Quantity: Integer): Decimal
begin
    exit(Amount * Quantity);
end;

// With local variables
procedure ProcessOrder(OrderNo: Code[20]): Boolean
var
    SalesHeader: Record "Sales Header";
    TotalAmount: Decimal;
begin
    if not SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
        exit(false);

    TotalAmount := CalculateOrderTotal(SalesHeader);
    exit(TotalAmount > 0);
end;

// Procedure without return value
procedure ShowMessage(Msg: Text)
begin
    Message(Msg);
end;

// With var parameter (by reference)
procedure IncrementCounter(var Counter: Integer)
begin
    Counter += 1;
end;
```

## Triggers

Triggers are event handlers that are called automatically:

```al
trigger OnValidate()
begin
    // Called when field is validated
end;

trigger OnInsert()
begin
    // Before inserting a record
end;

trigger OnModify()
begin
    // Before modifying a record
end;

trigger OnDelete()
begin
    // Before deleting a record
end;

trigger OnRun()
begin
    // When codeunit is executed directly
end;
```

## Strings and Labels

```al
var
    MyText: Text[100];
    MyLabel: Label 'Hello %1', Comment = '%1 = Customer Name';

// String operations
MyText := 'Hello';
MyText += ' World';  // Concatenation

// Format
Message('Value: %1, Name: %2', Amount, CustomerName);

// Label with translation
var
    ConfirmLbl: Label 'Do you want to continue?';
begin
    if Confirm(ConfirmLbl) then
        // ...
end;
```

## Error Handling

```al
// Throw error
Error('Something went wrong');
Error('Invalid value: %1', MyValue);

// Confirmation
if not Confirm('Continue?') then
    Error('Cancelled');

// TestField - error if empty
Customer.TestField(Name);
Customer.TestField("E-Mail");

// FieldError - field-specific error
if Amount < 0 then
    FieldError(Amount, 'must be positive');
```

## Assertions in Tests

```al
AssertError SomeMethodThatShouldFail();
// If no error occurs, the test fails

if GetLastErrorText() <> ExpectedError then
    Error('Unexpected error: %1', GetLastErrorText());
```
