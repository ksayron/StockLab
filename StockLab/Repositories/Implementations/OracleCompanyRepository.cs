using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{   
    public class OracleCompanyRepository : ICompanyRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OracleCompanyRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory;
        }

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
                // Парсим сообщения на русском, которые мы прописали в PL/SQL
                if (msg.Contains("уже занят") || msg.Contains("существует"))
                    throw new InvalidOperationException(msg); // 409 Conflict

                if (msg.Contains("неверный ID") || msg.Contains("не найден"))
                    throw new KeyNotFoundException(msg); // 404 Not Found

                // Для "Внутренняя ошибка сервера" и всего остального
                throw new Exception($"DB Error: {msg}");
            }
        }

        // Вспомогательный метод для маппинга строки reader в CompanyDto
        // ВНИМАНИЕ: Порядок полей зависит от конкретной процедуры!
        // Для get_all_companies: id, name, ticker, price, sector_name, volatility, status
        private CompanyDto MapCompanyRow(OracleDataReader reader)
        {
            return new CompanyDto
            {
                Id = reader.GetInt32(0),
                Name = reader.GetString(1),
                Ticker = reader.GetString(2),
                CurrentPrice = reader.GetDecimal(3),
                SectorName = reader.GetString(4),
                Volatility = reader.GetDecimal(5),
                Status = reader.IsDBNull(6) ? "ACTIVE" : reader.GetString(6)
            };
        }

        // =========================================================
        // VIEW METHODS (GUEST ACCESS)
        // =========================================================

        public async Task<IEnumerable<CompanyDto>> GetCompaniesAsync(string? searchQuery, int? sectorId, string sortBy, string sortDir)
        {
            var list = new List<CompanyDto>();
            using var conn = await GetOpenConnectionAsync(DbRole.Guest);

            using var cmd = new OracleCommand("stock_admin.pkg_companies_view.get_companies", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            // Параметры могут быть NULL, OracleDBType обрабатывает это корректно
            cmd.Parameters.Add("p_search_query", OracleDbType.Varchar2, searchQuery, ParameterDirection.Input);
            cmd.Parameters.Add("p_sector_id", OracleDbType.Int32, sectorId, ParameterDirection.Input);
            cmd.Parameters.Add("p_sort_by", OracleDbType.Varchar2, sortBy, ParameterDirection.Input);
            cmd.Parameters.Add("p_sort_dir", OracleDbType.Varchar2, sortDir, ParameterDirection.Input);

            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            // Soft Error Params
            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(MapCompanyRow(reader));
            }

            reader.Close();
            CheckStatus(pStatus, pMessage);

            return list;
        }

        public async Task<CompanyDto?> GetByIdAsync(int id)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.Guest);
            using var cmd = new OracleCommand("stock_admin.pkg_companies_view.get_company_by_id", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_company_id", OracleDbType.Int32, id, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();

            CompanyDto result = null;
            if (await reader.ReadAsync())
            {
                result = new CompanyDto
                {
                    Id = reader.GetInt32(0),
                    Name = reader.GetString(1),
                    Ticker = reader.GetString(2),
                    Description = reader.IsDBNull(3) ? null : reader.GetString(3),
                    CurrentPrice = reader.GetDecimal(4),
                    SectorName = reader.GetString(6),
                    Volatility = reader.GetDecimal(7),
                    Status = "ACTIVE"
                };
            }

            reader.Close();
            CheckStatus(pStatus, pMessage);

            return result;
        }

        public async Task<IEnumerable<CompanyDto>> SearchAsync(string query)
        {
            var list = new List<CompanyDto>();
            using var conn = await GetOpenConnectionAsync(DbRole.Guest);
            using var cmd = new OracleCommand("stock_admin.pkg_companies_view.search_companies", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_query", OracleDbType.Varchar2, query, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new CompanyDto
                {
                    Id = reader.GetInt32(0),
                    Name = reader.GetString(1),
                    Ticker = reader.GetString(2),
                    CurrentPrice = reader.GetDecimal(3),
                    SectorName = reader.GetString(4)
                });
            }

            reader.Close();
            CheckStatus(pStatus, pMessage);

            return list;
        }
        public async Task<IEnumerable<PriceLogDto>> GetPriceHistoryAsync(int companyId, int hoursBack)
        {
            var list = new List<PriceLogDto>();
            using var conn = await GetOpenConnectionAsync(DbRole.Guest); // Guest достаточно
            using var cmd = new OracleCommand("stock_admin.pkg_companies_view.get_price_history", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_company_id", OracleDbType.Int32, companyId, ParameterDirection.Input);
            cmd.Parameters.Add("p_hours_back", OracleDbType.Int32, hoursBack, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new PriceLogDto
                {
                    Price = reader.GetDecimal(0),
                    Timestamp = reader.GetDateTime(1)
                });
            }
            reader.Close();
            CheckStatus(pStatus, pMessage);
            return list;
        }

        // Этот метод для фонового сервиса
        public async Task<IEnumerable<PriceUpdateDto>> GetRecentPriceUpdatesAsync(DateTime lastCheckTime)
        {
            var list = new List<PriceUpdateDto>();
            using var conn = await GetOpenConnectionAsync(DbRole.Guest);
            using var cmd = new OracleCommand("stock_admin.pkg_companies_view.get_recent_price_updates", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_last_check_time", OracleDbType.TimeStamp, lastCheckTime, ParameterDirection.Input);
            cmd.Parameters.Add("o_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new PriceUpdateDto
                {
                    CompanyId = reader.GetInt32(0),
                    NewPrice = reader.GetDecimal(1),
                    Timestamp = reader.GetDateTime(2)
                });
            }
            return list;
        }

        // =========================================================
        // ADMIN METHODS (ADMIN ACCESS)
        // =========================================================

        public async Task<int> CreateCompanyIpoAsync(CreateCompanyDto dto)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.Admin);
            using var cmd = new OracleCommand("stock_admin.pkg_companies_admin.add_company", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_sector_id", OracleDbType.Int32, dto.SectorId, ParameterDirection.Input);
            cmd.Parameters.Add("p_name", OracleDbType.Varchar2, dto.Name, ParameterDirection.Input);
            cmd.Parameters.Add("p_ticker", OracleDbType.Varchar2, dto.Ticker, ParameterDirection.Input);
            cmd.Parameters.Add("p_description", OracleDbType.Varchar2, dto.Description, ParameterDirection.Input);
            cmd.Parameters.Add("p_init_price", OracleDbType.Decimal, dto.InitPrice, ParameterDirection.Input);
            cmd.Parameters.Add("p_volatility", OracleDbType.Decimal, dto.Volatility, ParameterDirection.Input);
            cmd.Parameters.Add("p_total_shares", OracleDbType.Int32, dto.TotalShares, ParameterDirection.Input);

            var pNewId = cmd.Parameters.Add("o_company_id", OracleDbType.Int32, ParameterDirection.Output);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();

            CheckStatus(pStatus, pMessage);

            if (pNewId.Value is OracleDecimal decimalVal)
                return decimalVal.ToInt32();

            throw new Exception("Не удалось получить ID новой компании.");
        }

        public async Task UpdateCompanyAsync(int id, UpdateCompanyDto dto)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.Admin);
            using var cmd = new OracleCommand("stock_admin.pkg_companies_admin.update_company", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_company_id", OracleDbType.Int32, id, ParameterDirection.Input);
            cmd.Parameters.Add("p_sector_id", OracleDbType.Int32, dto.SectorId, ParameterDirection.Input);
            cmd.Parameters.Add("p_name", OracleDbType.Varchar2, dto.Name, ParameterDirection.Input);
            cmd.Parameters.Add("p_description", OracleDbType.Varchar2, dto.Description, ParameterDirection.Input);
            cmd.Parameters.Add("p_volatility", OracleDbType.Decimal, dto.Volatility, ParameterDirection.Input);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }

        public async Task DelistCompanyAsync(int id)
        {
            using var conn = await GetOpenConnectionAsync(DbRole.Admin);
            using var cmd = new OracleCommand("stock_admin.pkg_companies_admin.delist_company", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_company_id", OracleDbType.Int32, id, ParameterDirection.Input);

            var pStatus = cmd.Parameters.Add("o_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("o_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }
    }
}
