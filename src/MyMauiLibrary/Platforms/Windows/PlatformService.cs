namespace MyMauiLibrary;

public class PlatformService : IPlatformService
{
    public void DoSomething()
    {
        // Windows-specific implementation

        SomethingResult = "Windows-specific result";
    }

    public string SomethingResult { get; private set; } = "Nothing yet";
}
