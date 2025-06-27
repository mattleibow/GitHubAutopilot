namespace MyMauiLibrary;

public class NonPlatformService : IPlatformService
{
    public void DoSomething()
    {
        // Non-platform-specific implementation

        SomethingResult = "Non-platform-specific result";
    }

    public string SomethingResult { get; private set; } = "Nothing yet";
}
