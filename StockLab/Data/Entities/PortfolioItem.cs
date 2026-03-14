namespace StockLab.Data.Entities
{
    public class PortfolioItem
    {
        public int UserId { get; set; }
        public int CompanyId { get; set; }
        public int QuantityOwned { get; set; }

        public User User { get; set; } = null!;
        public Company Company { get; set; } = null!;
    }
}
