using MediatR;

namespace StockLab.Events
{
    public record OrderPlacedEvent(int OrderId, int CompanyId, int UserId, string Type) : INotification;
}
