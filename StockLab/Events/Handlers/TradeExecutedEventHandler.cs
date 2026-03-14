using MediatR;
using StockLab.Events;
using StockLab.Services;

namespace StockLab.Events.Handlers
{
    public class TradeExecutedEventHandler(NotificationService notificationService) : INotificationHandler<TradeExecutedEvent>
    {
        public async Task Handle(TradeExecutedEvent ev, CancellationToken cancellationToken)
        {
            await notificationService.CreateTradeNotificationAsync(
                ev.BuyerUserId,
                ev.SellerUserId,
                ev.CompanyName,
                ev.Ticker,
                ev.Price,
                ev.Quantity);
        }
    }
}
