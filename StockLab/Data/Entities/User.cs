namespace StockLab.Data.Entities
{
    public class User
    {
        public int Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string PasswordHash { get; set; } = string.Empty;
        public decimal Balance { get; set; }
        public bool IsBanned { get; set; }
        public bool IsBot { get; set; }
        public int RoleId { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public Role Role { get; set; } = null!;
        public BotConfig? BotConfig { get; set; }
        public ICollection<Order> Orders { get; set; } = [];
        public ICollection<PortfolioItem> Portfolio { get; set; } = [];
        public ICollection<UserNotification> Notifications { get; set; } = [];
    }
}
