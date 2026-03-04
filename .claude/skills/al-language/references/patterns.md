# AL Best Practices & Patterns

## Code Organization

### Business Logic in Codeunits

```al
// WRONG: Logic directly on the page
page 50100 "My Page"
{
    trigger OnAction()
    begin
        Customer.Validate("Credit Limit", 1000);
        Customer.Modify();
        CreateSalesOrder(Customer);
        // ...lots more logic...
    end;
}

// RIGHT: Extract logic into a codeunit
codeunit 50100 "Customer Management"
{
    procedure ProcessCustomer(var Customer: Record Customer)
    begin
        ValidateCreditLimit(Customer);
        CreateDefaultSalesOrder(Customer);
    end;
}

page 50100 "My Page"
{
    trigger OnAction()
    var
        CustomerMgt: Codeunit "Customer Management";
    begin
        CustomerMgt.ProcessCustomer(Customer);
    end;
}
```

### Single Responsibility

```al
// WRONG: One codeunit does everything
codeunit 50100 "Do Everything"
{
    procedure PostSales();
    procedure SendEmail();
    procedure UpdateInventory();
    procedure GenerateReport();
}

// RIGHT: Specialized codeunits
codeunit 50101 "Sales Posting Mgt" { }
codeunit 50102 "Email Notification Mgt" { }
codeunit 50103 "Inventory Update Mgt" { }
```

## Record Handling

### FindSet vs FindFirst

```al
// FindFirst: When only one record is expected
if Customer.FindFirst() then
    ProcessSingleCustomer(Customer);

// FindSet: When iterating over multiple records
if Customer.FindSet() then
    repeat
        ProcessCustomer(Customer);
    until Customer.Next() = 0;

// FindSet with Modify
if Customer.FindSet(true) then  // true = ForUpdate
    repeat
        Customer.Status := Customer.Status::Processed;
        Customer.Modify();
    until Customer.Next() = 0;
```

### Get vs Find

```al
// Get: When primary key is known
if Customer.Get('10000') then
    Message(Customer.Name);

// Get with error if not found
Customer.Get('10000');  // Error if not found

// Find with filters
Customer.SetRange("Country/Region Code", 'DE');
if Customer.FindFirst() then
    Message(Customer.Name);
```

### Temporary Records

```al
procedure GetFilteredCustomers(var TempCustomer: Record Customer temporary)
var
    Customer: Record Customer;
begin
    Customer.SetRange("Country/Region Code", 'DE');
    if Customer.FindSet() then
        repeat
            TempCustomer := Customer;
            TempCustomer.Insert();
        until Customer.Next() = 0;
end;
```

## Events & Subscribers

### Integration Events

```al
codeunit 50100 "Sales Processing"
{
    procedure ProcessSale(var SalesHeader: Record "Sales Header")
    var
        IsHandled: Boolean;
    begin
        // Event before processing
        OnBeforeProcessSale(SalesHeader, IsHandled);
        if IsHandled then
            exit;

        // Main logic
        DoProcessSale(SalesHeader);

        // Event after processing
        OnAfterProcessSale(SalesHeader);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessSale(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterProcessSale(var SalesHeader: Record "Sales Header")
    begin
    end;
}

// Subscriber in another extension
codeunit 50200 "My Sales Extension"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Processing", 'OnBeforeProcessSale', '', false, false)]
    local procedure HandleOnBeforeProcessSale(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin
        if SalesHeader."Sell-to Customer No." = 'BLOCKED' then begin
            Error('This customer is blocked');
            IsHandled := true;
        end;
    end;
}
```

### Subscribing to Standard BC Events

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
local procedure HandleOnBeforePostSalesDoc(var SalesHeader: Record "Sales Header"; CommitIsSuppressed: Boolean; PreviewMode: Boolean)
begin
    // Custom validation before posting
    ValidateCustomFields(SalesHeader);
end;

[EventSubscriber(ObjectType::Table, Database::Customer, 'OnAfterValidateEvent', 'Credit Limit (LCY)', false, false)]
local procedure HandleCreditLimitValidation(var Rec: Record Customer; var xRec: Record Customer; CurrFieldNo: Integer)
begin
    if Rec."Credit Limit (LCY)" > 100000 then
        SendNotificationToManager(Rec);
end;
```

## Error Handling

### User-Friendly Errors

```al
// WRONG
Error('Error 42');

// RIGHT
var
    CustomerNotFoundErr: Label 'Customer %1 was not found.', Comment = '%1 = Customer No.';
