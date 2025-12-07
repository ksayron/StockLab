namespace StockLab.Models.DTOs
{
    // INPUT: Создание ордера
    public class PlaceOrderDto
    {
        public int CompanyId { get; set; }
        public string Type { get; set; } // "BUY" или "SELL"
        public int Quantity { get; set; }
        public decimal LimitPrice { get; set; }
    }

    // OUTPUT: Просмотр ордера
    public class OrderDto
    {
        public int Id { get; set; }
        public string Ticker { get; set; }
        public string Type { get; set; }
        public string Status { get; set; }
        public decimal LimitPrice { get; set; }
        public int OriginalQty { get; set; }
        public int RemainingQty { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
