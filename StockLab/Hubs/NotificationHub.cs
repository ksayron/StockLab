using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using StockLab.Services.Implementations;
using System.Security.Claims;
using System.Text.RegularExpressions;

    namespace StockLab.Hubs
    {
        [Authorize]
        public class NotificationHub : Hub
        {
            private readonly ConnectionManager _connectionManager;

            public NotificationHub(ConnectionManager connectionManager)
            {
                _connectionManager = connectionManager;
            }

            public override Task OnConnectedAsync()
            {
                var userId = GetUserId();
                if (userId > 0)
                {
                    _connectionManager.UserConnected(userId);

                    // Добавляем соединение в личную группу пользователя, 
                    // чтобы можно было слать сообщения конкретно ему: Clients.Group("User_5")
                    Groups.AddToGroupAsync(Context.ConnectionId, $"USER_{userId}");
                }
                return base.OnConnectedAsync();
            }

            public override Task OnDisconnectedAsync(Exception? exception)
            {
                var userId = GetUserId();
                if (userId > 0)
                {
                    // В реальном приложении нужно проверять, не осталось ли у юзера других открытых вкладок.
                    // Но для простоты считаем: соединение закрылось -> юзер ушел.
                    _connectionManager.UserDisconnected(userId);
                    Groups.RemoveFromGroupAsync(Context.ConnectionId, $"USER_{userId}");
                }
                return base.OnDisconnectedAsync(exception);
            }

            private int GetUserId()
            {
                var claim = Context.User?.FindFirst(ClaimTypes.NameIdentifier);
                return claim != null && int.TryParse(claim.Value, out int id) ? id : 0;
            }
        }
    }
