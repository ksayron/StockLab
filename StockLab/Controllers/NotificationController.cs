using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Services;
using System.Security.Claims;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class NotificationController(NotificationService notificationService) : ControllerBase
    {
        private int GetUserId() => int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

        [HttpGet]
        public async Task<IActionResult> GetNotifications([FromQuery] bool unreadOnly = false)
        {
            try
            {
                var data = await notificationService.GetUserNotificationsAsync(GetUserId(), unreadOnly);
                return Ok(new { success = true, data });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpPost("{id}/read")]
        public async Task<IActionResult> MarkAsRead(int id)
        {
            try
            {
                await notificationService.MarkAsReadAsync(GetUserId(), id);
                return Ok(new { success = true });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }
    }
}
