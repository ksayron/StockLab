using StockLab.Models.DTOs;

namespace StockLab.Repositories.Interfaces
{
    public interface INotificationsRepository
    {
        Task<IEnumerable<NotificationDto>> GetMyNotificationsAsync(int userId, bool onlyUnread);
        Task MarkAsReadAsync(int userId, int notificationId);
        Task<IEnumerable<NotificationDto>> GetRecentAsync(int userId, DateTime since);
    }
}
