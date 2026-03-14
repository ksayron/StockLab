using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Models.DTOs;

namespace StockLab.Services
{
    public class AnalyticsService(AppDbContext db)
    {
        public async Task<IEnumerable<WindroseDto>> GetWindroseDataAsync()
        {
            var tournament = await db.Tournaments
                .Where(t => t.Status == TournamentStatus.ACTIVE || t.Status == TournamentStatus.FINISHED)
                .OrderByDescending(t => t.Id)
                .FirstOrDefaultAsync();

            if (tournament == null) return [];

            var snapshots = await db.NetWorthSnapshots
                .Where(n => n.TournamentId == tournament.Id)
                .ToListAsync();

            var bots = await db.Users
                .Where(u => u.IsBot)
                .Include(u => u.BotConfig)
                .Include(u => u.Portfolio).ThenInclude(p => p.Company)
                .ToListAsync();

            var botData = bots
                .Where(b => b.BotConfig != null)
                .Select(b =>
                {
                    var snapshot = snapshots.FirstOrDefault(s => s.BotId == b.Id);
                    decimal initialWorth = snapshot?.InitialNetWorth ?? 1m;
                    decimal currentWorth = b.Balance + b.Portfolio.Sum(p => p.QuantityOwned * p.Company.CurrentPrice);
                    decimal roi = initialWorth > 0 ? (currentWorth - initialWorth) / initialWorth * 100 : 0;
                    return new { BotConfig = b.BotConfig!, Roi = roi };
                })
                .OrderBy(x => x.Roi)
                .ToList();

            if (!botData.Any()) return [];

            int count = botData.Count;
            int top10pct = Math.Max(1, count / 10);
            int bottom10pct = Math.Max(1, count / 10);

            var groups = new[]
            {
                new { Label = "Top 10%", Items = botData.TakeLast(top10pct).ToList() },
                new { Label = "Average", Items = botData.Skip(bottom10pct).Take(count - bottom10pct - top10pct).ToList() },
                new { Label = "Bottom 10%", Items = botData.Take(bottom10pct).ToList() }
            };

            return groups.Where(g => g.Items.Count > 0).Select(g => new WindroseDto
            {
                Category = g.Label,
                AvgGreed = g.Items.Average(x => (double)x.BotConfig.GreedFactor),
                AvgPanic = g.Items.Average(x => (double)x.BotConfig.PanicLevel),
                AvgMemory = g.Items.Average(x => x.BotConfig.MemorySpan),
                AvgBetSize = g.Items.Average(x => (double)x.BotConfig.BetSize),
                AvgRoi = g.Items.Average(x => (double)x.Roi)
            });
        }

        public async Task<IEnumerable<HeatmapDto>> GetMarketHeatmapAsync()
        {
            var cutoff = DateTime.UtcNow.AddHours(-24);

            var companies = await db.Companies
                .Include(c => c.Sector)
                .Where(c => c.Status == CompanyStatus.ACTIVE)
                .ToListAsync();

            var result = new List<HeatmapDto>();

            foreach (var company in companies)
            {
                var oldLog = await db.PriceLogs
                    .Where(p => p.CompanyId == company.Id && p.Timestamp <= cutoff)
                    .OrderByDescending(p => p.Timestamp)
                    .FirstOrDefaultAsync();

                decimal oldPrice = oldLog?.Price ?? company.CurrentPrice;
                decimal changePercent = oldPrice > 0
                    ? (company.CurrentPrice - oldPrice) / oldPrice * 100
                    : 0;

                result.Add(new HeatmapDto
                {
                    CompanyId = company.Id,
                    CompanyName = company.Name,
                    Ticker = company.Ticker,
                    SectorName = company.Sector.Name,
                    ChangePercent = Math.Round(changePercent, 2),
                    Sentiment = changePercent >= 0 ? "BULLISH" : "BEARISH"
                });
            }

            return result;
        }

        public async Task<IEnumerable<TopActiveDto>> GetTopActiveCompaniesAsync()
        {
            var cutoff = DateTime.UtcNow.AddHours(-24);

            return await db.Trades
                .Where(t => t.ExecutedAt >= cutoff)
                .GroupBy(t => t.BuyOrder.CompanyId)
                .Select(g => new
                {
                    CompanyId = g.Key,
                    TradeCount = g.Count(),
                    Volume = g.Sum(t => t.Quantity)
                })
                .OrderByDescending(x => x.TradeCount)
                .Take(5)
                .Join(db.Companies.Include(c => c.Sector),
                    x => x.CompanyId,
                    c => c.Id,
                    (x, c) => new TopActiveDto
                    {
                        CompanyId = c.Id,
                        CompanyName = c.Name,
                        Ticker = c.Ticker,
                        SectorName = c.Sector.Name,
                        CurrentPrice = c.CurrentPrice,
                        TradeCount = x.TradeCount,
                        Volume = x.Volume
                    })
                .ToListAsync();
        }
    }
}
