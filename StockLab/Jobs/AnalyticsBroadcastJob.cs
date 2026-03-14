using Microsoft.AspNetCore.SignalR;
using StockLab.Hubs;
using StockLab.Services;

namespace StockLab.Jobs
{
    public class AnalyticsBroadcastJob(
        AnalyticsService analyticsService,
        BotService botService,
        IHubContext<DashboardHub> dashboardHub)
    {
        public async Task ExecuteAsync()
        {
            var status = await botService.GetTournamentStatusAsync();
            if (status != "ACTIVE") return;

            var windrose = analyticsService.GetWindroseDataAsync();
            var heatmap = analyticsService.GetMarketHeatmapAsync();
            var top5 = analyticsService.GetTopActiveCompaniesAsync();

            await Task.WhenAll(windrose, heatmap, top5);

            // Windrose + heatmap → admins only
            await dashboardHub.Clients.Group("Admins").SendAsync("ReceiveWindrose", windrose.Result);
            await dashboardHub.Clients.Group("Admins").SendAsync("ReceiveHeatmap", heatmap.Result);

            // Top5 → everyone
            await dashboardHub.Clients.All.SendAsync("ReceiveTop5", top5.Result);
        }
    }
}
