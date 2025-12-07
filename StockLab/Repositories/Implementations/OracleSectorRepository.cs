using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{
    public class OracleSectorRepository : ISectorRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OracleSectorRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory;
        }

        // Вспомогательный метод для получения соединения
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
                if (msg.Contains("занято") || msg.Contains("используется"))
                    throw new InvalidOperationException(msg); // 400 Bad Request / 409 Conflict

                if (msg.Contains("not found"))
                    throw new KeyNotFoundException(msg); // 404

                throw new Exception($"DB Error: {msg}"); // 500
            }
        }

        // =========================================================
        // PUBLIC METHODS (Используем GUEST Connection)
        // =========================================================

        public async Task<IEnumerable<SectorDto>> GetAllSectorsAsync()
        {
            var sectors = new List<SectorDto>();

            // 1. Подключаемся как Guest
            using var conn = await GetOpenConnectionAsync(DbRole.Guest);

            // 2. Настраиваем команду
            using var cmd = new OracleCommand("stock_admin.pkg_market_view.get_all_sectors", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true; // Важно для именованных параметров

            // 3. Параметр курсора (OUT)
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            // 4. Выполняем и читаем
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                sectors.Add(new SectorDto
                {
                    // Индексы соответствуют SELECT в пакете: sector_id, name, description
                    Id = reader.GetInt32(0),
                    Name = reader.GetString(1),
                    // Проверка на NULL для описания
                    Description = reader.IsDBNull(2) ? null : reader.GetString(2)
                });
            }

            reader.Close();
            CheckStatus(pStatus, pMessage);

            return sectors;
        }

        public async Task<SectorDto?> GetSectorByIdAsync(int id)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.Guest);

            using var cmd = new OracleCommand("stock_admin.pkg_market_view.get_sector_by_id", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            // Входной параметр
            cmd.Parameters.Add("p_sector_id", OracleDbType.Int32, id, ParameterDirection.Input);
            // Выходной курсор
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return new SectorDto
                {
                    Id = reader.GetInt32(0),
                    Name = reader.GetString(1),
                    Description = reader.IsDBNull(2) ? null : reader.GetString(2)
                };
            }

            reader.Close();
            CheckStatus(pStatus, pMessage);

            return null; // Если ничего не нашли
        }

        // =========================================================
        // ADMIN METHODS (Используем ADMIN Connection)
        // =========================================================

        public async Task<int> AddSectorAsync(string name, string description)
        {
            // Используем ADMIN роль
            using var conn = await GetOpenConnectionAsync(DbRole.Admin);

            using var cmd = new OracleCommand("stock_admin.pkg_market_admin.add_sector", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            // Input Params
            cmd.Parameters.Add("p_name", OracleDbType.Varchar2, name, ParameterDirection.Input);
            cmd.Parameters.Add("p_description", OracleDbType.Varchar2, description, ParameterDirection.Input);

            // Output Param (ID созданного сектора)
            var pNewId = cmd.Parameters.Add("o_sector_id", OracleDbType.Int32, ParameterDirection.Output);
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();

            CheckStatus(pStatus, pMessage);
            // Извлекаем значение из OUT параметра
            // OracleDecimal нужно привести к int
            if (pNewId.Value is OracleDecimal decimalVal)
            {
                return decimalVal.ToInt32();
            }

            
            throw new Exception("Не удалось получить ID созданного сектора");
        }

        public async Task UpdateSectorAsync(int id, string name, string description)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.Admin);

            using var cmd = new OracleCommand("stock_admin.pkg_market_admin.update_sector", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_sector_id", OracleDbType.Int32, id, ParameterDirection.Input);
            cmd.Parameters.Add("p_name", OracleDbType.Varchar2, name, ParameterDirection.Input);
            cmd.Parameters.Add("p_description", OracleDbType.Varchar2, description, ParameterDirection.Input);
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();

            CheckStatus(pStatus, pMessage);
        }

        public async Task DeleteSectorAsync(int id)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.Admin);

            using var cmd = new OracleCommand("stock_admin.pkg_market_admin.delete_sector", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_sector_id", OracleDbType.Int32, id, ParameterDirection.Input);
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();

            CheckStatus(pStatus, pMessage);
        }
    }
}
