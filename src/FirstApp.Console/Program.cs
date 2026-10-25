using System.Net.Mail;
using FirstApp.Lib;
using FirstApp.ProductDBMock;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

// appsettings.json, overridable by environment variable (e.g. ProductDb__Provider=Mock).
var configuration = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: true)
    .AddEnvironmentVariables()
    .Build();

var services = new ServiceCollection();
var productDbProvider = configuration["ProductDb:Provider"] ?? "Sqlite";
switch (productDbProvider.ToLowerInvariant())
{
    case "sqlite":
        services.AddSingleton<IProductDB>(_ => ProductRepository.FromEnvironment());
        break;
    case "mock":
        services.AddSingleton<IProductDB>(_ => new MockProductDB());
        break;
    default:
        throw new InvalidOperationException($"Unknown ProductDb:Provider '{productDbProvider}'. Use 'Sqlite' or 'Mock'.");
}
using var serviceProvider = services.BuildServiceProvider();

if (args.Length > 0)
{
    Console.WriteLine($"Arguments: {string.Join(", ", args)}");
}
int i = 0;
Console.WriteLine("Hello, World!");
i++;

var greeting = Greeter.Greet(i);
Console.WriteLine(greeting);

string productList;
try
{
    var products = serviceProvider.GetRequiredService<IProductDB>().GetProducts();
    productList = string.Join(Environment.NewLine, products.Select(p => $"- {p.Name}: {p.Price:0.00}"));
}
catch (Exception ex)
{
    productList = $"(Could not load products: {ex.Message})";
}
Console.WriteLine(productList);
var body = $"{greeting}{Environment.NewLine}{Environment.NewLine}Products:{Environment.NewLine}{productList}";

// SMTP settings come from docker-compose (the "mail" MailHog service).
var smtpHost = Environment.GetEnvironmentVariable("SMTP_HOST") ?? "localhost";
var smtpPort = int.Parse(Environment.GetEnvironmentVariable("SMTP_PORT") ?? "1025");
using var smtp = new SmtpClient(smtpHost, smtpPort) { EnableSsl = false };
using var message = new MailMessage(
    from: "app@first-app.local",
    to: "test@first-app.local",
    subject: "Hello from FirstApp",
    body: body);

await smtp.SendMailAsync(message);

Console.WriteLine($"Email sent via {smtpHost}:{smtpPort}");
