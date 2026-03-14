using Hangfire;
using MediatR;
using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Events;
using StockLab.Models.DTOs;

namespace StockLab.Services
{
    public class CompanyService(AppDbContext db, IBackgroundJobClient jobClient)
    {
        public async Task<IEnumerable<CompanyDto>> GetCompaniesAsync(
            string? search, int? sectorId, string sortBy, string sortDir)
        {
            var query = db.Companies
                .Include(c => c.Sector)
                .Where(c => c.Status == CompanyStatus.ACTIVE)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(c => c.Name.Contains(search) || c.Ticker.Contains(search));

            if (sectorId.HasValue)
                query = query.Where(c => c.SectorId == sectorId.Value);

            query = (sortBy, sortDir) switch
            {
                ("PRICE", "DESC") => query.OrderByDescending(c => c.CurrentPrice),
                ("PRICE", _) => query.OrderBy(c => c.CurrentPrice),
                ("VOLATILITY", "DESC") => query.OrderByDescending(c => c.Volatility),
                ("VOLATILITY", _) => query.OrderBy(c => c.Volatility),
                (_, "DESC") => query.OrderByDescending(c => c.Name),
                _ => query.OrderBy(c => c.Name)
            };

            return await query.Select(c => new CompanyDto
            {
                Id = c.Id,
                Name = c.Name,
                Ticker = c.Ticker,
                CurrentPrice = c.CurrentPrice,
                SectorName = c.Sector.Name,
                Volatility = c.Volatility,
                Status = c.Status.ToString(),
                Description = c.Description
            }).ToListAsync();
        }

        public async Task<CompanyDto?> GetByIdAsync(int id)
        {
            return await db.Companies
                .Include(c => c.Sector)
                .Where(c => c.Id == id)
                .Select(c => new CompanyDto
                {
                    Id = c.Id,
                    Name = c.Name,
                    Ticker = c.Ticker,
                    CurrentPrice = c.CurrentPrice,
                    SectorName = c.Sector.Name,
                    Volatility = c.Volatility,
                    Status = c.Status.ToString(),
                    Description = c.Description
                })
                .FirstOrDefaultAsync();
        }

        public async Task<IEnumerable<PriceLogDto>> GetPriceHistoryAsync(int companyId, int hoursBack)
        {
            var cutoff = DateTime.UtcNow.AddHours(-hoursBack);
            return await db.PriceLogs
                .Where(p => p.CompanyId == companyId && p.Timestamp >= cutoff)
                .OrderBy(p => p.Timestamp)
                .Select(p => new PriceLogDto { Price = p.Price, Timestamp = p.Timestamp })
                .ToListAsync();
        }

        public async Task<int> CreateCompanyIpoAsync(CreateCompanyDto dto)
        {
            if (!await db.Sectors.AnyAsync(s => s.Id == dto.SectorId))
                throw new KeyNotFoundException("Сектор не найден");

            if (await db.Companies.AnyAsync(c => c.Name == dto.Name || c.Ticker == dto.Ticker))
                throw new InvalidOperationException("Компания с таким именем или тикером уже существует");

            var issuerRole = await db.Roles.FirstAsync(r => r.Name == "Issuer");

            var issuer = new User
            {
                Username = $"ISSUER_{dto.Ticker}",
                Email = $"issuer_{dto.Ticker.ToLower()}@stocklab.sys",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString()),
                Balance = 0,
                IsBanned = true,
                RoleId = issuerRole.Id
            };
            db.Users.Add(issuer);

            var company = new Company
            {
                Name = dto.Name,
                Ticker = dto.Ticker,
                Description = dto.Description,
                SectorId = dto.SectorId,
                CurrentPrice = dto.InitPrice,
                Volatility = dto.Volatility,
                TotalShares = dto.TotalShares
            };
            db.Companies.Add(company);
            await db.SaveChangesAsync();

            // Give issuer all shares
            db.PortfolioItems.Add(new PortfolioItem
            {
                UserId = issuer.Id,
                CompanyId = company.Id,
                QuantityOwned = dto.TotalShares
            });

            // Create IPO SELL order
            db.Orders.Add(new Order
            {
                UserId = issuer.Id,
                CompanyId = company.Id,
                Type = OrderType.SELL,
                LimitPrice = dto.InitPrice,
                OriginalQty = dto.TotalShares,
                RemainingQty = dto.TotalShares
            });

            // Log initial price
            db.PriceLogs.Add(new PriceLog { CompanyId = company.Id, Price = dto.InitPrice });

            await db.SaveChangesAsync();

            jobClient.Enqueue<Jobs.OrderMatchingJob>(j => j.MatchAsync(company.Id, CancellationToken.None));

            return company.Id;
        }

        public async Task UpdateCompanyAsync(int id, UpdateCompanyDto dto)
        {
            var company = await db.Companies.FindAsync(id)
                ?? throw new KeyNotFoundException("Компания не найдена");

            if (!await db.Sectors.AnyAsync(s => s.Id == dto.SectorId))
                throw new KeyNotFoundException("Сектор не найден");

            company.SectorId = dto.SectorId;
            company.Name = dto.Name;
            company.Description = dto.Description;
            company.Volatility = dto.Volatility;
            await db.SaveChangesAsync();
        }

        public async Task DelistCompanyAsync(int id)
        {
            var company = await db.Companies.FindAsync(id)
                ?? throw new KeyNotFoundException("Компания не найдена");

            company.Status = CompanyStatus.DELISTED;
            company.CurrentPrice = 0;

            // Cancel all open orders
            var openOrders = await db.Orders
                .Where(o => o.CompanyId == id && (o.Status == OrderStatus.OPEN || o.Status == OrderStatus.PARTIAL))
                .ToListAsync();

            foreach (var order in openOrders)
            {
                order.Status = OrderStatus.CANCELLED;
                order.RemainingQty = 0;
            }

            await db.SaveChangesAsync();
        }
    }
}
