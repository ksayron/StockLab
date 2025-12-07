namespace StockLab.Services.Interfaces
{
    public interface IHashService
    {
        string Hash(string password);
        string Hash(string password, int iterations);
        bool Verify(string password, string hashedPassword);
        bool IsHashSupported(string hashString);

    }
}
