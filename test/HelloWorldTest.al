namespace DefaultPublisher.Test;

codeunit 50200 "Hello World Test"
{
    Subtype = Test;

    [Test]
    procedure TestSamplePass()
    begin
        // Simple test that always passes — used to verify the test runner works
        if 1 + 1 <> 2 then
            Error('Basic math is broken');
    end;

    [Test]
    procedure TestTextConcatenation()
    var
        Result: Text;
    begin
        Result := 'Hello' + ' ' + 'World';
        if Result <> 'Hello World' then
            Error('Text concatenation failed: %1', Result);
    end;
}
