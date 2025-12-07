using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{
    public class OracleTradingRepository : ITradingRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OracleTradingRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory;
        }

        private async Task<OracleConnection> GetOpenConnectionAsync()
        {
            // Используем роль USER (обычный трейдер)
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
                // Анализ русских сообщений об ошибках
                if (msg.Contains("Недостаточно средств") || msg.Contains("Недостаточно акций"))
                    throw new InvalidOperationException(msg); // 400 Bad Request / 402 Payment Required

                if (msg.Contains("не найден"))
                    throw new KeyNotFoundException(msg); // 404 Not Found

                // Для системных ошибок
                throw new Exception($"DB Error: {msg}"); // 500
            }
        }

        public async Task<int> PlaceOrderAsync(int userId, PlaceOrderDto dto)
        {
            using var conn = await GetOpenConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_trading_user.place_order", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            // Inputs
            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);
            cmd.Parameters.Add("p_company_id", OracleDbType.Int32, dto.CompanyId, ParameterDirection.Input);
            cmd.Parameters.Add("p_type", OracleDbType.Varchar2, dto.Type.ToUpper(), ParameterDirection.Input);
            cmd.Parameters.Add("p_qty", OracleDbType.Int32, dto.Quantity, ParameterDirection.Input);
            cmd.Parameters.Add("p_limit_price", OracleDbType.Decimal, dto.LimitPrice, ParameterDirection.Input);

            // Outputs
            var pOrderId = cmd.Parameters.Add("o_order_id", OracleDbType.Int32, ParameterDirection.Output);

            // Soft Error Params
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();

            CheckStatus(pStatus, pMessage);

            if (pOrderId.Value is OracleDecimal decimalVal)
                return decimalVal.ToInt32();

            throw new Exception("Order ID not returned.");
        }

        public async Task CancelOrderAsync(int userId, int orderId)
        {
            using var conn = await GetOpenConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_trading_user.cancel_order", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);
            cmd.Parameters.Add("p_order_id", OracleDbType.Int32, orderId, ParameterDirection.Input);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }

        public async Task<IEnumerable<OrderDto>> GetUserOrdersAsync(int userId)
        {
            var list = new List<OrderDto>();
            using var conn = await GetOpenConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_trading_user.get_orders_by_user_id", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new OrderDto
                {
                    Id = reader.GetInt32(0),
                    Ticker = reader.GetString(1),
                    Type = reader.GetString(2),
                    Status = reader.GetString(3),
                    LimitPrice = reader.GetDecimal(4),
                    OriginalQty = reader.GetInt32(5),
                    RemainingQty = reader.GetInt32(6),
                    CreatedAt = reader.GetDateTime(7)
                });
            }

            reader.Close();
            CheckStatus(pStatus, pMessage);

            return list;
        }
    }
}
