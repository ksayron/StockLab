using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Models.DTOs;
using StockLab.Services;
using System.Security.Claims;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class TradingController(TradingService tradingService) : ControllerBase
    {
        private int GetCurrentUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (claim != null && int.TryParse(claim.Value, out int id)) return id;
            throw new UnauthorizedAccessException("Invalid User ID in Token");
        }

        [HttpGet("orders")]
        public async Task<IActionResult> GetMyOrders()
        {
            try
            {
                var orders = await tradingService.GetUserOrdersAsync(GetCurrentUserId());
                return Ok(new { success = true, data = orders });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpPost("order")]
        public async Task<IActionResult> PlaceOrder([FromBody] PlaceOrderDto dto)
        {
            if (dto.Quantity <= 0 || dto.LimitPrice <= 0)
                return BadRequest(new { success = false, message = "Quantity and Price must be positive" });
            if (dto.Type.ToUpper() != "BUY" && dto.Type.ToUpper() != "SELL")
                return BadRequest(new { success = false, message = "Type must be BUY or SELL" });

            try
            {
                var orderId = await tradingService.PlaceOrderAsync(GetCurrentUserId(), dto);
                return Ok(new { success = true, message = "Ордер успешно создан", orderId });
            }
            catch (InvalidOperationException ex) { return BadRequest(new { success = false, message = ex.Message }); }
            catch (UnauthorizedAccessException ex) { return Unauthorized(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpDelete("order/{id}")]
        public async Task<IActionResult> CancelOrder(int id)
        {
            try
            {
                await tradingService.CancelOrderAsync(GetCurrentUserId(), id);
                return Ok(new { success = true, message = "Ордер отменен" });
            }
            catch (KeyNotFoundException ex) { return NotFound(new { success = false, message = ex.Message }); }
            catch (InvalidOperationException ex) { return BadRequest(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }
    }
}
