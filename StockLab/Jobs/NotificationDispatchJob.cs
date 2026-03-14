using Microsoft.AspNetCore.SignalR;
using StockLab.Hubs;
using StockLab.Services;
using StockLab.Services.Implementations;

namespace StockLab.Jobs
{
    public class NotificationDispatchJob(
        NotificationService notificationService,
        ConnectionManager connectionManager,
        IHubContext<NotificationHub> notificationHub)
    {
        public async Task ExecuteAsync()
        {
            var onlineUserIds = connectionManager.GetOnlineUserIds();
            if (!onlineUserIds.Any()) return;

            foreach (var userId in onlineUserIds)
            {
                var since = connectionManager.GetLastCheckTime(userId);
                var newNotifications = await notificationService.GetRecentUnreadAsync(userId, since);

                if (newNotifications.Any())
                {
                    await notificationHub.Clients
                        .Group($"USER_{userId}")
                        .SendAsync("ReceiveNotifications", newNotifications);
                }

                connectionManager.UpdateLastCheckTime(userId, DateTime.UtcNow);
            }
        }
    }
}
