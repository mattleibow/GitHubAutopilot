namespace MyMauiLibrary;

public class PlatformService : IPlatformService
{
    public void DoSomething()
    {
        // Android-specific implementation

        SomethingResult = "Android-specific result";
    }

    public string SomethingResult { get; private set; } = "Nothing yet";
}
