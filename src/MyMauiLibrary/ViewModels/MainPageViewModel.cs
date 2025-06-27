using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace MyMauiLibrary.ViewModels;

public partial class MainPageViewModel : ObservableObject
{
    private readonly IPlatformService? _service;

    [ObservableProperty]
    private string _somethingResult = string.Empty;

    public MainPageViewModel(IPlatformService platformService)
    {
        _service = platformService;
        SomethingResult = platformService.SomethingResult;
    }

    [RelayCommand]
    private void CounterClicked()
    {
        _service?.DoSomething();
        SomethingResult = _service?.SomethingResult ?? string.Empty;
    }
}
