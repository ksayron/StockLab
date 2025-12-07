using Oracle.ManagedDataAccess.Client;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{
    public class OracleNotificationsRepository : INotificationsRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OracleNotificationsRepository(IDbConnectionFactory dbFactory)
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
            if (pStatus.Value?.ToString() == "ERROR")
                throw new Exception($"DB Error: {pMessage.Value}");
        }

        public async Task<IEnumerable<NotificationDto>> GetMyNotificationsAsync(int userId, bool onlyUnread)
        {
            var list = new List<NotificationDto>();
            using var conn = await GetOpenConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_notifications.get_my_notifications", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);
            cmd.Parameters.Add("p_only_unread", OracleDbType.Int32, onlyUnread ? 1 : 0, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new NotificationDto
                {
                    Id = reader.GetInt32(0),
                    Title = reader.GetString(1),
                    Message = reader.GetString(2),
                    Type = reader.GetString(3),
                    CreatedAt = reader.GetDateTime(4),
                    IsRead = reader.GetInt32(5) == 1
                });
            }
            reader.Close();
            CheckStatus(pStatus, pMessage);
            return list;
        }

        public async Task MarkAsReadAsync(int userId, int notificationId)
        {
            using var conn = await GetOpenConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_notifications.mark_as_read", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);
            cmd.Parameters.Add("p_notification_id", OracleDbType.Int32, notificationId, ParameterDirection.Input);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }
        public async Task<IEnumerable<NotificationDto>> GetRecentAsync(int userId, DateTime since)
        {
            var list = new List<NotificationDto>();
            using var conn = await GetOpenConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_notifications.get_recent_notifications", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_user_id", OracleDbType.Int32, userId, ParameterDirection.Input);
            cmd.Parameters.Add("p_since_time", OracleDbType.TimeStamp, since, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new NotificationDto
                {
                    Id = reader.GetInt32(0),
                    Title = reader.GetString(1),
                    Message = reader.GetString(2),
                    Type = reader.GetString(3),
                    CreatedAt = reader.GetDateTime(4),
                    IsRead = reader.GetInt32(5) == 1
                });
            }
            return list;
        }
    }
}
