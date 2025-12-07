namespace StockLab.Models.DTOs
{
    public class NotificationDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Message { get; set; }
        public string Type { get; set; } // INFO, SUCCESS, ERROR
        public bool IsRead { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
