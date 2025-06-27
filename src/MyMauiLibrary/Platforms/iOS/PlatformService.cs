namespace MyMauiLibrary;

public class PlatformService : IPlatformService
{
    public void DoSomething()
    {
        // iOS-specific implementation

        SomethingResult = "iOS-specific result";
    }

    public string SomethingResult { get; private set; } = "Nothing yet";
}
