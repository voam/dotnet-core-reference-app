using System.Net.Mail;
using FirstApp.Lib;

if (args.Length > 0)
{
    Console.WriteLine($"Arguments: {string.Join(", ", args)}");
}
int i = 0;
Console.WriteLine("Hello, World!");
i++;

var greeting = Greeter.Greet(i);
Console.WriteLine(greeting);

// SMTP settings come from docker-compose (the "mail" MailHog service).
var smtpHost = Environment.GetEnvironmentVariable("SMTP_HOST") ?? "localhost";
var smtpPort = int.Parse(Environment.GetEnvironmentVariable("SMTP_PORT") ?? "1025");
using var smtp = new SmtpClient(smtpHost, smtpPort) { EnableSsl = false };
using var message = new MailMessage(
    from: "app@first-app.local",
    to: "test@first-app.local",
    subject: "Hello from FirstApp",
    body: greeting);

   await smtp.SendMailAsync(message);

Console.WriteLine($"Email sent via {smtpHost}:{smtpPort}");
