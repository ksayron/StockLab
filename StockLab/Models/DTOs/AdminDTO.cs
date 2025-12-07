namespace StockLab.Models.DTOs
{
    public class AdminUserDetailDto
    {
        public int UserId { get; set; }
        public string Username { get; set; }
        public string Email { get; set; }
        public decimal Balance { get; set; }
        public bool IsBanned { get; set; }
        public string RoleName { get; set; }
        public DateTime CreatedAt { get; set; }
        public int TotalOrders { get; set; }
        public int TotalTrades { get; set; }
    }

    public class AdminOrderViewDto
    {
        public int OrderId { get; set; }
        public string Username { get; set; }
        public string Type { get; set; }
        public string Status { get; set; }
        public decimal Price { get; set; }
        public int Qty { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class AdminTradeViewDto
    {
        public int TradeId { get; set; }
        public string Buyer { get; set; }
        public string Seller { get; set; }
        public decimal Price { get; set; }
        public int Qty { get; set; }
        public DateTime ExecutedAt { get; set; }
    }

    public class BalanceAdjustmentDto
    {
        public decimal NewBalance { get; set; }
    }
    public class CreateAdminDto
    {
        public string Username { get; set; }
        public string Password { get; set; }
    }
    public class SystemLogDto
    {
        public int LogId { get; set; }
        public string ProcName { get; set; }
        public int? UserId { get; set; }
        public string ErrorCode { get; set; }
        public string ErrorMsg { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
