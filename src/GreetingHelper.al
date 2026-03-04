namespace DefaultPublisher.src;

codeunit 50101 "Greeting Helper"
{
    /// <summary>
    /// Returns a personalized greeting for the given name.
    /// Empty names return a default greeting.
    /// </summary>
    procedure GetGreeting(Name: Text): Text
    begin
        if Name = '' then
            exit('Hello, Guest!');
        exit('Hello, ' + Name + '!');
    end;

    /// <summary>
    /// Returns a greeting with a title prefix (Mr., Ms., Dr., etc.).
    /// </summary>
    procedure GetFormalGreeting(Title: Text; LastName: Text): Text
    begin
        if (Title = '') or (LastName = '') then
            exit('Good day!');
        exit('Good day, ' + Title + ' ' + LastName + '!');
    end;

    /// <summary>
    /// Returns a time-appropriate greeting (Morning/Afternoon/Evening)
    /// based on the given hour (0-23).
    /// </summary>
    procedure GetTimeBasedGreeting(Hour: Integer): Text
    begin
        if (Hour < 0) or (Hour > 23) then
            exit('Hello!');
        if Hour < 12 then
            exit('Good morning!');
        if Hour < 18 then
            exit('Good afternoon!');
        exit('Good evening!');
    end;
}
