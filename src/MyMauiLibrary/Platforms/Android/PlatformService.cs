namespace MyMauiLibrary;

public class PlatformService : IPlatformService
{
    public void DoSomething()
    {
        // Android-specific implementation

        SomethingResult = $"Android-specific result (OS version: {Build.VERSION.Release})";
    }

    public string SomethingResult { get; private set; } = "Nothing yet";
}
