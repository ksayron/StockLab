using Hangfire;
using MediatR;
using StockLab.Events;
using StockLab.Jobs;

namespace StockLab.Events.Handlers
{
    public class OrderPlacedEventHandler(IBackgroundJobClient jobClient) : INotificationHandler<OrderPlacedEvent>
    {
        public Task Handle(OrderPlacedEvent notification, CancellationToken cancellationToken)
        {
            jobClient.Enqueue<OrderMatchingJob>(j => j.MatchAsync(notification.CompanyId, CancellationToken.None));
            return Task.CompletedTask;
        }
    }
}
