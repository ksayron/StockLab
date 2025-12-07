using StockLab.Models.DTOs;

namespace StockLab.Repositories.Interfaces
{
    public interface ISectorRepository
    {
        // Public Methods (pkg_market_view)
        Task<IEnumerable<SectorDto>> GetAllSectorsAsync();
        Task<SectorDto> GetSectorByIdAsync(int id);

        // Admin Methods (pkg_market_admin)
        Task<int> AddSectorAsync(string name, string description);
        Task UpdateSectorAsync(int id, string name, string description);
        Task DeleteSectorAsync(int id);
    }
}
