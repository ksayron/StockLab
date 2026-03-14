namespace StockLab.Data.Entities
{
    public class BotConfig
    {
        public int UserId { get; set; }
        public decimal GreedFactor { get; set; }
        public decimal PanicLevel { get; set; }
        public int MemorySpan { get; set; }
        public decimal BetSize { get; set; }

        public User User { get; set; } = null!;
    }
}
