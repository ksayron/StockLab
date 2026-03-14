namespace StockLab.Data.Entities
{
    public class Trade
    {
        public int Id { get; set; }
        public int BuyOrderId { get; set; }
        public int SellOrderId { get; set; }
        public decimal Price { get; set; }
        public int Quantity { get; set; }
        public DateTime ExecutedAt { get; set; } = DateTime.UtcNow;

        public Order BuyOrder { get; set; } = null!;
        public Order SellOrder { get; set; } = null!;
    }
}
