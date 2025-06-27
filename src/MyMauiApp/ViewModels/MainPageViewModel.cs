using System.Windows.Input;
using MyMauiLibrary;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace MyMauiApp.ViewModels;

public partial class MainPageViewModel : ObservableObject
{
    private readonly IPlatformService? _service;

    [ObservableProperty]
    private string _somethingResult = string.Empty;

    public MainPageViewModel() {}

    public MainPageViewModel(IPlatformService platformService)
    {
        _service = platformService;
        SomethingResult = "Initial Value"; // Default value
    }

    [RelayCommand]
    private void CounterClicked()
    {
        _service?.DoSomething();
        SomethingResult = _service?.SomethingResult ?? string.Empty;
    }
}
