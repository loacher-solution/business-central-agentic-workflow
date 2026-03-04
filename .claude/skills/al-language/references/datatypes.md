# AL Data Types

## Simple Data Types

| Type | Description | Example |
|------|-------------|---------|
| `Integer` | Whole numbers (-2,147,483,647 to 2,147,483,647) | `42` |
| `BigInteger` | Large whole numbers | `9223372036854775807` |
| `Decimal` | Decimal numbers | `123.45` |
| `Boolean` | Truth values | `true`, `false` |
| `Text[n]` | Variable-length text (max n characters) | `'Hello'` |
| `Code[n]` | Uppercase, trimmed text (for IDs) | `'CUST001'` |
| `Char` | Single character | `'A'` |
| `Byte` | 8-bit value (0-255) | `255` |
| `Date` | Date | `20260206D` |
| `Time` | Time of day | `120000T` |
| `DateTime` | Date and time | `20260206D + 120000T` |
| `Duration` | Time span (ms) | `3600000` (1 hour) |
| `Guid` | Global Unique Identifier | |

## Text and Code

```al
var
    MyText: Text[100];    // Max 100 characters
    MyCode: Code[20];     // Max 20 characters, uppercase
    UnlimitedText: Text;  // Unlimited (BigText internally)

// Text operations
MyText := 'Hello World';
MyText := MyText + '!';
MyText := UpperCase(MyText);
MyText := LowerCase(MyText);
MyText := CopyStr(MyText, 1, 5);  // 'Hello'
MyText := StrSubstNo('Hello %1', 'World');

// Code is automatically uppercase and trimmed
MyCode := '  abc  ';  // Results in 'ABC'
```

## Date and Time

```al
var
    MyDate: Date;
    MyTime: Time;
    MyDateTime: DateTime;

// Literals
MyDate := 20260206D;  // February 6, 2026
MyTime := 143000T;    // 14:30:00
MyDateTime := CreateDateTime(MyDate, MyTime);

// Current date/time
MyDate := Today;
MyTime := Time;
MyDateTime := CurrentDateTime;

// Date arithmetic
MyDate := CalcDate('<+1M>', Today);  // +1 month
MyDate := CalcDate('<-1W>', Today);  // -1 week
MyDate := CalcDate('<CY>', Today);   // End of current year

// Components
Year := Date2DMY(MyDate, 3);
Month := Date2DMY(MyDate, 2);
Day := Date2DMY(MyDate, 1);
```

## Record

Records represent database rows.

```al
var
    Customer: Record Customer;
    SalesHeader: Record "Sales Header";

// Get record
if Customer.Get('10000') then
    Message(Customer.Name);

// Multiple records
Customer.SetRange("Country/Region Code", 'DE');
Customer.SetFilter("Credit Limit (LCY)", '>%1', 10000);
if Customer.FindSet() then
    repeat
        ProcessCustomer(Customer);
    until Customer.Next() = 0;

// Create record
Customer.Init();
Customer."No." := '99999';
Customer.Name := 'New Customer';
Customer.Insert(true);  // true = run triggers

// Modify record
Customer.Validate("Credit Limit (LCY)", 50000);
Customer.Modify(true);

// Delete record
Customer.Delete(true);

// Delete all records
Customer.DeleteAll(true);

// Count
Count := Customer.Count();

// Sums
Customer.CalcSums("Balance (LCY)");
Total := Customer."Balance (LCY)";

// Calculate fields (FlowFields)
Customer.CalcFields(Balance);

// Check existence
if Customer.IsEmpty() then
    Error('No customers found');

// Temporary records
var
    TempCustomer: Record Customer temporary;
```

## Option and Enum

```al
// Option (deprecated, use Enum)
field(Status; Option)
{
    OptionMembers = " ",Open,Released,Posted;
    OptionCaption = ' ,Open,Released,Posted';
}

// Enum (modern)
enum 50100 "My Status"
{
    value(0; " ") { Caption = ' '; }
    value(1; Open) { Caption = 'Open'; }
    value(2; Released) { Caption = 'Released'; }
}

// Usage
var
    Status: Enum "My Status";
begin
    Status := Status::Open;
    if Status = Status::Released then
        // ...
end;
```

## Collections

### List

```al
var
    CustomerNames: List of [Text];
    CustomerNo: Code[20];
    CustomerNos: List of [Code[20]];

// Add
CustomerNames.Add('Customer A');
CustomerNames.Add('Customer B');

// Access
Message(CustomerNames.Get(1));

// Iteration
foreach CustomerName in CustomerNames do
    Message(CustomerName);

// Count
Count := CustomerNames.Count();

// Contains
if CustomerNames.Contains('Customer A') then
    // ...

// Remove
CustomerNames.Remove('Customer A');
CustomerNames.RemoveAt(1);
```

### Dictionary

```al
var
    CustomerBalances: Dictionary of [Code[20], Decimal];
    Balance: Decimal;
    CustomerNo: Code[20];

// Add
CustomerBalances.Add('10000', 1500.00);
CustomerBalances.Set('10000', 2000.00);  // Overwrites if exists

// Retrieve
if CustomerBalances.Get('10000', Balance) then
    Message('Balance: %1', Balance);

// Keys/Values
foreach CustomerNo in CustomerBalances.Keys() do
    Message('%1: %2', CustomerNo, CustomerBalances.Get(CustomerNo));

// Existence
if CustomerBalances.ContainsKey('10000') then
    // ...
```

### Array

```al
var
    Values: array[10] of Integer;
    Matrix: array[5, 5] of Decimal;

Values[1] := 100;
Matrix[1, 2] := 3.14;

// Iterate over array
for i := 1 to ArrayLen(Values) do
    Total += Values[i];
```

## JSON

```al
var
    JsonObj: JsonObject;
    JsonArr: JsonArray;
    JsonTok: JsonToken;
    JsonVal: JsonValue;

// Create JSON
JsonObj.Add('name', 'John');
JsonObj.Add('age', 30);

// Parse JSON
JsonObj.ReadFrom('{"name":"John","age":30}');

// Read values
if JsonObj.Get('name', JsonTok) then begin
    JsonVal := JsonTok.AsValue();
    Name := JsonVal.AsText();
end;

// Array
JsonArr.Add('Item 1');
JsonArr.Add('Item 2');
JsonObj.Add('items', JsonArr);

// To text
JsonObj.WriteTo(JsonText);
```

## HTTP

```al
var
    Client: HttpClient;
    Request: HttpRequestMessage;
    Response: HttpResponseMessage;
    Content: HttpContent;
    ResponseText: Text;

// GET Request
if Client.Get('https://api.example.com/data', Response) then begin
    Response.Content.ReadAs(ResponseText);
    Message(ResponseText);
end;

// POST Request
Content.WriteFrom('{"name":"test"}');
Content.GetHeaders().Add('Content-Type', 'application/json');
Request.Method := 'POST';
Request.SetRequestUri('https://api.example.com/data');
Request.Content := Content;
if Client.Send(Request, Response) then
    // ...
```

## Blob

For large binary data (images, documents).

```al
var
    TempBlob: Codeunit "Temp Blob";
    InStr: InStream;
    OutStr: OutStream;

// Write to blob
TempBlob.CreateOutStream(OutStr);
OutStr.WriteText('Hello World');

// Read from blob
TempBlob.CreateInStream(InStr);
InStr.ReadText(MyText);
```

## Media

For images in records.

```al
field(50100; Image; Media)
{
}

// Import image
Customer.Image.ImportFile(FileName, Description);

// Export image
Customer.Image.ExportFile(FileName);
```
