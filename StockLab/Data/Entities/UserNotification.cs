namespace StockLab.Data.Entities
{
    public class UserNotification
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int NotificationId { get; set; }
        public bool IsRead { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public User User { get; set; } = null!;
        public Notification Notification { get; set; } = null!;
    }
}
