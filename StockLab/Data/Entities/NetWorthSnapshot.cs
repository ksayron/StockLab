namespace StockLab.Data.Entities
{
    public class NetWorthSnapshot
    {
        public int BotId { get; set; }
        public int TournamentId { get; set; }
        public decimal InitialNetWorth { get; set; }

        public User Bot { get; set; } = null!;
        public Tournament Tournament { get; set; } = null!;
    }
}
