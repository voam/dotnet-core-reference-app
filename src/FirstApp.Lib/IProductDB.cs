namespace FirstApp.Lib;

public interface IProductDB
{
    IReadOnlyList<Product> GetProducts();
}
