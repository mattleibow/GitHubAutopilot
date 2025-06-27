using MyMauiLibrary;
using MyMauiLibrary.ViewModels;

namespace MyMauiApp;

public partial class MainPage : ContentPage
{
    public MainPage(IPlatformService platformService)
    {
        InitializeComponent();

        BindingContext = new MainPageViewModel(platformService);
    }
}
