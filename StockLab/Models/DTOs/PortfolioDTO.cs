namespace StockLab.Models.DTOs
{
    public class PortfolioSummaryDto
    {
        public decimal CashBalance { get; set; }
        public decimal StocksValue { get; set; }
        public decimal TotalEquity { get; set; }
        public decimal ChangeAbs { get; set; }    // Изменение в $ за 15 мин
        public decimal ChangePercent { get; set; } // Изменение в % за 15 мин
    }

    public class PortfolioItemDto
    {
        public int CompanyId { get; set; }
        public string Ticker { get; set; }
        public string Name { get; set; }
        public int Quantity { get; set; }
        public decimal CurrentPrice { get; set; }
        public decimal TotalValue { get; set; }
        public decimal PriceChangeAbs { get; set; } // Изменение цены акции ($)
        public decimal PriceChangePercent { get; set; } // Изменение цены акции (%)
    }
}
