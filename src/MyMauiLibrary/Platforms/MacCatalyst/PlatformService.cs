namespace MyMauiLibrary;

public class PlatformService : IPlatformService
{
    public void DoSomething()
    {
        // macOS-specific implementation

        SomethingResult = "macOS-specific result";
    }

    public string SomethingResult { get; private set; } = "Nothing yet";
}
