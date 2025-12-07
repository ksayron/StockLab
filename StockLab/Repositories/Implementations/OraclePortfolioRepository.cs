using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{
    public class OraclePortfolioRepository : IPortfolioRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OraclePortfolioRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory;
        }

        private async Task<OracleConnection> GetOpenConnectionAsync()
        {
            var conn = (OracleConnection)_dbFactory.CreateConnection(DbRole.User);
            await conn.OpenAsync();
            return conn;
        }

        private void CheckStatus(OracleParameter pStatus, OracleParameter pMessage)
        {
            string status = pStatus.Value?.ToString();
            string msg = pMessage.Value?.ToString();

            if (status == "ERROR")
            {
                if (msg.Contains("не найден"))
                    throw new KeyNotFoundException(msg);

                throw new Exception($"DB Error: {msg}");
            }
        }

        public async Task<PortfolioSummaryDto> GetSummaryAsync(int userId)
        {
            using var conn = await GetOpenConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_portfolio.get_portfolio_summary", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            // Inputs
            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);

            // Outputs
            var pCash = cmd.Parameters.Add("o_cash_balance", OracleDbType.Decimal, ParameterDirection.Output);
            var pStockVal = cmd.Parameters.Add("o_stocks_value", OracleDbType.Decimal, ParameterDirection.Output);
            var pTotal = cmd.Parameters.Add("o_total_equity", OracleDbType.Decimal, ParameterDirection.Output);
            var pChgAbs = cmd.Parameters.Add("o_change_abs", OracleDbType.Decimal, ParameterDirection.Output);
            var pChgPct = cmd.Parameters.Add("o_change_pct", OracleDbType.Decimal, ParameterDirection.Output);

            // Soft Error Params
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();

            CheckStatus(pStatus, pMessage);

            decimal GetVal(OracleParameter p) => p.Value is OracleDecimal d ? d.Value : 0m;

            return new PortfolioSummaryDto
            {
                CashBalance = GetVal(pCash),
                StocksValue = GetVal(pStockVal),
                TotalEquity = GetVal(pTotal),
                ChangeAbs = GetVal(pChgAbs),
                ChangePercent = GetVal(pChgPct)
            };
        }

        public async Task<IEnumerable<PortfolioItemDto>> GetItemsAsync(int userId)
        {
            var list = new List<PortfolioItemDto>();
            using var conn = await GetOpenConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_portfolio.get_portfolio_items", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new PortfolioItemDto
                {
                    CompanyId = reader.GetInt32(0),
                    Ticker = reader.GetString(1),
                    Name = reader.GetString(2),
                    Quantity = reader.GetInt32(3),
                    CurrentPrice = reader.GetDecimal(4),
                    TotalValue = reader.GetDecimal(5),
                    PriceChangeAbs = reader.GetDecimal(6),
                    PriceChangePercent = reader.GetDecimal(7)
                });
            }
            
            reader.Close();
            CheckStatus(pStatus, pMessage);

            return list;
        }
    }
}
