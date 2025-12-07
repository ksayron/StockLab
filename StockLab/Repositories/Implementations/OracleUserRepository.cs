using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{
    public class OracleUserRepository : IUserRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OracleUserRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory;
        }

        // Helper to get an open OracleConnection from the factory
        private async Task<OracleConnection> GetOpenConnectionAsync(DbRole role)
        {
            var conn = (OracleConnection)_dbFactory.CreateConnection(role);
            await conn.OpenAsync();
            return conn;
        }
        private void CheckStatus(OracleParameter pStatus, OracleParameter pMessage)
        {
            string status = pStatus.Value?.ToString();
            string msg = pMessage.Value?.ToString();

            if (status == "ERROR")
            {
                // Тут мы превращаем "Мягкую ошибку БД" в "Исключение C#" 
                // чтобы Контроллер мог вернуть правильный HTTP код (400/401/409).

                if (msg.Contains("Неподходящие логин и пароль"))
                    throw new UnauthorizedAccessException(msg); // 401

                if (msg.Contains("заблокирован"))
                    throw new UnauthorizedAccessException(msg); // 403/401

                if (msg.Contains("заняты") || msg.Contains("зарезервированный"))
                    throw new InvalidOperationException(msg); // 409 Conflict / 400 Bad Request

                if (msg.Contains("не найден"))
                    throw new KeyNotFoundException(msg); // 404

                throw new Exception($"DB Error: {msg}");
            }
        }

        // ---------------------------------------------------------
        // 1. AUTHENTICATE (Login)
        // ---------------------------------------------------------
       public async Task<AuthResult> AuthenticateAsync(string username, string passwordHash)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.Guest);
            using var cmd = new OracleCommand("stock_admin.pkg_users.authenticate_user", conn)
            {
                CommandType = CommandType.StoredProcedure,
                BindByName = true
            };

            cmd.Parameters.Add("p_username", OracleDbType.Varchar2, username, ParameterDirection.Input);
            cmd.Parameters.Add("p_password_hash", OracleDbType.Varchar2, passwordHash, ParameterDirection.Input);

            // OUT Data
            var pUserId = cmd.Parameters.Add("o_user_id", OracleDbType.Int32, ParameterDirection.Output);
            var pRoleName = cmd.Parameters.Add("o_role_name", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pIsBanned = cmd.Parameters.Add("o_is_banned", OracleDbType.Int32, ParameterDirection.Output);

            // OUT Status (Soft Error)
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();

            // Проверяем ошибки
            CheckStatus(pStatus, pMessage);

            // Если успешно - маппим
            int userId = ((OracleDecimal)pUserId.Value).ToInt32();
            int bannedVal = ((OracleDecimal)pIsBanned.Value).ToInt32();

            return new AuthResult
            {
                UserId = userId,
                RoleName = pRoleName.Value.ToString(),
                IsBanned = (bannedVal == 1)
            };
        }

        // ---------------------------------------------------------
        // 2. REGISTER
        // ---------------------------------------------------------
        public async Task RegisterAsync(string username, string email, string passwordHash)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.Guest);
            using var cmd = new OracleCommand("stock_admin.pkg_users.register_user", conn)
            {
                CommandType = CommandType.StoredProcedure,
                BindByName = true
            };

            cmd.Parameters.Add("p_username", OracleDbType.Varchar2, username, ParameterDirection.Input);
            cmd.Parameters.Add("p_email", OracleDbType.Varchar2, email, ParameterDirection.Input);
            cmd.Parameters.Add("p_password_hash", OracleDbType.Varchar2, passwordHash, ParameterDirection.Input);

            cmd.Parameters.Add("o_user_id", OracleDbType.Int32, ParameterDirection.Output);
            cmd.Parameters.Add("o_role_name", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);

            // Soft Error Params
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();

            CheckStatus(pStatus, pMessage);
        }

        // ---------------------------------------------------------
        // 3. GET USER PROFILE
        // ---------------------------------------------------------
        public async Task<UserProfileDto> GetUserProfileAsync(int userId)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.User);
            using var cmd = new OracleCommand("stock_admin.pkg_users.get_user_details", conn)
            {
                CommandType = CommandType.StoredProcedure,
                BindByName = true
            };

            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            // Soft Error Params
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();

            // Сначала проверяем статус, вдруг там ошибка (хотя при открытии курсора это редкость)
            CheckStatus(pStatus, pMessage);

            if (await reader.ReadAsync())
            {
                return new UserProfileDto
                {
                    UserId = reader.GetInt32(0),
                    Username = reader.GetString(1),
                    Email = reader.GetString(2),
                    Balance = reader.GetDecimal(3),
                    CreatedAt = reader.GetDateTime(4),
                    RoleName = reader.GetString(5)
                };
            }

            return null;
        }

        // ---------------------------------------------------------
        // 4. DEPOSIT CASH
        // ---------------------------------------------------------
        public async Task DepositCashAsync(int userId, decimal amount)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.User);
            using var cmd = new OracleCommand("stock_admin.pkg_users.deposit_cash", conn)
            {
                CommandType = CommandType.StoredProcedure,
                BindByName = true
            };

            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);
            cmd.Parameters.Add("p_amount", OracleDbType.Decimal, amount, ParameterDirection.Input);

            // Soft Error Params
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();

            CheckStatus(pStatus, pMessage);
        }
    }
}
