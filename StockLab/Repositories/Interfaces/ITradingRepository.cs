using StockLab.Models.DTOs;

namespace StockLab.Repositories.Interfaces
{
    public interface ITradingRepository
    {
        Task<int> PlaceOrderAsync(int userId, PlaceOrderDto dto);
        Task CancelOrderAsync(int userId, int orderId);
        Task<IEnumerable<OrderDto>> GetUserOrdersAsync(int userId);
    }
}
