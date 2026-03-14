using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Models.DTOs;

namespace StockLab.Services
{
    public class NotificationService(AppDbContext db)
    {
        public async Task CreateTradeNotificationAsync(
            int buyerUserId, int sellerUserId,
            string companyName, string ticker,
            decimal price, int quantity)
        {
            var buyNotif = new Notification
            {
                Title = "Сделка исполнена",
                Message = $"BUY {quantity}x {ticker} @ {price:F2}",
                Type = NotificationType.TRADE
            };
            db.Notifications.Add(buyNotif);

            var sellNotif = new Notification
            {
                Title = "Сделка исполнена",
                Message = $"SELL {quantity}x {ticker} @ {price:F2}",
                Type = NotificationType.TRADE
            };
            db.Notifications.Add(sellNotif);
            await db.SaveChangesAsync();

            db.UserNotifications.Add(new UserNotification { UserId = buyerUserId, NotificationId = buyNotif.Id });
            db.UserNotifications.Add(new UserNotification { UserId = sellerUserId, NotificationId = sellNotif.Id });
            await db.SaveChangesAsync();
        }

        public async Task CreatePersonalNotificationAsync(int userId, string title, string message, NotificationType type)
        {
            var notif = new Notification { Title = title, Message = message, Type = type };
            db.Notifications.Add(notif);
            await db.SaveChangesAsync();

            db.UserNotifications.Add(new UserNotification { UserId = userId, NotificationId = notif.Id });
            await db.SaveChangesAsync();
        }

        public async Task<IEnumerable<NotificationDto>> GetUserNotificationsAsync(int userId, bool onlyUnread)
        {
            var query = db.UserNotifications
                .Where(un => un.UserId == userId)
                .Include(un => un.Notification)
                .AsQueryable();

            if (onlyUnread)
                query = query.Where(un => !un.IsRead);

            return await query
                .OrderByDescending(un => un.CreatedAt)
                .Take(50)
                .Select(un => new NotificationDto
                {
                    Id = un.Id,
                    Title = un.Notification.Title,
                    Message = un.Notification.Message,
                    Type = un.Notification.Type.ToString(),
                    IsRead = un.IsRead,
                    CreatedAt = un.CreatedAt
                })
                .ToListAsync();
        }

        public async Task<IEnumerable<NotificationDto>> GetRecentUnreadAsync(int userId, DateTime since)
        {
            return await db.UserNotifications
                .Where(un => un.UserId == userId && !un.IsRead && un.CreatedAt >= since)
                .Include(un => un.Notification)
                .Select(un => new NotificationDto
                {
                    Id = un.Id,
                    Title = un.Notification.Title,
                    Message = un.Notification.Message,
                    Type = un.Notification.Type.ToString(),
                    IsRead = un.IsRead,
                    CreatedAt = un.CreatedAt
                })
                .ToListAsync();
        }

        public async Task MarkAsReadAsync(int userId, int userNotificationId)
        {
            var notif = await db.UserNotifications
                .FirstOrDefaultAsync(un => un.Id == userNotificationId && un.UserId == userId)
                ?? throw new KeyNotFoundException("Уведомление не найдено");

            notif.IsRead = true;
            await db.SaveChangesAsync();
        }
    }
}
