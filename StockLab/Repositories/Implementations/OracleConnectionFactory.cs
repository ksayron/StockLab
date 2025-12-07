using Oracle.ManagedDataAccess.Client;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{
    public class OracleConnectionFactory : IDbConnectionFactory
    {
        private readonly IConfiguration _config;

        public OracleConnectionFactory(IConfiguration config)
        {
            _config = config;
        }

        public IDbConnection CreateConnection(DbRole role)
        {
            string connStringKey = role switch
            {
                DbRole.Admin => "OracleDbAdmin",
                DbRole.User => "OracleDbUser",
                _ => "OracleDbGuest" // Default
            };

            return new OracleConnection(_config.GetConnectionString(connStringKey));
        }
    }
}
