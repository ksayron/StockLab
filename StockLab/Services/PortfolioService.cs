using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Models.DTOs;

namespace StockLab.Services
{
    public class PortfolioService(AppDbContext db)
    {
        public async Task<PortfolioSummaryDto> GetSummaryAsync(int userId)
        {
            if (!await db.Users.AnyAsync(u => u.Id == userId))
                throw new KeyNotFoundException("Пользователь не найден");

            var user = await db.Users.FindAsync(userId);
            var cash = user!.Balance;

            var items = await db.PortfolioItems
                .Where(p => p.UserId == userId)
                .Include(p => p.Company)
                .ToListAsync();

            decimal stocksValue = items.Sum(p => p.QuantityOwned * p.Company.CurrentPrice);

            // 24h change: compare current price vs price 24h ago
            decimal changeAbs = 0;
            var cutoff24h = DateTime.UtcNow.AddHours(-24);

            foreach (var item in items)
            {
                var oldPriceLog = await db.PriceLogs
                    .Where(pl => pl.CompanyId == item.CompanyId && pl.Timestamp <= cutoff24h)
                    .OrderByDescending(pl => pl.Timestamp)
                    .FirstOrDefaultAsync();

                decimal oldPrice = oldPriceLog?.Price ?? item.Company.CurrentPrice;
                changeAbs += item.QuantityOwned * (item.Company.CurrentPrice - oldPrice);
            }

            decimal totalEquity = cash + stocksValue;
            decimal changePct = stocksValue > 0 ? changeAbs / (totalEquity - changeAbs) * 100 : 0;

            return new PortfolioSummaryDto
            {
                CashBalance = cash,
                StocksValue = stocksValue,
                TotalEquity = totalEquity,
                ChangeAbs = changeAbs,
                ChangePercent = Math.Round(changePct, 2)
            };
        }

        public async Task<IEnumerable<PortfolioItemDto>> GetItemsAsync(int userId)
        {
            if (!await db.Users.AnyAsync(u => u.Id == userId))
                throw new KeyNotFoundException("Пользователь не найден");

            var cutoff24h = DateTime.UtcNow.AddHours(-24);

            var items = await db.PortfolioItems
                .Where(p => p.UserId == userId && p.QuantityOwned > 0)
                .Include(p => p.Company)
                .ToListAsync();

            var result = new List<PortfolioItemDto>();
            foreach (var item in items)
            {
                var oldLog = await db.PriceLogs
                    .Where(pl => pl.CompanyId == item.CompanyId && pl.Timestamp <= cutoff24h)
                    .OrderByDescending(pl => pl.Timestamp)
                    .FirstOrDefaultAsync();

                decimal oldPrice = oldLog?.Price ?? item.Company.CurrentPrice;
                decimal changeAbs = item.Company.CurrentPrice - oldPrice;
                decimal changePct = oldPrice > 0 ? changeAbs / oldPrice * 100 : 0;

                result.Add(new PortfolioItemDto
                {
                    CompanyId = item.CompanyId,
                    Ticker = item.Company.Ticker,
                    Name = item.Company.Name,
                    Quantity = item.QuantityOwned,
                    CurrentPrice = item.Company.CurrentPrice,
                    TotalValue = item.QuantityOwned * item.Company.CurrentPrice,
                    PriceChangeAbs = changeAbs,
                    PriceChangePercent = Math.Round(changePct, 2)
                });
            }

            return result;
        }
    }
}
