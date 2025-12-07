using StockLab.Models.DTOs;

namespace StockLab.Repositories.Interfaces
{
    public interface ICompanyRepository
    {
        // View (Guest/User/Admin)
        Task<IEnumerable<CompanyDto>> GetCompaniesAsync(string? searchQuery,int? sectorId,string sortBy,string sortDir);
        Task<CompanyDto?> GetByIdAsync(int id);
        Task<IEnumerable<PriceLogDto>> GetPriceHistoryAsync(int companyId, int hoursBack);
        Task<IEnumerable<PriceUpdateDto>> GetRecentPriceUpdatesAsync(DateTime lastCheckTime);

        // Admin (Only Admin)
        Task<int> CreateCompanyIpoAsync(CreateCompanyDto dto);
        Task UpdateCompanyAsync(int id, UpdateCompanyDto dto);
        Task DelistCompanyAsync(int id);
    }
}
