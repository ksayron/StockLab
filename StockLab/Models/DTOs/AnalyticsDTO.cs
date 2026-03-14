namespace StockLab.Models.DTOs
{
    public class WindroseDto
    {
        public string Category { get; set; } = string.Empty;
        public double AvgGreed { get; set; }
        public double AvgPanic { get; set; }
        public double AvgMemory { get; set; }
        public double AvgBetSize { get; set; }
        public double AvgRoi { get; set; }
    }

    public class HeatmapDto
    {
        public int CompanyId { get; set; }
        public string CompanyName { get; set; } = string.Empty;
        public string Ticker { get; set; } = string.Empty;
        public string SectorName { get; set; } = string.Empty;
        public decimal ChangePercent { get; set; }
        public string Sentiment { get; set; } = string.Empty;
    }

    public class TopActiveDto
    {
        public int CompanyId { get; set; }
        public string CompanyName { get; set; } = string.Empty;
        public string Ticker { get; set; } = string.Empty;
        public string SectorName { get; set; } = string.Empty;
        public decimal CurrentPrice { get; set; }
        public int TradeCount { get; set; }
        public int Volume { get; set; }
    }
}
