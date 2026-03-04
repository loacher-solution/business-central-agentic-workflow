# AL Objects

## Table

Tables store data in Business Central.

### Structure

```al
table 50100 "My Table"
{
    Caption = 'My Table';
    DataPerCompany = true;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(3; Amount; Decimal)
        {
            Caption = 'Amount';
            InitValue = 0;  // Default value
        }
        field(4; "Document Date"; Date)
        {
            Caption = 'Document Date';

            trigger OnValidate()
            begin
                if "Document Date" > Today then
                    Error('Date cannot be in the future');
            end;
        }
        field(5; Status; Enum "Document Status")
        {
            Caption = 'Status';
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(SK1; "Document Date", Status)
        {
        }
    }

    trigger OnInsert()
    begin
        if "No." = '' then
            "No." := GetNextNo();
    end;

    trigger OnModify()
    begin
        "Modified Date" := Today;
    end;

    trigger OnDelete()
    begin
        // Cleanup related records
    end;

    procedure GetNextNo(): Code[20]
    begin
        // Number series logic
    end;
}
```

### Table Extension

```al
tableextension 50100 "Customer Ext" extends Customer
{
    fields
    {
        field(50100; "Shoe Size"; Integer)
        {
            Caption = 'Shoe Size';

            trigger OnValidate()
            begin
                if "Shoe Size" < 0 then
                    Error('Invalid shoe size');
            end;
        }
        field(50101; "Preferred Contact"; Text[100])
        {
            Caption = 'Preferred Contact';
        }
    }

    procedure HasShoeSize(): Boolean
    begin
        exit("Shoe Size" <> 0);
    end;
}
```

## Page

Pages are the UI elements (forms, lists, etc.)

### Page Types
- `Card` - Single record (form)
- `List` - List of records
- `ListPart` - Embedded list
- `CardPart` - Embedded form
- `Document` - Document with lines
- `Worksheet` - Worksheet
- `RoleCenter` - Home page
- `API` - Web API endpoint

### Card Page

```al
page 50100 "My Card"
{
    PageType = Card;
    SourceTable = "My Table";
    Caption = 'My Card';

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
            }
            group(Details)
            {
                Caption = 'Details';

                field("Document Date"; Rec."Document Date")
                {
                    ApplicationArea = All;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                }
            }
        }
        area(FactBoxes)
        {
            systempart(Notes; Notes)
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Post)
            {
                ApplicationArea = All;
                Caption = 'Post';
                Image = Post;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    PostDocument();
                end;
            }
        }
        area(Navigation)
        {
            action(Ledger)
            {
                ApplicationArea = All;
                Caption = 'Ledger Entries';
                RunObject = page "General Ledger Entries";
            }
        }
    }

    local procedure PostDocument()
    begin
        // Posting logic
    end;
}
```

### List Page

```al
page 50101 "My List"
{
    PageType = List;
    SourceTable = "My Table";
    Caption = 'My List';
    CardPageId = "My Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImportData)
            {
                ApplicationArea = All;
                Caption = 'Import';

                trigger OnAction()
                begin
                    // Import logic
                end;
            }
        }
    }
}
```

### Page Extension

```al
pageextension 50100 "Customer Card Ext" extends "Customer Card"
{
    layout
    {
        addlast(General)
        {
            field("Shoe Size"; Rec."Shoe Size")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the shoe size.';
            }
        }

        modify("Phone No.")
        {
            Visible = false;
        }

        movefirst(General; "E-Mail")
    }

    actions
    {
        addlast(Navigation)
        {
            action(CustomAction)
            {
                ApplicationArea = All;
                Caption = 'Custom Action';

                trigger OnAction()
                begin
                    Message('Hello from extension!');
                end;
            }
        }
    }
}
```

## Codeunit

Codeunits contain business logic (like classes).

```al
codeunit 50100 "My Business Logic"
{
    // Optional: When codeunit operates directly on a record
    TableNo = Customer;

    trigger OnRun()
    begin
        // Called when Codeunit.Run(Record) is invoked
        ProcessCustomer(Rec);
    end;

    procedure ProcessCustomer(var Customer: Record Customer)
    begin
        Customer.TestField(Name);
        Customer.Validate("Credit Limit (LCY)", CalculateNewLimit(Customer));
        Customer.Modify(true);
    end;

    procedure CalculateNewLimit(Customer: Record Customer): Decimal
    var
        SalesHeader: Record "Sales Header";
        TotalSales: Decimal;
    begin
        SalesHeader.SetRange("Sell-to Customer No.", Customer."No.");
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.CalcSums(Amount);
        TotalSales := SalesHeader.Amount;

        exit(TotalSales * 1.5);
    end;

    // Event Publisher
    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessCustomer(var Customer: Record Customer; var IsHandled: Boolean)
    begin
    end;

    // Event Subscriber
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure HandleOnBeforePostSalesDoc(var SalesHeader: Record "Sales Header")
    begin
        // Custom logic before posting
    end;
}
```

## Report

Reports for data output and reporting.

```al
report 50100 "Customer List Report"
{
    Caption = 'Customer List';
    DefaultLayout = RDLC;
    RDLCLayout = './Layouts/CustomerList.rdl';

    dataset
    {
        dataitem(Customer; Customer)
        {
            RequestFilterFields = "No.", "Country/Region Code";

            column(No_; "No.")
            {
            }
            column(Name; Name)
            {
            }
            column(Balance; Balance)
            {
            }

            trigger OnPreDataItem()
            begin
                // Before processing any records
            end;

            trigger OnAfterGetRecord()
            begin
                // After each record is retrieved
                if Balance < 0 then
                    CurrReport.Skip();
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Options)
                {
                    field(ShowDetails; ShowDetails)
                    {
                        ApplicationArea = All;
                        Caption = 'Show Details';
                    }
                }
            }
        }
    }

    var
        ShowDetails: Boolean;
}
```

## Enum

Enumerations for defined value sets.

```al
enum 50100 "Document Status"
{
    Extensible = true;

    value(0; Open)
    {
        Caption = 'Open';
    }
    value(1; Released)
    {
        Caption = 'Released';
    }
    value(2; Posted)
    {
        Caption = 'Posted';
    }
}

// Enum Extension
enumextension 50100 "Document Status Ext" extends "Document Status"
{
    value(100; "Pending Approval")
    {
        Caption = 'Pending Approval';
    }
}
```

## XMLport

For data import/export.

```al
xmlport 50100 "Import Customers"
{
    Caption = 'Import Customers';
    Direction = Import;
    Format = Xml;

    schema
    {
        textelement(Customers)
        {
            tableelement(Customer; Customer)
            {
                fieldelement(No; Customer."No.")
                {
                }
                fieldelement(Name; Customer.Name)
                {
                }
            }
        }
    }
}
```
