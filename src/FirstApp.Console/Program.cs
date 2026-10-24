using FirstApp.Lib;

﻿if (args.Length > 0)
{
    Console.WriteLine($"Arguments: {string.Join(", ", args)}");
}
int i = 0;
Console.WriteLine("Hello, World!");
i++;

Console.WriteLine(Greeter.Greet(i));
