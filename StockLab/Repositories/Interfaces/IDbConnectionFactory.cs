using System.Data;

namespace StockLab.Repositories.Interfaces
{
    public enum DbRole { Guest, User, Admin }
    public interface IDbConnectionFactory
    {
        IDbConnection CreateConnection(DbRole role);
    }
}
