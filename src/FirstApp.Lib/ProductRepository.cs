using Microsoft.Data.Sqlite;

namespace FirstApp.Lib;

public class ProductRepository(string databasePath)
{
    private readonly string _connectionString = new SqliteConnectionStringBuilder
    {
        DataSource = databasePath,
        Mode = SqliteOpenMode.ReadWrite, // don't silently create an empty file
    }.ToString();

    // Uses SQLITE_PATH (set in docker-compose), falling back to /data/app.db.
    public static ProductRepository FromEnvironment() =>
        new(Environment.GetEnvironmentVariable("SQLITE_PATH") ?? "/data/app.db");

    public IReadOnlyList<Product> GetProducts()
    {
        using var connection = new SqliteConnection(_connectionString);
        connection.Open();

        using var command = connection.CreateCommand();
        command.CommandText = "SELECT Id, Name, Price FROM Products ORDER BY Id";

        var products = new List<Product>();
        using var reader = command.ExecuteReader();
        while (reader.Read())
        {
            products.Add(new Product(reader.GetInt64(0), reader.GetString(1), reader.GetDouble(2)));
        }
        return products;
    }
}
