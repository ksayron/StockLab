using StockLab.Models.DTOs;

namespace StockLab.Repositories.Interfaces
{
    public interface IAdminRepository
    {
        Task BanUserAsync(int adminId, int targetUserId, bool ban);
        Task CreateNewAdminAsync(string username, string passwordHash);
        Task AdjustBalanceAsync(int targetUserId, decimal newBalance);
        Task<AdminUserDetailDto?> GetUserDetailsAsync(int targetUserId);
        Task<IEnumerable<AdminOrderViewDto>> GetCompanyOrdersAsync(int companyId);
        Task<IEnumerable<AdminTradeViewDto>> GetCompanyTradesAsync(int companyId);
        Task<IEnumerable<SystemLogDto>> GetSystemLogsAsync(int? minutesBack);
        Task<string> ExportDatabaseJsonAsync();
        Task ImportDatabaseJsonAsync(string jsonContent);
    }
}
