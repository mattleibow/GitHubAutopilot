using MyMauiLibrary;
using MyMauiLibrary.ViewModels;

namespace MyMauiApp;

public partial class MainPage : ContentPage
{
    public MainPage(MainPageViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;
    }
}
