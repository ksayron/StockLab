using Microsoft.AspNetCore.SignalR;
using StockLab.Hubs;
using StockLab.Repositories.Interfaces;

namespace StockLab.Services.Implementations
{
    public class AnalyticsBroadcastService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly IHubContext<DashboardHub> _hubContext;
        private readonly ILogger<AnalyticsBroadcastService> _logger;

        public AnalyticsBroadcastService(
            IServiceProvider serviceProvider,
            IHubContext<DashboardHub> hubContext,
            ILogger<AnalyticsBroadcastService> logger)
        {
            _serviceProvider = serviceProvider;
            _hubContext = hubContext;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            await Task.Delay(5000, stoppingToken);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using (var scope = _serviceProvider.CreateScope())
                    {
                        var repo = scope.ServiceProvider.GetRequiredService<IAnalyticsRepository>();
                        var botRepo = scope.ServiceProvider.GetRequiredService<IBotRepository>();

                        var status = await botRepo.GetTournamentStatusAsync();

                        if (status == "ACTIVE")
                        {
                            // 1. Получаем данные
                            var windroseTask = repo.GetWindroseDataAsync();
                            var heatmapTask = repo.GetMarketHeatmapAsync();
                            var top5Task = repo.GetTopActiveCompaniesAsync();

                            await Task.WhenAll(windroseTask, heatmapTask, top5Task);

                            // 2. Рассылка СЕКРЕТНЫХ данных (Только группе Admins)
                            // Обычные юзеры даже не получат эти пакеты по сети
                            if (windroseTask.Result.Any())
                            {
                                await _hubContext.Clients.Group("Admins")
                                    .SendAsync("ReceiveWindrose", windroseTask.Result, stoppingToken);
                            }

                            if (heatmapTask.Result.Any())
                            {
                                await _hubContext.Clients.Group("Admins")
                                    .SendAsync("ReceiveHeatmap", heatmapTask.Result, stoppingToken);
                            }

                            // 3. Рассылка ПУБЛИЧНЫХ данных (Всем подключенным)
                            // Это видят и Админы, и Юзеры, и Гости
                            if (top5Task.Result.Any())
                            {
                                await _hubContext.Clients.All
                                    .SendAsync("ReceiveTop5", top5Task.Result, stoppingToken);
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Ошибка в сервисе аналитики");
                }

                await Task.Delay(3000, stoppingToken);
            }
        }
    }
}
