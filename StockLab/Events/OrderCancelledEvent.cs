using MediatR;

namespace StockLab.Events
{
    public record OrderCancelledEvent(int OrderId, int CompanyId, int UserId, string Type) : INotification;
}
