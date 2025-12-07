using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{
    public class OracleAdminRepository : IAdminRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OracleAdminRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory;
        }

        private async Task<OracleConnection> GetAdminConnectionAsync()
        {
            var conn = (OracleConnection)_dbFactory.CreateConnection(DbRole.Admin);
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
                    throw new KeyNotFoundException(msg); // 404

                if (msg.Contains("занято") || msg.Contains("нельзя"))
                    throw new InvalidOperationException(msg); // 400/409

                throw new Exception($"Admin DB Error: {msg}"); // 500
            }
        }

        public async Task BanUserAsync(int adminId, int targetUserId, bool ban)
        {
            using var conn = await GetAdminConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_admin_tools.set_user_ban_status", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_admin_id", OracleDbType.Int32, adminId, ParameterDirection.Input);
            cmd.Parameters.Add("p_target_user_id", OracleDbType.Int32, targetUserId, ParameterDirection.Input);
            cmd.Parameters.Add("p_is_banned", OracleDbType.Int32, ban ? 1 : 0, ParameterDirection.Input);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }

        public async Task CreateNewAdminAsync(string username, string passwordHash)
        {
            using var conn = await GetAdminConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_admin_tools.create_new_admin", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_username", OracleDbType.Varchar2, username, ParameterDirection.Input);
            cmd.Parameters.Add("p_password_hash", OracleDbType.Varchar2, passwordHash, ParameterDirection.Input);

            // OUT
            cmd.Parameters.Add("o_admin_id", OracleDbType.Int32, ParameterDirection.Output);
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }

        public async Task AdjustBalanceAsync(int targetUserId, decimal newBalance)
        {
            using var conn = await GetAdminConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_admin_tools.adjust_user_balance", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_target_user_id", OracleDbType.Int32, targetUserId, ParameterDirection.Input);
            cmd.Parameters.Add("p_new_balance", OracleDbType.Decimal, newBalance, ParameterDirection.Input);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }

        public async Task<AdminUserDetailDto?> GetUserDetailsAsync(int targetUserId)
        {
            using var conn = await GetAdminConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_admin_tools.get_user_full_details", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_target_user_id", OracleDbType.Int32, targetUserId, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            CheckStatus(pStatus, pMessage);

            if (await reader.ReadAsync())
            {
                return new AdminUserDetailDto
                {
                    UserId = reader.GetInt32(0),
                    Username = reader.GetString(1),
                    Email = reader.GetString(2),
                    Balance = reader.GetDecimal(3),
                    IsBanned = reader.GetInt32(4) == 1,
                    RoleName = reader.GetString(5),
                    CreatedAt = reader.GetDateTime(6),
                    TotalOrders = reader.GetInt32(7),
                    TotalTrades = reader.GetInt32(8)
                };
            }
            return null;
        }

        public async Task<IEnumerable<AdminOrderViewDto>> GetCompanyOrdersAsync(int companyId)
        {
            var list = new List<AdminOrderViewDto>();
            using var conn = await GetAdminConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_admin_tools.get_company_orders_admin", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_company_id", OracleDbType.Int32, companyId, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new AdminOrderViewDto
                {
                    OrderId = reader.GetInt32(0),
                    Username = reader.GetString(1),
                    Type = reader.GetString(2),
                    Status = reader.GetString(3),
                    Price = reader.GetDecimal(4),
                    Qty = reader.GetInt32(6),
                    CreatedAt = reader.GetDateTime(7)
                });
            }
            reader.Close();
            CheckStatus(pStatus, pMessage);
            return list;
        }

        public async Task<IEnumerable<AdminTradeViewDto>> GetCompanyTradesAsync(int companyId)
        {
            var list = new List<AdminTradeViewDto>();
            using var conn = await GetAdminConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_admin_tools.get_company_trades_admin", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_company_id", OracleDbType.Int32, companyId, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new AdminTradeViewDto
                {
                    TradeId = reader.GetInt32(0),
                    Buyer = reader.GetString(1),
                    Seller = reader.GetString(2),
                    Price = reader.GetDecimal(3),
                    Qty = reader.GetInt32(4),
                    ExecutedAt = reader.GetDateTime(5)
                });
            }
            reader.Close();
            CheckStatus(pStatus, pMessage);
            return list;
        }

        public async Task<IEnumerable<SystemLogDto>> GetSystemLogsAsync(int? minutesBack)
        {
            var list = new List<SystemLogDto>();
            using var conn = await GetAdminConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_admin_tools.get_system_logs", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            // Параметр может быть null, OracleDBType.Int32 это поддерживает
            cmd.Parameters.Add("p_minutes_back", OracleDbType.Int32, minutesBack, ParameterDirection.Input);

            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new SystemLogDto
                {
                    LogId = reader.GetInt32(0),
                    ProcName = reader.IsDBNull(1) ? "Unknown" : reader.GetString(1),
                    UserId = reader.IsDBNull(2) ? null : reader.GetInt32(2),
                    ErrorCode = reader.IsDBNull(3) ? null : reader.GetString(3),
                    ErrorMsg = reader.IsDBNull(4) ? "No message" : reader.GetString(4),
                    CreatedAt = reader.GetDateTime(5)
                });
            }

            reader.Close();
            CheckStatus(pStatus, pMessage);

            return list;
        }

        public async Task<string> ExportDatabaseJsonAsync()
        {
            using var conn = await GetAdminConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_data_management.export_database_json", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            // CLOB Output
            var pClob = cmd.Parameters.Add("o_json_clob", OracleDbType.Clob, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);

            // Читаем CLOB в строку
            if (pClob.Value is OracleClob clob && !clob.IsNull)
            {
                return clob.Value;
            }
            return "{}";
        }

        public async Task ImportDatabaseJsonAsync(string jsonContent)
        {
            using var conn = await GetAdminConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_data_management.import_database_json", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            // Передаем CLOB
            cmd.Parameters.Add("p_json_clob", OracleDbType.Clob, jsonContent, ParameterDirection.Input);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }
    }
}
