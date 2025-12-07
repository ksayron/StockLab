using Microsoft.AspNetCore.SignalR;
using StockLab.Hubs;
using StockLab.Repositories.Interfaces;

namespace StockLab.Services.Implementations
{
    public class NotificationBackgroundService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ConnectionManager _connectionManager;
        private readonly IHubContext<NotificationHub> _hubContext;

        public NotificationBackgroundService(
            IServiceProvider serviceProvider,
            ConnectionManager connectionManager,
            IHubContext<NotificationHub> hubContext)
        {
            _serviceProvider = serviceProvider;
            _connectionManager = connectionManager;
            _hubContext = hubContext;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var onlineUserIds = _connectionManager.GetOnlineUserIds();

                    // Если никого нет, просто спим
                    if (onlineUserIds.Any())
                    {
                        // Создаем Scope один раз на цикл проверки
                        using (var scope = _serviceProvider.CreateScope())
                        {
                            var repo = scope.ServiceProvider.GetRequiredService<INotificationsRepository>();

                            foreach (var userId in onlineUserIds)
                            {
                                var lastCheck = _connectionManager.GetLastCheckTime(userId);

                                // Получаем новые уведомления из БД
                                var newNotifications = await repo.GetRecentAsync(userId, lastCheck);

                                if (newNotifications.Any())
                                {
                                    // Отправляем через WebSockets конкретному юзеру
                                    await _hubContext.Clients.Group($"USER_{userId}")
                                        .SendAsync("ReceiveNotifications", newNotifications);

                                    // Обновляем время проверки (берем время самого свежего уведомления)
                                    var newestTime = newNotifications.Max(n => n.CreatedAt);
                                    _connectionManager.UpdateLastCheckTime(userId, newestTime);
                                }
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[NotificationWorker Error]: {ex.Message}");
                }

                // Проверяем раз в 2 секунды (баланс между скоростью и нагрузкой на БД)
                await Task.Delay(2000, stoppingToken);
            }
        }
    }
}
