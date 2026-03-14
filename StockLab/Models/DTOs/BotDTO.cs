namespace StockLab.Models.DTOs
{
    // Для списка всех ботов
    public class BotSummaryDto
    {
        public int UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public decimal NetWorth { get; set; }
        public decimal GreedFactor { get; set; }
        public decimal PanicLevel { get; set; }
        public int MemorySpan { get; set; }
        public decimal BetSize { get; set; }
        public int CurrentRank { get; set; }
        public int? LastRank { get; set; } // Может быть null, если бот новый
    }

    // Для детальной страницы бота
    public class BotDetailDto : BotSummaryDto
    {
        public decimal CashBalance { get; set; } // Чистый кэш (отдельно от NetWorth)
        public int TotalGamesPlayed { get; set; }
        public decimal? AverageRoi { get; set; }
    }

    // Для управления турниром (Request Body)
    public class GenerateSeasonDto
    {
        public int BotCount { get; set; } = 100;
    }   
}
