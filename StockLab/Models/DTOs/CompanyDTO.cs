namespace StockLab.Models.DTOs
{
    // OUTPUT: То, что видит пользователь
    public class CompanyDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Ticker { get; set; }
        public decimal CurrentPrice { get; set; }
        public string SectorName { get; set; }
        public decimal Volatility { get; set; }
        public string Status { get; set; }
        public string Description { get; set; } // Добавляем, так как есть в get_company_by_id
    }

    // INPUT: Создание (IPO)
    public class CreateCompanyDto
    {
        public int SectorId { get; set; }
        public string Name { get; set; }
        public string Ticker { get; set; }
        public string Description { get; set; }
        public decimal InitPrice { get; set; }
        public decimal Volatility { get; set; } // 0.1 - 1.0
        public int TotalShares { get; set; } // Для IPO (напр. 1 000 000)
    }

    // INPUT: Обновление (Тикер менять нельзя)
    public class UpdateCompanyDto
    {
        public int SectorId { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public decimal Volatility { get; set; }
    }
    public class PriceLogDto
    {
        public decimal Price { get; set; }
        public DateTime Timestamp { get; set; }
    }
    public class PriceUpdateDto
    {
        public int CompanyId { get; set; }
        public decimal NewPrice { get; set; }
        public DateTime Timestamp { get; set; }
    }
}
