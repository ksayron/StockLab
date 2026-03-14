using Hangfire;
using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Models.DTOs;

namespace StockLab.Services
{
    public class BotService(AppDbContext db, IBackgroundJobClient jobClient)
    {
        private static readonly Random Rng = new();

        public async Task GenerateSeasonAsync(int botCount)
        {
            // Hard reset: remove existing bot data
            var botUserIds = await db.Users.Where(u => u.IsBot).Select(u => u.Id).ToListAsync();

            if (botUserIds.Count > 0)
            {
                await db.Orders
                    .Where(o => botUserIds.Contains(o.UserId))
                    .ExecuteDeleteAsync();

                await db.PortfolioItems
                    .Where(p => botUserIds.Contains(p.UserId))
                    .ExecuteDeleteAsync();

                await db.BotConfigs.Where(b => botUserIds.Contains(b.UserId)).ExecuteDeleteAsync();
                await db.Users.Where(u => u.IsBot).ExecuteDeleteAsync();
            }

            // Remove previous tournament
            var oldTournaments = db.Tournaments.Include(t => t.NetWorthSnapshots).Include(t => t.History);
            db.Tournaments.RemoveRange(oldTournaments);

            // Create bot companies
            var botCompanyTickers = new[] { "BOT1", "BOT2", "BOT3", "BOT4", "BOT5" };
            var botSector = await db.Sectors.FirstOrDefaultAsync()
                ?? throw new InvalidOperationException("Нет секторов для создания компаний ботов");

            var issuerRole = await db.Roles.FirstAsync(r => r.Name == "Issuer");
            var botRole = await db.Roles.FirstAsync(r => r.Name == "Bot");

            foreach (var ticker in botCompanyTickers)
            {
                if (await db.Companies.AnyAsync(c => c.Ticker == ticker)) continue;

                decimal initPrice = (decimal)(Rng.NextDouble() * 980 + 20);
                decimal volatility = (decimal)(Rng.NextDouble() * 0.25 + 0.05);
                int shares = 1000;

                var issuer = new User
                {
                    Username = $"ISSUER_{ticker}",
                    Email = $"issuer_{ticker.ToLower()}@stocklab.sys",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString()),
                    Balance = 0,
                    IsBanned = true,
                    RoleId = issuerRole.Id
                };
                db.Users.Add(issuer);

                var company = new Company
                {
                    Name = $"Bot Company {ticker}",
                    Ticker = ticker,
                    SectorId = botSector.Id,
                    CurrentPrice = initPrice,
                    Volatility = volatility,
                    TotalShares = shares
                };
                db.Companies.Add(company);
                await db.SaveChangesAsync();

                db.PortfolioItems.Add(new PortfolioItem { UserId = issuer.Id, CompanyId = company.Id, QuantityOwned = shares });
                db.Orders.Add(new Order
                {
                    UserId = issuer.Id,
                    CompanyId = company.Id,
                    Type = OrderType.SELL,
                    LimitPrice = initPrice,
                    OriginalQty = shares,
                    RemainingQty = shares
                });
                db.PriceLogs.Add(new PriceLog { CompanyId = company.Id, Price = initPrice });
            }

            // Generate bots
            for (int i = 0; i < botCount; i++)
            {
                decimal balance = (decimal)(Rng.NextDouble() * 95_000 + 5_000);
                var bot = new User
                {
                    Username = $"Bot_{i + 1}_{Rng.Next(1000, 9999)}",
                    Email = $"bot{i + 1}@stocklab.bot",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString()),
                    Balance = balance,
                    IsBot = true,
                    RoleId = botRole.Id
                };
                db.Users.Add(bot);
                await db.SaveChangesAsync();

                db.BotConfigs.Add(new BotConfig
                {
                    UserId = bot.Id,
                    GreedFactor = (decimal)(Rng.NextDouble() * 0.9 + 0.1),
                    PanicLevel = (decimal)(Rng.NextDouble() * 0.9 + 0.1),
                    MemorySpan = Rng.Next(1, 20),
                    BetSize = (decimal)(Rng.NextDouble() * 0.25 + 0.05)
                });
            }

