using Microsoft.EntityFrameworkCore;
using StockLab.Data.Entities;

namespace StockLab.Data
{
    public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
    {
        public DbSet<Role> Roles => Set<Role>();
        public DbSet<User> Users => Set<User>();
        public DbSet<Sector> Sectors => Set<Sector>();
        public DbSet<Company> Companies => Set<Company>();
        public DbSet<PriceLog> PriceLogs => Set<PriceLog>();
        public DbSet<Order> Orders => Set<Order>();
        public DbSet<Trade> Trades => Set<Trade>();
        public DbSet<PortfolioItem> PortfolioItems => Set<PortfolioItem>();
        public DbSet<BotConfig> BotConfigs => Set<BotConfig>();
        public DbSet<Tournament> Tournaments => Set<Tournament>();
        public DbSet<NetWorthSnapshot> NetWorthSnapshots => Set<NetWorthSnapshot>();
        public DbSet<TournamentHistory> TournamentHistories => Set<TournamentHistory>();
        public DbSet<Notification> Notifications => Set<Notification>();
        public DbSet<UserNotification> UserNotifications => Set<UserNotification>();
        public DbSet<SystemLog> SystemLogs => Set<SystemLog>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // ─── Role ───
            modelBuilder.Entity<Role>(e =>
            {
                e.HasKey(r => r.Id);
                e.HasIndex(r => r.Name).IsUnique();
                e.Property(r => r.Name).HasMaxLength(50);
            });

            // ─── User ───
            modelBuilder.Entity<User>(e =>
            {
                e.HasKey(u => u.Id);
                e.HasIndex(u => u.Username).IsUnique();
                e.Property(u => u.Username).HasMaxLength(100);
                e.Property(u => u.Email).HasMaxLength(200);
                e.Property(u => u.Balance).HasPrecision(18, 2);
                e.HasOne(u => u.Role).WithMany(r => r.Users).HasForeignKey(u => u.RoleId);
            });

            // ─── Sector ───
            modelBuilder.Entity<Sector>(e =>
            {
                e.HasKey(s => s.Id);
                e.Property(s => s.Name).HasMaxLength(100);
                e.Property(s => s.Buff).HasPrecision(5, 2);
            });

            // ─── Company ───
            modelBuilder.Entity<Company>(e =>
            {
                e.HasKey(c => c.Id);
                e.HasIndex(c => c.Ticker).IsUnique();
                e.Property(c => c.Ticker).HasMaxLength(10);
                e.Property(c => c.Name).HasMaxLength(200);
                e.Property(c => c.CurrentPrice).HasPrecision(18, 4);
                e.Property(c => c.Volatility).HasPrecision(5, 4);
                e.Property(c => c.Status).HasConversion<string>();
                e.HasOne(c => c.Sector).WithMany(s => s.Companies).HasForeignKey(c => c.SectorId);
            });

            // ─── PriceLog ───
            modelBuilder.Entity<PriceLog>(e =>
            {
                e.HasKey(p => p.Id);
                e.HasIndex(p => new { p.CompanyId, p.Timestamp });
                e.Property(p => p.Price).HasPrecision(18, 4);
                e.HasOne(p => p.Company).WithMany(c => c.PriceLogs).HasForeignKey(p => p.CompanyId);
            });

            // ─── Order ───
            modelBuilder.Entity<Order>(e =>
            {
                e.HasKey(o => o.Id);
                e.HasIndex(o => new { o.CompanyId, o.Status });
                e.Property(o => o.Type).HasConversion<string>();
                e.Property(o => o.Status).HasConversion<string>();
                e.Property(o => o.LimitPrice).HasPrecision(18, 4);
                e.HasOne(o => o.User).WithMany(u => u.Orders).HasForeignKey(o => o.UserId);
                e.HasOne(o => o.Company).WithMany(c => c.Orders).HasForeignKey(o => o.CompanyId);
            });

            // ─── Trade ───
            modelBuilder.Entity<Trade>(e =>
            {
                e.HasKey(t => t.Id);
                e.Property(t => t.Price).HasPrecision(18, 4);
                e.HasOne(t => t.BuyOrder).WithMany(o => o.BuyTrades)
                    .HasForeignKey(t => t.BuyOrderId).OnDelete(DeleteBehavior.Restrict);
                e.HasOne(t => t.SellOrder).WithMany(o => o.SellTrades)
                    .HasForeignKey(t => t.SellOrderId).OnDelete(DeleteBehavior.Restrict);
            });

            // ─── PortfolioItem ───
            modelBuilder.Entity<PortfolioItem>(e =>
            {
                e.HasKey(p => new { p.UserId, p.CompanyId });
                e.HasOne(p => p.User).WithMany(u => u.Portfolio).HasForeignKey(p => p.UserId);
                e.HasOne(p => p.Company).WithMany(c => c.PortfolioItems).HasForeignKey(p => p.CompanyId);
            });

            // ─── BotConfig ───
            modelBuilder.Entity<BotConfig>(e =>
            {
                e.HasKey(b => b.UserId);
                e.Property(b => b.GreedFactor).HasPrecision(5, 2);
                e.Property(b => b.PanicLevel).HasPrecision(5, 2);
                e.Property(b => b.BetSize).HasPrecision(5, 2);
                e.HasOne(b => b.User).WithOne(u => u.BotConfig)
                    .HasForeignKey<BotConfig>(b => b.UserId);
            });

            // ─── Tournament ───
            modelBuilder.Entity<Tournament>(e =>
            {
                e.HasKey(t => t.Id);
                e.Property(t => t.Status).HasConversion<int>();
            });

            // ─── NetWorthSnapshot ───
            modelBuilder.Entity<NetWorthSnapshot>(e =>
            {
                e.HasKey(n => new { n.BotId, n.TournamentId });
                e.Property(n => n.InitialNetWorth).HasPrecision(18, 2);
                e.HasOne(n => n.Bot).WithMany().HasForeignKey(n => n.BotId)
                    .OnDelete(DeleteBehavior.Cascade);
                e.HasOne(n => n.Tournament).WithMany(t => t.NetWorthSnapshots)
                    .HasForeignKey(n => n.TournamentId);
            });

            // ─── TournamentHistory ───
            modelBuilder.Entity<TournamentHistory>(e =>
            {
                e.HasKey(h => new { h.BotId, h.TournamentId });
                e.Property(h => h.Roi).HasPrecision(10, 4);
                e.Property(h => h.Tier).HasMaxLength(20);
                e.HasOne(h => h.Bot).WithMany().HasForeignKey(h => h.BotId)
                    .OnDelete(DeleteBehavior.Cascade);
                e.HasOne(h => h.Tournament).WithMany(t => t.History)
                    .HasForeignKey(h => h.TournamentId);
            });

            // ─── Notification ───
            modelBuilder.Entity<Notification>(e =>
            {
                e.HasKey(n => n.Id);
                e.Property(n => n.Type).HasConversion<string>();
                e.Property(n => n.Title).HasMaxLength(200);
            });

            // ─── UserNotification ───
            modelBuilder.Entity<UserNotification>(e =>
            {
                e.HasKey(un => un.Id);
                e.HasIndex(un => new { un.UserId, un.IsRead });
                e.HasOne(un => un.User).WithMany(u => u.Notifications).HasForeignKey(un => un.UserId);
                e.HasOne(un => un.Notification).WithMany(n => n.UserNotifications)
                    .HasForeignKey(un => un.NotificationId);
            });

            // ─── Seed data ───
            modelBuilder.Entity<Role>().HasData(
                new Role { Id = 1, Name = "Admin" },
                new Role { Id = 2, Name = "User" },
                new Role { Id = 3, Name = "Bot" },
                new Role { Id = 4, Name = "Issuer" }
            );

            // Default admin: admin / admin123
            modelBuilder.Entity<User>().HasData(new User
            {
                Id = 1,
                Username = "admin",
                Email = "admin@stocklab.local",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123"),
                Balance = 0,
                IsBanned = false,
                IsBot = false,
                RoleId = 1,
                CreatedAt = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc)
            });
        }
    }
}
