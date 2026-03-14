using Oracle.ManagedDataAccess.Client;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{
    public class OracleAnalyticsRepository : IAnalyticsRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OracleAnalyticsRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory;
        }

        private async Task<OracleConnection> GetConnectionAsync()
        {
            // Аналитика доступна всем, можно использовать роль User или Admin, 
            // но лучше Admin или специальный Reader, если есть.
            var conn = (OracleConnection)_dbFactory.CreateConnection(DbRole.Admin);
            await conn.OpenAsync();
            return conn;
        }

        // Хелпер для проверки статуса
        private void CheckStatus(OracleParameter pStatus, OracleParameter pMessage)
        {
            string? status = pStatus.Value?.ToString();
            string? msg = pMessage.Value?.ToString();

            // WARNING в аналитике (например, нет турнира) не должен ронять приложение,
            // просто возвращаем пустой список, но логируем.
            if (status == "ERROR")
            {
                throw new Exception($"OLAP Error: {msg}");
            }
        }

        public async Task<IEnumerable<WindroseDto>> GetWindroseDataAsync()
        {
            var list = new List<WindroseDto>();
            using var conn = await GetConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_olap_analytics.get_windrose_data", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            var pStatus = cmd.Parameters.Add("p_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("p_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            try
            {
                using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    list.Add(new WindroseDto
                    {
                        Category = reader.GetString(0),
                        AvgGreed = reader.GetDecimal(1),
                        AvgPanic = reader.GetDecimal(2),
                        AvgMemory = reader.GetDecimal(3),
                        AvgBetSize = reader.GetDecimal(4),
                        AvgRoi = reader.GetDecimal(5)
                    });
                }
            }
            catch (OracleException)
            {
                // Если статус WARNING (нет турнира), курсор может не открыться или быть пустым
                // Игнорируем ошибку чтения, проверяем статус ниже
            }

            // Если статус WARNING (нет активного турнира), вернем пустой список, это нормально
            if (pStatus.Value?.ToString() == "WARNING") return new List<WindroseDto>();

            CheckStatus(pStatus, pMessage);
            return list;
        }

        public async Task<IEnumerable<HeatmapDto>> GetMarketHeatmapAsync()
        {
            var list = new List<HeatmapDto>();
            using var conn = await GetConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_olap_analytics.get_market_heatmap", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            var pStatus = cmd.Parameters.Add("p_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("p_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new HeatmapDto
                {
                    Level1 = reader.IsDBNull(0) ? "GLOBAL" : reader.GetString(0),
                    Level2 = reader.IsDBNull(1) ? "TOTAL" : reader.GetString(1),
                    TotalVolume = reader.GetDecimal(2),
                    WeightedChange = reader.IsDBNull(3) ? 0 : reader.GetDecimal(3),
                    Status = reader.IsDBNull(4) ? "NEUTRAL" : reader.GetString(4)
                });
            }
            CheckStatus(pStatus, pMessage);
            return list;
        }

        public async Task<IEnumerable<TopActiveDto>> GetTopActiveCompaniesAsync()
        {
            var list = new List<TopActiveDto>();
            using var conn = await GetConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_olap_analytics.get_top_active_companies", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            var pStatus = cmd.Parameters.Add("p_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("p_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new TopActiveDto
                {
                    CompanyName = reader.GetString(0),
                    Ticker = reader.GetString(1),
                    TotalShares = reader.GetInt32(2),
                    TradeCount = reader.GetInt32(3)
                });
            }
            CheckStatus(pStatus, pMessage);
            return list;
        }
    }
}
