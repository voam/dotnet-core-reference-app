using FirstApp.Lib;

namespace FirstApp.ProductDBMock;

public class MockProductDB(IEnumerable<Product>? products = null) : IProductDB
{
    private readonly IReadOnlyList<Product> _products = (products ??
    [
        new Product(1, "Mock Widget", 9.99),
        new Product(2, "Mock Gadget", 19.99),
    ]).ToList();

    public IReadOnlyList<Product> GetProducts() => _products;
}
