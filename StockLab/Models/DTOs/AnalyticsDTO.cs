namespace StockLab.Models.DTOs
{
    public class WindroseDto
    {
        public string Category { get; set; } = string.Empty; // "Winners", "Losers", "Average"
        public decimal AvgGreed { get; set; }
        public decimal AvgPanic { get; set; }
        public decimal AvgMemory { get; set; }
        public decimal AvgBetSize { get; set; }
        public decimal AvgRoi { get; set; }
    }

    public class HeatmapDto
    {
        public string Level1 { get; set; } = string.Empty; // Sector or Global
        public string Level2 { get; set; } = string.Empty; // Company or Sector_Total
        public decimal TotalVolume { get; set; }
        public decimal WeightedChange { get; set; }
        public string Status { get; set; } = string.Empty; // BULLISH / BEARISH
    }

    public class TopActiveDto
    {
        public string CompanyName { get; set; } = string.Empty;
        public string Ticker { get; set; } = string.Empty;
        public int TotalShares { get; set; }
        public int TradeCount { get; set; }
    }
}
