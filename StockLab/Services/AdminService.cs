using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Models.DTOs;
using System.Text.Json;

namespace StockLab.Services
{
    public class AdminService(AppDbContext db)
    {
        public async Task BanUserAsync(int adminId, int targetUserId, bool ban)
        {
            if (adminId == targetUserId)
                throw new InvalidOperationException("Нельзя заблокировать себя");

            var user = await db.Users.FindAsync(targetUserId)
                ?? throw new KeyNotFoundException("Пользователь не найден");

            user.IsBanned = ban;
            await db.SaveChangesAsync();
        }

        public async Task CreateNewAdminAsync(string username, string plainPassword)
        {
            if (await db.Users.AnyAsync(u => u.Username == username))
                throw new InvalidOperationException("Имя пользователя уже занято");

            var adminRole = await db.Roles.FirstAsync(r => r.Name == "Admin");
            db.Users.Add(new User
            {
                Username = username,
                Email = $"{username}@stocklab.admin",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(plainPassword),
                Balance = 0,
                RoleId = adminRole.Id
            });
            await db.SaveChangesAsync();
        }

        public async Task AdjustBalanceAsync(int userId, decimal newBalance)
        {
            var user = await db.Users.FindAsync(userId)
                ?? throw new KeyNotFoundException("Пользователь не найден");

            user.Balance = newBalance;
            await db.SaveChangesAsync();
        }

        public async Task<AdminUserDetailDto?> GetUserDetailsAsync(int userId)
        {
            return await db.Users
                .Include(u => u.Role)
                .Where(u => u.Id == userId)
                .Select(u => new AdminUserDetailDto
                {
                    UserId = u.Id,
                    Username = u.Username,
                    Email = u.Email,
                    Balance = u.Balance,
                    IsBanned = u.IsBanned,
                    RoleName = u.Role.Name,
                    CreatedAt = u.CreatedAt,
                    TotalOrders = u.Orders.Count,
                    TotalTrades = u.Orders.SelectMany(o => o.BuyTrades).Count()
                        + u.Orders.SelectMany(o => o.SellTrades).Count()
                })
                .FirstOrDefaultAsync();
        }

        public async Task<IEnumerable<AdminUserDetailDto>> GetAllUsersAsync()
        {
            return await db.Users
                .Include(u => u.Role)
                .Where(u => !u.IsBot)
                .Select(u => new AdminUserDetailDto
                {
                    UserId = u.Id,
                    Username = u.Username,
                    Email = u.Email,
                    Balance = u.Balance,
                    IsBanned = u.IsBanned,
                    RoleName = u.Role.Name,
                    CreatedAt = u.CreatedAt,
                    TotalOrders = u.Orders.Count,
                    TotalTrades = 0
                })
                .ToListAsync();
        }

        public async Task<IEnumerable<AdminOrderViewDto>> GetCompanyOrdersAsync(int companyId)
        {
            return await db.Orders
                .Where(o => o.CompanyId == companyId)
                .Include(o => o.User)
                .OrderByDescending(o => o.CreatedAt)
                .Select(o => new AdminOrderViewDto
                {
                    OrderId = o.Id,
                    Username = o.User.Username,
                    Type = o.Type.ToString(),
                    Status = o.Status.ToString(),
                    Price = o.LimitPrice,
                    Qty = o.OriginalQty,
                    CreatedAt = o.CreatedAt
                })
                .ToListAsync();
        }

        public async Task<IEnumerable<AdminTradeViewDto>> GetCompanyTradesAsync(int companyId)
        {
            return await db.Trades
                .Where(t => t.BuyOrder.CompanyId == companyId)
                .Include(t => t.BuyOrder).ThenInclude(o => o.User)
                .Include(t => t.SellOrder).ThenInclude(o => o.User)
                .OrderByDescending(t => t.ExecutedAt)
                .Select(t => new AdminTradeViewDto
                {
                    TradeId = t.Id,
                    Buyer = t.BuyOrder.User.Username,
                    Seller = t.SellOrder.User.Username,
                    Price = t.Price,
                    Qty = t.Quantity,
                    ExecutedAt = t.ExecutedAt
                })
                .ToListAsync();
        }

        public async Task<IEnumerable<SystemLogDto>> GetSystemLogsAsync(int? minutesBack)
        {
            var query = db.SystemLogs.AsQueryable();
            if (minutesBack.HasValue)
            {
                var cutoff = DateTime.UtcNow.AddMinutes(-minutesBack.Value);
                query = query.Where(l => l.CreatedAt >= cutoff);
            }
            return await query
                .OrderByDescending(l => l.CreatedAt)
                .Take(1000)
                .Select(l => new SystemLogDto
                {
                    LogId = l.Id,
                    ProcName = l.ProcName,
                    UserId = l.UserId,
                    ErrorCode = l.ErrorCode,
                    ErrorMsg = l.ErrorMsg,
                    CreatedAt = l.CreatedAt
                })
                .ToListAsync();
        }

        public async Task<string> ExportDatabaseJsonAsync()
        {
            var data = new
            {
                sectors = await db.Sectors.ToListAsync(),
                companies = await db.Companies.ToListAsync(),
                users = await db.Users.Include(u => u.Role)
                    .Where(u => !u.IsBot && u.Role.Name != "Issuer")
                    .Select(u => new { u.Id, u.Username, u.Email, u.Balance, u.IsBanned, Role = u.Role.Name })
                    .ToListAsync(),
                exportedAt = DateTime.UtcNow
            };
            return JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
        }

        public async Task ImportDatabaseJsonAsync(string jsonContent)
        {
            // Basic import: parse sectors from JSON and upsert
            using var doc = JsonDocument.Parse(jsonContent);
            var root = doc.RootElement;

            if (root.TryGetProperty("sectors", out var sectorsEl))
            {
                foreach (var s in sectorsEl.EnumerateArray())
                {
                    string name = s.GetProperty("name").GetString() ?? "";
                    string? desc = s.TryGetProperty("description", out var d) ? d.GetString() : null;
                    if (!await db.Sectors.AnyAsync(sec => sec.Name == name))
                        db.Sectors.Add(new Sector { Name = name, Description = desc });
                }
                await db.SaveChangesAsync();
            }
        }
    }
}
