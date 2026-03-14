using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Models.DTOs;

namespace StockLab.Services
{
    public class UserService(AppDbContext db)
    {
        public async Task<AuthResult> AuthenticateAsync(string username, string plainPassword)
        {
            var user = await db.Users
                .Include(u => u.Role)
                .FirstOrDefaultAsync(u => u.Username == username);

            if (user == null || !BCrypt.Net.BCrypt.Verify(plainPassword, user.PasswordHash))
                throw new UnauthorizedAccessException("Неподходящие логин и пароль");

            if (user.IsBanned)
                throw new UnauthorizedAccessException("Пользователь заблокирован");

            return new AuthResult { UserId = user.Id, RoleName = user.Role.Name, IsBanned = user.IsBanned };
        }

        public async Task RegisterAsync(string username, string email, string plainPassword)
        {
            if (username.StartsWith("ISSUER_", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Зарезервированный префикс имени пользователя");

            if (username.Length < 3 || username.Length > 50)
                throw new InvalidOperationException("Имя пользователя должно быть от 3 до 50 символов");

            if (await db.Users.AnyAsync(u => u.Username == username))
                throw new InvalidOperationException("Имя пользователя уже занято");

            var userRole = await db.Roles.FirstAsync(r => r.Name == "User");
            db.Users.Add(new User
            {
                Username = username,
                Email = email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(plainPassword),
                Balance = 25_000m,
                RoleId = userRole.Id
            });
            await db.SaveChangesAsync();
        }

        public async Task<UserProfileDto> GetUserProfileAsync(int userId)
        {
            var user = await db.Users
                .Include(u => u.Role)
                .FirstOrDefaultAsync(u => u.Id == userId)
                ?? throw new KeyNotFoundException("Пользователь не найден");

            return new UserProfileDto
            {
                UserId = user.Id,
                Username = user.Username,
                Email = user.Email,
                Balance = user.Balance,
                RoleName = user.Role.Name,
                CreatedAt = user.CreatedAt
            };
        }

        public async Task DepositCashAsync(int userId, decimal amount)
        {
            if (amount <= 0)
                throw new InvalidOperationException("Нельзя начислять негативные суммы");

            var user = await db.Users.FindAsync(userId)
                ?? throw new KeyNotFoundException("Пользователь не найден");

            user.Balance += amount;
            await db.SaveChangesAsync();
        }
    }
}
