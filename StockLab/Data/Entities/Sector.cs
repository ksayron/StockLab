namespace StockLab.Data.Entities
{
    public class Sector
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal Buff { get; set; } = 1.0m;

        public ICollection<Company> Companies { get; set; } = [];
    }
}
