using Oracle.ManagedDataAccess.Client;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Data;

namespace StockLab.Repositories.Implementations
{
    public class OracleBotRepository : IBotRepository
    {
        private readonly IDbConnectionFactory _dbFactory;

        public OracleBotRepository(IDbConnectionFactory dbFactory)
        {
            _dbFactory = dbFactory;
        }

        // Используем роль Admin, так как управление ботами - это админская функция
        private async Task<OracleConnection> GetConnectionAsync()
        {
            var conn = (OracleConnection)_dbFactory.CreateConnection(DbRole.Admin);
            await conn.OpenAsync();
            return conn;
        }

        // Хелпер для проверки статуса (аналогично AdminRepo)
        private void CheckStatus(OracleParameter pStatus, OracleParameter pMessage)
        {
            string? status = pStatus.Value?.ToString();
            string? msg = pMessage.Value?.ToString();

            if (status == "ERROR")
            {
                throw new Exception($"Bot Engine Error: {msg}");
            }
            if (status == "WARNING")
            {
                // Можно логировать или бросать специфичное исключение, 
                // но часто достаточно просто Exception с сообщением
                throw new InvalidOperationException($"Warning: {msg}");
            }
        }

        public async Task GenerateAndStartSeasonAsync(int botCount)
        {
            using var conn = await GetConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_market_bots.generate_and_start_new_season", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_bot_count", OracleDbType.Int32, botCount, ParameterDirection.Input);

            var pStatus = cmd.Parameters.Add("p_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("p_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }

        public async Task StartTournamentAsync()
        {
            using var conn = await GetConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_market_bots.start_tournament", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            var pStatus = cmd.Parameters.Add("p_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("p_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }

        public async Task PauseTournamentAsync()
        {
            using var conn = await GetConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_market_bots.pause_tournament", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            var pStatus = cmd.Parameters.Add("p_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("p_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }

        public async Task FinalizeTournamentAsync()
        {
            using var conn = await GetConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_market_bots.finalize_tournament", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            var pStatus = cmd.Parameters.Add("p_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("p_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            await cmd.ExecuteNonQueryAsync();
            CheckStatus(pStatus, pMessage);
        }

        public async Task<string> GetTournamentStatusAsync()
        {
            using var conn = await GetConnectionAsync();
            // Вызов функции внутри SQL запроса (так проще всего получить результат функции через ADO.NET)
            using var cmd = new OracleCommand("SELECT stock_admin.pkg_market_bots.get_current_status_code FROM DUAL", conn);

            var result = await cmd.ExecuteScalarAsync();
            return result?.ToString() ?? "UNKNOWN";
        }

        public async Task<IEnumerable<BotSummaryDto>> GetAllBotsAsync()
        {
            var list = new List<BotSummaryDto>();
            using var conn = await GetConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_market_bots.get_all_bots", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            var pStatus = cmd.Parameters.Add("p_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("p_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();

            // Важно: Порядок считывания должен совпадать с SELECT в процедуре
            // SELECT u.user_id, u.username, nw, greed, panic, memory, bet, current_rank, last_rank
            while (await reader.ReadAsync())
            {
                list.Add(new BotSummaryDto
                {
                    UserId = reader.GetInt32(0),
                    Username = reader.GetString(1),
                    NetWorth = reader.GetDecimal(2),
                    GreedFactor = reader.GetDecimal(3),
                    PanicLevel = reader.GetDecimal(4),
                    MemorySpan = reader.GetInt32(5),
                    BetSize = reader.GetDecimal(6),
                    CurrentRank = reader.GetInt32(7),
                    LastRank = null
                });
            }
            reader.Close();
            CheckStatus(pStatus, pMessage);
            return list;
        }

        public async Task<BotDetailDto?> GetBotDetailsAsync(int botId)
        {
            using var conn = await GetConnectionAsync();
            using var cmd = new OracleCommand("stock_admin.pkg_market_bots.get_bot_details", conn);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.BindByName = true;

            cmd.Parameters.Add("p_bot_id", OracleDbType.Int32, botId, ParameterDirection.Input);
            cmd.Parameters.Add("p_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            var pStatus = cmd.Parameters.Add("p_status", OracleDbType.Varchar2, 50, null, ParameterDirection.Output);
            var pMessage = cmd.Parameters.Add("p_message", OracleDbType.Varchar2, 4000, null, ParameterDirection.Output);

            using var reader = await cmd.ExecuteReaderAsync();
            // SELECT u.user_id, u.username, u.balance, networth, bc.greed, bc.panic, bc.mem, bc.bet, total_games, avg_roi
            if (await reader.ReadAsync())
            {
                var dto = new BotDetailDto
                {
                    UserId = reader.GetInt32(0),
                    Username = reader.GetString(1),
                    CashBalance = reader.GetDecimal(2), // balance
                    NetWorth = reader.GetDecimal(3),    // calculated networth

                    // Bot Configs (bc.*)
                    GreedFactor = reader.GetDecimal(5), // user_id is index 4 if bc.* included key
                    PanicLevel = reader.GetDecimal(6),
                    MemorySpan = reader.GetInt32(7),
                    BetSize = reader.GetDecimal(8),

                    // History Stats
                    TotalGamesPlayed = reader.GetInt32(9),
                    AverageRoi = reader.IsDBNull(10) ? null : reader.GetDecimal(10)
                };

                // Rank logic might not be in detail cursor per package spec, 
                // if needed we can fetch it separately or rely on get_all_bots for ranking.
                // For now, leaving ranks 0 in details or calculate later.

                reader.Close();
                CheckStatus(pStatus, pMessage);
                return dto;
            }

            reader.Close();
            CheckStatus(pStatus, pMessage);
            return null;
        }
    }
}
