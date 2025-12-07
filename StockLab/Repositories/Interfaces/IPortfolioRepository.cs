using StockLab.Models.DTOs;

namespace StockLab.Repositories.Interfaces
{
    public interface IPortfolioRepository
    {
        Task<PortfolioSummaryDto> GetSummaryAsync(int userId);
        Task<IEnumerable<PortfolioItemDto>> GetItemsAsync(int userId);
    }
}
