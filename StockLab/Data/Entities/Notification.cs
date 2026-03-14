namespace StockLab.Data.Entities
{
    public enum NotificationType { INFO, SUCCESS, WARNING, ERROR, TRADE }

    public class Notification
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public NotificationType Type { get; set; } = NotificationType.INFO;

        public ICollection<UserNotification> UserNotifications { get; set; } = [];
    }
}
