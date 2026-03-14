using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Models.DTOs;
using StockLab.Services;

namespace StockLab.Jobs
{
    public class BotTradingJob(AppDbContext db, BotService botService, TradingService tradingService)
    {
        private static readonly Random Rng = new();

        public async Task ExecuteAsync()
        {
            var status = await botService.GetTournamentStatusAsync();
            if (status != "ACTIVE") return;

            // Pick random active bot
            var botIds = await db.Users
                .Where(u => u.IsBot && !u.IsBanned)
                .Select(u => u.Id)
                .ToListAsync();

            if (!botIds.Any()) return;

            int botId = botIds[Rng.Next(botIds.Count)];
            var bot = await db.Users
                .Include(u => u.BotConfig)
                .Include(u => u.Portfolio).ThenInclude(p => p.Company)
                .FirstOrDefaultAsync(u => u.Id == botId);

            if (bot?.BotConfig == null) return;

            // Pick random active company
            var companies = await db.Companies
                .Where(c => c.Status == CompanyStatus.ACTIVE)
                .ToListAsync();

            if (!companies.Any()) return;

            var company = companies[Rng.Next(companies.Count)];
            var holding = bot.Portfolio.FirstOrDefault(p => p.CompanyId == company.Id);

            // Determine action
            string action;
            if (holding == null || holding.QuantityOwned == 0)
                action = "BUY";
            else if (bot.Balance < 500)
                action = "SELL";
            else
                action = Rng.Next(2) == 0 ? "BUY" : "SELL";

            // Dynamic price: currentPrice * (1 + volatility * direction)
            double direction = Rng.NextDouble() * 2 - 1; // -1 to 1
            decimal tradePrice = company.CurrentPrice * (1 + (decimal)(company.Volatility * (decimal)direction));
            tradePrice = Math.Max(0.01m, Math.Round(tradePrice, 4));

            try
            {
                if (action == "BUY")
                {
                    decimal spendFraction = (decimal)(Rng.NextDouble() * 0.25 + 0.05);
                    decimal spendAmount = bot.Balance * spendFraction;
                    int qty = (int)(spendAmount / tradePrice);
                    if (qty < 1) return;

                    await tradingService.PlaceOrderAsync(botId, new PlaceOrderDto
                    {
                        CompanyId = company.Id,
                        Type = "BUY",
                        Quantity = qty,
                        LimitPrice = tradePrice
                    });
                }
                else if (holding != null && holding.QuantityOwned > 0)
                {
                    double sellFraction = Rng.NextDouble() * 0.9 + 0.1;
                    int qty = Math.Max(1, (int)(holding.QuantityOwned * sellFraction));

                    await tradingService.PlaceOrderAsync(botId, new PlaceOrderDto
                    {
                        CompanyId = company.Id,
                        Type = "SELL",
                        Quantity = qty,
                        LimitPrice = tradePrice
                    });
                }
            }
            catch
            {
                // Bots can fail silently (insufficient funds, etc.)
            }
        }
    }
}
