using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace StockLab.Hubs
{
    [AllowAnonymous]
    public class DashboardHub : Hub
    {
        public override async Task OnConnectedAsync()
        {
            var user = Context.User;

            // Проверяем, авторизован ли пользователь и есть ли у него роль Admin
            // Важно: Убедись, что в JWT токене роль мапится корректно на ClaimTypes.Role
            if (user != null && user.Identity != null && user.Identity.IsAuthenticated)
            {
                if (user.IsInRole("Admin"))
                {
                    // Добавляем соединение в закрытую группу
                    await Groups.AddToGroupAsync(Context.ConnectionId, "Admins");
                }
            }

            // Гости и обычные юзеры просто подключаются, но ни в какие группы не попадают
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var user = Context.User;
            if (user != null && user.IsInRole("Admin"))
            {
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, "Admins");
            }
            await base.OnDisconnectedAsync(exception);
        }
    }
}
