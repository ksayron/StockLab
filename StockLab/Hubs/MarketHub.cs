using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using System.Text.RegularExpressions;

namespace StockLab.Hubs
{
    [Authorize] // Токены из HTTP работают и тут!
    public class MarketHub : Hub
    {
        // Клиент вызывает этот метод, чтобы подписаться на обновления конкретной акции
        public async Task SubscribeToTicker(string ticker)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, ticker.ToUpper());
        }

        public async Task UnsubscribeFromTicker(string ticker)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, ticker.ToUpper());
        }
    }
}
