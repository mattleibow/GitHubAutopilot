using MyMauiLibrary;
using MyMauiLibrary.ViewModels;

namespace MyMauiLibrary.Tests;

public class MainPageViewModelTests
{
    [Fact]
    public void CounterClicked_UpdatesSomethingResult()
    {
        // Arrange
        var service = new NonPlatformService();
        var viewModel = new MainPageViewModel(service);

        // Act
        viewModel.CounterClickedCommand.Execute(null);

        // Assert
        Assert.Equal(service.SomethingResult, viewModel.SomethingResult);
    }

    [Fact]
    public void CounterClicked_ChangesResult()
    {
        // Arrange
        var service = new NonPlatformService();
        var viewModel = new MainPageViewModel(service);
        var initialResult = viewModel.SomethingResult;

        // Act
        viewModel.CounterClickedCommand.Execute(null);

        // Assert
        Assert.NotEqual(initialResult, viewModel.SomethingResult);
    }
}
