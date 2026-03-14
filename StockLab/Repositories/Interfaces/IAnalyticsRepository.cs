using StockLab.Models.DTOs;

namespace StockLab.Repositories.Interfaces
{
    public interface IAnalyticsRepository
    {
        Task<IEnumerable<WindroseDto>> GetWindroseDataAsync();
        Task<IEnumerable<HeatmapDto>> GetMarketHeatmapAsync();
        Task<IEnumerable<TopActiveDto>> GetTopActiveCompaniesAsync();
    }
}
