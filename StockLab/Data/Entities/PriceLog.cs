namespace StockLab.Data.Entities
{
    public class PriceLog
    {
        public long Id { get; set; }
        public int CompanyId { get; set; }
        public decimal Price { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        public Company Company { get; set; } = null!;
    }
}
