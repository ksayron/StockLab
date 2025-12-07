using Microsoft.AspNetCore.SignalR;
using StockLab.Hubs;
using StockLab.Repositories.Interfaces;

namespace StockLab.Services.Implementations
{
    public class MarketBackgroundService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly IHubContext<MarketHub> _hubContext;
        private DateTime _lastCheckTime;

        public MarketBackgroundService(IServiceProvider serviceProvider, IHubContext<MarketHub> hubContext)
        {
            _serviceProvider = serviceProvider;
            _hubContext = hubContext;
            _lastCheckTime = DateTime.UtcNow;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    // Создаем Scope, чтобы получить репозиторий
                    using (var scope = _serviceProvider.CreateScope())
                    {
                        var repo = scope.ServiceProvider.GetRequiredService<ICompanyRepository>();

                        // Вызываем процедуру через репозиторий
                        var updates = await repo.GetRecentPriceUpdatesAsync(_lastCheckTime);

                        foreach (var update in updates)
                        {
                            if (update.Timestamp > _lastCheckTime)
                                _lastCheckTime = update.Timestamp;

                            // Рассылка по WebSockets
                            await _hubContext.Clients.Group($"COMPANY_{update.CompanyId}")
                                .SendAsync("ReceivePriceUpdate", update);
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[MarketService Error]: {ex.Message}");
                }

                await Task.Delay(1000, stoppingToken);
            }
        }
    }
}
