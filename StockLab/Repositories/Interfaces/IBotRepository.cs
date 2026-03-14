using StockLab.Models.DTOs;

namespace StockLab.Repositories.Interfaces
{
    public interface IBotRepository
    {
        // Управление циклом
        Task GenerateAndStartSeasonAsync(int botCount);
        Task StartTournamentAsync();
        Task PauseTournamentAsync();
        Task FinalizeTournamentAsync();

        // Статус
        Task<string> GetTournamentStatusAsync();

        // Данные
        Task<IEnumerable<BotSummaryDto>> GetAllBotsAsync();
        Task<BotDetailDto?> GetBotDetailsAsync(int botId);
    }
}
