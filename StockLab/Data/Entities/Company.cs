namespace StockLab.Data.Entities
{
    public enum CompanyStatus { ACTIVE, DELISTED, BANKRUPT }

    public class Company
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Ticker { get; set; } = string.Empty;
        public string? Description { get; set; }
        public int SectorId { get; set; }
        public decimal CurrentPrice { get; set; }
        public decimal Volatility { get; set; }
        public int TotalShares { get; set; }
        public CompanyStatus Status { get; set; } = CompanyStatus.ACTIVE;
        public DateTime? LastTradeAt { get; set; }

        public Sector Sector { get; set; } = null!;
        public ICollection<PriceLog> PriceLogs { get; set; } = [];
        public ICollection<Order> Orders { get; set; } = [];
        public ICollection<PortfolioItem> PortfolioItems { get; set; } = [];
    }
}
