using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Services;

namespace StockLab.Jobs
{
    public class OrderMatchingJob(OrderMatchingService matchingService, AppDbContext db)
    {
        /// <summary>Triggered by OrderPlacedEvent for a specific company.</summary>
        public async Task MatchAsync(int companyId, CancellationToken cancellationToken)
        {
            await matchingService.MatchOrdersAsync(companyId);
        }

        /// <summary>Recurring fallback: matches all companies with open orders.</summary>
        public async Task MatchAllAsync()
        {
            var activeCompanyIds = await db.Orders
                .Where(o => o.Status == OrderStatus.OPEN || o.Status == OrderStatus.PARTIAL)
                .Select(o => o.CompanyId)
                .Distinct()
                .ToListAsync();

            foreach (var companyId in activeCompanyIds)
                await matchingService.MatchOrdersAsync(companyId);
        }
    }
}
