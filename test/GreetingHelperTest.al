namespace DefaultPublisher.Test;

using DefaultPublisher.src;

codeunit 50201 "Greeting Helper Test"
{
    Subtype = Test;

    var
        GreetingHelper: Codeunit "Greeting Helper";

    // --- GetGreeting tests ---

    [Test]
    procedure TestGetGreetingWithName()
    var
        Result: Text;
    begin
        Result := GreetingHelper.GetGreeting('Alice');
        if Result <> 'Hello, Alice!' then
            Error('Expected "Hello, Alice!" but got "%1"', Result);
    end;

    [Test]
    procedure TestGetGreetingWithEmptyName()
    var
        Result: Text;
    begin
        Result := GreetingHelper.GetGreeting('');
        if Result <> 'Hello, Guest!' then
            Error('Expected "Hello, Guest!" but got "%1"', Result);
    end;

    // --- GetFormalGreeting tests ---

    [Test]
    procedure TestGetFormalGreeting()
    var
        Result: Text;
    begin
        Result := GreetingHelper.GetFormalGreeting('Dr.', 'Smith');
        if Result <> 'Good day, Dr. Smith!' then
            Error('Expected "Good day, Dr. Smith!" but got "%1"', Result);
    end;

    [Test]
    procedure TestGetFormalGreetingEmptyTitle()
    var
        Result: Text;
    begin
        Result := GreetingHelper.GetFormalGreeting('', 'Smith');
        if Result <> 'Good day!' then
            Error('Expected "Good day!" but got "%1"', Result);
    end;

    [Test]
    procedure TestGetFormalGreetingEmptyLastName()
    var
        Result: Text;
    begin
        Result := GreetingHelper.GetFormalGreeting('Mr.', '');
        if Result <> 'Good day!' then
            Error('Expected "Good day!" but got "%1"', Result);
    end;

    // --- GetTimeBasedGreeting tests ---

    [Test]
    procedure TestGetTimeBasedGreetingMorning()
    var
        Result: Text;
    begin
        Result := GreetingHelper.GetTimeBasedGreeting(8);
        if Result <> 'Good morning!' then
            Error('Expected "Good morning!" but got "%1"', Result);
    end;

    [Test]
    procedure TestGetTimeBasedGreetingAfternoon()
    var
        Result: Text;
    begin
        Result := GreetingHelper.GetTimeBasedGreeting(14);
        if Result <> 'Good afternoon!' then
            Error('Expected "Good afternoon!" but got "%1"', Result);
    end;

    [Test]
    procedure TestGetTimeBasedGreetingEvening()
    var
        Result: Text;
    begin
        Result := GreetingHelper.GetTimeBasedGreeting(20);
        if Result <> 'Good evening!' then
            Error('Expected "Good evening!" but got "%1"', Result);
    end;

    [Test]
    procedure TestGetTimeBasedGreetingInvalidHour()
    var
        Result: Text;
    begin
        Result := GreetingHelper.GetTimeBasedGreeting(-1);
        if Result <> 'Hello!' then
            Error('Expected "Hello!" for invalid hour but got "%1"', Result);
    end;

    [Test]
    procedure TestGetTimeBasedGreetingBoundaryNoon()
    var
        Result: Text;
    begin
        // Hour 12 should be afternoon, not morning
        Result := GreetingHelper.GetTimeBasedGreeting(12);
        if Result <> 'Good afternoon!' then
            Error('Expected "Good afternoon!" at noon but got "%1"', Result);
    end;
}
