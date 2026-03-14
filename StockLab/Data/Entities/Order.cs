namespace StockLab.Data.Entities
{
    public enum OrderType { BUY, SELL }
    public enum OrderStatus { OPEN, PARTIAL, FILLED, CANCELLED }

    public class Order
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int CompanyId { get; set; }
        public OrderType Type { get; set; }
        public OrderStatus Status { get; set; } = OrderStatus.OPEN;
        public decimal LimitPrice { get; set; }
        public int OriginalQty { get; set; }
        public int RemainingQty { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public User User { get; set; } = null!;
        public Company Company { get; set; } = null!;

        public ICollection<Trade> BuyTrades { get; set; } = [];
        public ICollection<Trade> SellTrades { get; set; } = [];
    }
}
