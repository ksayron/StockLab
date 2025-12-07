using Oracle.ManagedDataAccess.Client;
using StockLab.Models.DTOs;
using StockLab.Services.Interfaces;
using System.Data;

namespace StockLab.Services.Implementations
{
    public class OracleUserService : IUserService
    {
        IConfiguration _config;
        public OracleUserService(IConfiguration config)
        {
            _config = config;
        }

        OracleConnection GetOracleConnection()
        {
            return new OracleConnection(_config.GetConnectionString("OracleDB"));
        }

        public async Task AddUserAsync(RegisterRequest req)
        {
            using var conn = GetOracleConnection();
            await conn.OpenAsync();
            using var cmd = new OracleCommand("pkg_users.add_user", conn)
            {
                CommandType = CommandType.StoredProcedure
            };
            cmd.Parameters.Add("p_username", OracleDbType.Varchar2, req.Username, ParameterDirection.Input);
            cmd.Parameters.Add("p_password_hash", OracleDbType.Varchar2, req.PasswordHash, ParameterDirection.Input);
            cmd.Parameters.Add("p_email", OracleDbType.Varchar2, req.Email, ParameterDirection.Input);
            cmd.Parameters.Add("p_role_id", OracleDbType.Int32, 2, ParameterDirection.Input);
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task<int?> AuthLoginAsync(string username, string passwordHash)
        {
            using var conn = GetOracleConnection();
            await conn.OpenAsync();
            using var cmd = new OracleCommand("BEGIN :result := pkg_users.validate_login(:u, :p); END;", conn);
            cmd.Parameters.Add("result", OracleDbType.Int32, ParameterDirection.ReturnValue);
            cmd.Parameters.Add("u", OracleDbType.Varchar2, username, ParameterDirection.Input);
            cmd.Parameters.Add("p", OracleDbType.Varchar2, passwordHash, ParameterDirection.Input);

            await cmd.ExecuteNonQueryAsync();
            return cmd.Parameters["result"].Value as int?;
        }

        public async Task<IEnumerable<UserDTO>> GetUsersAsync()
        {
            var users = new List<UserDTO>();
            using var conn = GetOracleConnection();
            await conn.OpenAsync();
            using var cmd = new OracleCommand("pkg_users.get_users", conn)
            {
                CommandType = CommandType.StoredProcedure
            };
            cmd.Parameters.Add("p_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                users.Add(new UserDTO
                {
                    Id = reader.GetInt32(0),
                    Username = reader.GetString(1),
                    PasswordHash = reader.GetString(2),
                    Email = reader.GetString(3),
                    RoleId = reader.GetInt32(4),
                    Balance = reader.GetDecimal(5)
                });
            }
            return users;
        }

        public async Task<UserDTO?> GetUserByUsernameAsync(string username)
        {
            using var conn = GetOracleConnection();
            using var cmd = new OracleCommand("pkg_users.get_user_by_username", conn)
            {
                CommandType = CommandType.StoredProcedure
            };
            cmd.Parameters.Add("p_username", OracleDbType.Varchar2).Value = username;
            cmd.Parameters.Add("p_cursor", OracleDbType.RefCursor).Direction = ParameterDirection.Output;

            await conn.OpenAsync();
            using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return new UserDTO
                {
                    Id = reader.GetInt32(0),
                    Username = reader.GetString(1),
                    PasswordHash = reader.GetString(2),
                    Email = reader.GetString(3),
                    RoleId = reader.GetInt32(4),
                    Balance = reader.GetDecimal(5)
                };
            }
            return null;
        }
    }
}
