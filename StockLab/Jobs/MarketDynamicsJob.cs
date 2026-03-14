using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;

namespace StockLab.Jobs
{
    public class MarketDynamicsJob(AppDbContext db)
    {
        public async Task ExecuteAsync()
        {
            var now = DateTime.UtcNow;
            var oneMinuteAgo = now.AddMinutes(-1);
            var fifteenMinutesAgo = now.AddMinutes(-15);

            var activeCompanies = await db.Companies
                .Where(c => c.Status == CompanyStatus.ACTIVE)
                .ToListAsync();

            foreach (var company in activeCompanies)
            {
                // Overheat: 15+ trades in last minute → reduce volatility 5%
                int recentTrades = await db.Trades
                    .Where(t => t.BuyOrder.CompanyId == company.Id && t.ExecutedAt >= oneMinuteAgo)
                    .CountAsync();

                if (recentTrades >= 15)
                {
                    company.Volatility = Math.Max(0.01m, company.Volatility * 0.95m);
                    continue;
                }

                // Stagnation: no trades in last 15 min → increase volatility 10%
                bool hasRecentTrade = company.LastTradeAt.HasValue
                    && company.LastTradeAt.Value >= fifteenMinutesAgo;

                if (!hasRecentTrade && company.Volatility < 0.50m)
                {
                    company.Volatility = Math.Min(0.50m, company.Volatility * 1.10m);
                }
            }

            await db.SaveChangesAsync();
        }
    }
}
