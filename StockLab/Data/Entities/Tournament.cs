namespace StockLab.Data.Entities
{
    public enum TournamentStatus { PLANNED = 0, ACTIVE = 1, PAUSED = 2, FINISHED = 3 }

    public class Tournament
    {
        public int Id { get; set; }
        public TournamentStatus Status { get; set; } = TournamentStatus.PLANNED;
        public DateTime? StartedAt { get; set; }
        public DateTime? FinishedAt { get; set; }

        public ICollection<NetWorthSnapshot> NetWorthSnapshots { get; set; } = [];
        public ICollection<TournamentHistory> History { get; set; } = [];
    }
}
