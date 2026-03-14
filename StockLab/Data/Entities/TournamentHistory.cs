namespace StockLab.Data.Entities
{
    public class TournamentHistory
    {
        public int BotId { get; set; }
        public int TournamentId { get; set; }
        public decimal Roi { get; set; }
        public int Rank { get; set; }
        public string Tier { get; set; } = string.Empty;

        public User Bot { get; set; } = null!;
        public Tournament Tournament { get; set; } = null!;
    }
}