            // Create tournament
            db.Tournaments.Add(new Tournament { Status = TournamentStatus.PLANNED });
            await db.SaveChangesAsync();
        }

        public async Task StartTournamentAsync()
        {
            var tournament = await db.Tournaments.OrderByDescending(t => t.Id).FirstOrDefaultAsync()
                ?? throw new InvalidOperationException("Нет активного турнира");

            if (tournament.Status == TournamentStatus.ACTIVE)
                throw new InvalidOperationException("Турнир уже запущен");

            if (tournament.Status == TournamentStatus.PLANNED)
            {
                // Record initial net worth snapshots
                var bots = await db.Users
                    .Where(u => u.IsBot)
                    .Include(u => u.Portfolio).ThenInclude(p => p.Company)
                    .ToListAsync();

                foreach (var bot in bots)
                {
                    decimal worth = bot.Balance + bot.Portfolio.Sum(p => p.QuantityOwned * p.Company.CurrentPrice);
                    db.NetWorthSnapshots.Add(new NetWorthSnapshot
                    {
                        BotId = bot.Id,
                        TournamentId = tournament.Id,
                        InitialNetWorth = worth
                    });
                }
                tournament.StartedAt = DateTime.UtcNow;
            }

            tournament.Status = TournamentStatus.ACTIVE;
            await db.SaveChangesAsync();
        }

        public async Task PauseTournamentAsync()
        {
            var tournament = await db.Tournaments.OrderByDescending(t => t.Id).FirstOrDefaultAsync()
                ?? throw new InvalidOperationException("Нет активного турнира");

            if (tournament.Status != TournamentStatus.ACTIVE)
                throw new InvalidOperationException("Турнир не активен");

            tournament.Status = TournamentStatus.PAUSED;
            await db.SaveChangesAsync();
        }

        public async Task FinalizeTournamentAsync()
        {
            var tournament = await db.Tournaments.OrderByDescending(t => t.Id).FirstOrDefaultAsync()
                ?? throw new InvalidOperationException("Нет активного турнира");

            var snapshots = await db.NetWorthSnapshots
                .Where(n => n.TournamentId == tournament.Id)
                .ToListAsync();

            var bots = await db.Users
                .Where(u => u.IsBot)
                .Include(u => u.Portfolio).ThenInclude(p => p.Company)
                .ToListAsync();

            var botResults = bots.Select(b =>
            {
                var snapshot = snapshots.FirstOrDefault(s => s.BotId == b.Id);
                decimal initialWorth = snapshot?.InitialNetWorth ?? 1m;
                decimal currentWorth = b.Balance + b.Portfolio.Sum(p => p.QuantityOwned * p.Company.CurrentPrice);
                decimal roi = initialWorth > 0 ? (currentWorth - initialWorth) / initialWorth * 100 : 0;
                return new { BotId = b.Id, Roi = roi };
            })
            .OrderByDescending(x => x.Roi)
            .ToList();

            for (int i = 0; i < botResults.Count; i++)
            {
                int rank = i + 1;
                decimal roi = botResults[i].Roi;
                string tier = rank <= botResults.Count * 0.1 ? "GOLD"
                    : rank <= botResults.Count * 0.3 ? "SILVER"
                    : "BRONZE";

                db.TournamentHistories.Add(new TournamentHistory
                {
                    BotId = botResults[i].BotId,
                    TournamentId = tournament.Id,
                    Roi = roi,
                    Rank = rank,
                    Tier = tier
                });
            }

            tournament.Status = TournamentStatus.FINISHED;
            tournament.FinishedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
        }

        public async Task<string> GetTournamentStatusAsync()
        {
            var tournament = await db.Tournaments.OrderByDescending(t => t.Id).FirstOrDefaultAsync();
            return tournament?.Status.ToString() ?? "PLANNED";
        }

        public async Task<IEnumerable<BotSummaryDto>> GetAllBotsAsync()
        {
            var tournament = await db.Tournaments.OrderByDescending(t => t.Id).FirstOrDefaultAsync();
            var snapshots = tournament != null
                ? await db.NetWorthSnapshots.Where(n => n.TournamentId == tournament.Id).ToListAsync()
                : [];

            return await db.Users
                .Where(u => u.IsBot)
                .Include(u => u.BotConfig)
                .Include(u => u.Portfolio).ThenInclude(p => p.Company)
                .Select(u => new BotSummaryDto
                {
                    UserId = u.Id,
                    Username = u.Username,
                    NetWorth = u.Balance + u.Portfolio.Sum(p => p.QuantityOwned * p.Company.CurrentPrice),
                    GreedFactor = u.BotConfig != null ? u.BotConfig.GreedFactor : 0,
                    PanicLevel = u.BotConfig != null ? u.BotConfig.PanicLevel : 0,
                    MemorySpan = u.BotConfig != null ? u.BotConfig.MemorySpan : 0,
                    BetSize = u.BotConfig != null ? u.BotConfig.BetSize : 0,
                    CurrentRank = 0,
                    LastRank = null
                })
                .ToListAsync();
        }

        public async Task<BotDetailDto?> GetBotDetailsAsync(int botId)
        {
            var bot = await db.Users
                .Where(u => u.Id == botId && u.IsBot)
                .Include(u => u.BotConfig)
                .Include(u => u.Portfolio).ThenInclude(p => p.Company)
                .FirstOrDefaultAsync();

            if (bot == null) return null;

            decimal netWorth = bot.Balance + bot.Portfolio.Sum(p => p.QuantityOwned * p.Company.CurrentPrice);

            var history = await db.TournamentHistories
                .Where(h => h.BotId == botId)
                .ToListAsync();

            decimal avgRoi = history.Count > 0 ? history.Average(h => h.Roi) : 0;

            return new BotDetailDto
            {
                UserId = bot.Id,
                Username = bot.Username,
                NetWorth = netWorth,
                CashBalance = bot.Balance,
                GreedFactor = bot.BotConfig?.GreedFactor ?? 0,
                PanicLevel = bot.BotConfig?.PanicLevel ?? 0,
                MemorySpan = bot.BotConfig?.MemorySpan ?? 0,
                BetSize = bot.BotConfig?.BetSize ?? 0,
                CurrentRank = 0,
                LastRank = null,
                TotalGamesPlayed = history.Count,
                AverageRoi = avgRoi
            };
        }
    }
}