begin
    if not Customer.Get(CustomerNo) then
        Error(CustomerNotFoundErr, CustomerNo);
end;
```

### TestField Pattern

```al
procedure PostDocument(SalesHeader: Record "Sales Header")
begin
    // Check required fields
    SalesHeader.TestField("Sell-to Customer No.");
    SalesHeader.TestField("Posting Date");
    SalesHeader.TestField("Document Date");

    // Then post
    DoPost(SalesHeader);
end;
```

### Confirm Before Destructive Actions

```al
var
    DeleteConfirmQst: Label 'Do you want to delete %1 records?', Comment = '%1 = Count';
begin
    if not Confirm(DeleteConfirmQst, false, RecordCount) then
        exit;

    DeleteRecords();
end;
```

## Performance

### SetLoadFields

```al
// WRONG: Loads all fields
Customer.SetRange("Country/Region Code", 'DE');
if Customer.FindSet() then
    repeat
        Total += Customer."Balance (LCY)";
    until Customer.Next() = 0;

// RIGHT: Loads only required fields
Customer.SetLoadFields("No.", "Balance (LCY)");
Customer.SetRange("Country/Region Code", 'DE');
if Customer.FindSet() then
    repeat
        Total += Customer."Balance (LCY)";
    until Customer.Next() = 0;
```

### Bulk Operations

```al
// WRONG: Individual inserts
for i := 1 to 1000 do begin
    MyRecord.Init();
    MyRecord."No." := Format(i);
    MyRecord.Insert();
end;

// RIGHT: With ModifyAll
MyRecord.ModifyAll(Status, MyRecord.Status::Processed);

// Or with DataTransfer (BC 2021+)
var
    DataTransfer: DataTransfer;
begin
    DataTransfer.SetTables(Database::"Source Table", Database::"Target Table");
    DataTransfer.AddFieldValue(SourceField, TargetField);
    DataTransfer.CopyRows();
end;
```

### CalcFields Only When Needed

```al
// WRONG: CalcFields in loop
if Customer.FindSet() then
    repeat
        Customer.CalcFields(Balance);
        // ...
    until Customer.Next() = 0;

// RIGHT: SetAutoCalcFields before the loop
Customer.SetAutoCalcFields(Balance);
if Customer.FindSet() then
    repeat
        // Balance is automatically calculated
    until Customer.Next() = 0;
```

## Naming Conventions

```al
// Objects: PascalCase with prefix
table 50100 "My Custom Table" { }
page 50100 "My Custom Card" { }
codeunit 50100 "My Custom Mgt" { }

// Fields: PascalCase
field(1; "Customer No."; Code[20]) { }
field(2; "Document Date"; Date) { }

// Variables: PascalCase, descriptive
var
    SalesHeader: Record "Sales Header";
    TotalAmount: Decimal;
    IsValid: Boolean;

// Procedures: PascalCase, verb first
procedure ProcessSalesOrder(var SalesHeader: Record "Sales Header")
procedure CalculateTotalAmount(): Decimal
procedure ValidateCustomerData(Customer: Record Customer): Boolean

// Labels: Suffix Lbl, Err, Qst, Msg
var
    ConfirmDeleteQst: Label 'Delete this record?';
    RecordNotFoundErr: Label 'Record not found.';
    SuccessMsg: Label 'Operation completed successfully.';
    FieldCaptionLbl: Label 'Customer No.';

// Local procedures: "local" keyword
local procedure DoInternalProcessing()
```

## Testing

```al
codeunit 50199 "My Tests"
{
    Subtype = Test;

    [Test]
    procedure TestCustomerCreation()
    var
        Customer: Record Customer;
        CustomerMgt: Codeunit "Customer Management";
    begin
        // Given
        InitializeTestData();

        // When
        CustomerMgt.CreateCustomer(Customer);

        // Then
        Assert.IsTrue(Customer."No." <> '', 'Customer No. should be set');
        Assert.AreEqual('NEW', Customer."Customer Group Code", 'Wrong customer group');
    end;

    [Test]
    procedure TestInvalidInputError()
    var
        CustomerMgt: Codeunit "Customer Management";
    begin
        // Expect error
        asserterror CustomerMgt.ProcessInvalidData();

        Assert.ExpectedError('Invalid input');
    end;

    local procedure InitializeTestData()
    begin
        // Setup test data
    end;

    var
        Assert: Codeunit Assert;
}
```
