using FirstApp.Lib;

namespace FirstApp.Tests;

public class GreeterTests
{
    [Theory]
    [InlineData(0, "Hello 0!")]
    [InlineData(42, "Hello 42!")]
    [InlineData(-1, "Hello -1!")]
    public void Greet_FormatsNumberIntoGreeting(int number, string expected)
        => Assert.Equal(expected, Greeter.Greet(number));
}
