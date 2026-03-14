namespace StockLab.Data.Entities
{
    public class SystemLog
    {
        public int Id { get; set; }
        public string ProcName { get; set; } = string.Empty;
        public int? UserId { get; set; }
        public string? ErrorCode { get; set; }
        public string ErrorMsg { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
