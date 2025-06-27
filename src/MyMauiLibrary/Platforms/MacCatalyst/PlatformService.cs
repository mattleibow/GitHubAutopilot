using UIKit;

namespace MyMauiLibrary;

public class PlatformService : IPlatformService
{
    public void DoSomething()
    {
        // macOS-specific implementation

        SomethingResult = $"macOS-specific result (OS version: {UIDevice.Current.SystemVersion})";
    }

    public string SomethingResult { get; private set; } = "Nothing yet";
}
