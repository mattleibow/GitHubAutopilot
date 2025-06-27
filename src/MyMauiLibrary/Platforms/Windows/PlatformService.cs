namespace MyMauiLibrary;

public class PlatformService : IPlatformService
{
    public void DoSomething()
    {
        // Windows-specific implementation
        var version = AnalyticsInfo.VersionInfo.DeviceVersion;
        var versionNumber = ulong.Parse(version);
        var major = (versionNumber & 0xFFFF000000000000L) >> 48;
        var minor = (versionNumber & 0x0000FFFF00000000L) >> 32;
        var build = (versionNumber & 0x00000000FFFF0000L) >> 16;
        var revision = versionNumber & 0x000000000000FFFFL;
        var versionString = $"{major}.{minor}.{build}.{revision}";

        SomethingResult = $"Windows-specific result (OS version: {versionString})";
    }

    public string SomethingResult { get; private set; } = "Nothing yet";
}
