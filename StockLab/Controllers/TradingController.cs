using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Oracle.ManagedDataAccess.Client;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using System.Security.Claims;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize] // Весь контроллер требует авторизации
    public class TradingController : ControllerBase
    {
        private readonly ITradingRepository _repository;

        public TradingController(ITradingRepository repository)
        {
            _repository = repository;
        }

        // Вспомогательный метод для получения ID из токена
        // Вспомогательный метод для получения ID из токена
        private int GetCurrentUserId()
        {
            // Используем тот тип клейма, который настроили в Program.cs (ClaimTypes.NameIdentifier)
            var claim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (claim != null && int.TryParse(claim.Value, out int id))
            {
                return id;
            }
            // Это исключение будет перехвачено в методах действия
            throw new UnauthorizedAccessException("Invalid User ID in Token");
        }

        // GET api/trading/orders - Мои заявки
        [HttpGet("orders")]
        public async Task<IActionResult> GetMyOrders()
        {
            try
            {
                int userId = GetCurrentUserId();
                var orders = await _repository.GetUserOrdersAsync(userId);
                return Ok(new { success = true, data = orders });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // POST api/trading/order - Создать заявку
        [HttpPost("order")]
        public async Task<IActionResult> PlaceOrder([FromBody] PlaceOrderDto dto)
        {
            // 1. Валидация входных данных
            if (dto.Quantity <= 0 || dto.LimitPrice <= 0)
                return BadRequest(new { success = false, message = "Quantity and Price must be positive" });

            if (dto.Type.ToUpper() != "BUY" && dto.Type.ToUpper() != "SELL")
                return BadRequest(new { success = false, message = "Type must be BUY or SELL" });

            try
            {
                int userId = GetCurrentUserId();
                int orderId = await _repository.PlaceOrderAsync(userId, dto);

                return Ok(new { success = true, message = "Ордер успешно создан", orderId = orderId });
            }
            // 2. Обработка ошибок бизнес-логики (из Репозитория)
            catch (InvalidOperationException ex)
            {
                // Сюда попадают: "Недостаточно средств", "Недостаточно акций"
                // Возвращаем 400 Bad Request
                return BadRequest(new { success = false, message = ex.Message });
            }
            // 3. Обработка ошибок авторизации (если токен кривой)
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(new { success = false, message = ex.Message });
            }
            // 4. Все остальные ошибки (Системные сбои, Биржа закрыта и т.д.)
            catch (Exception ex)
            {
                // Сюда попадет "DB Error: ..."
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // DELETE api/trading/order/{id} - Отменить заявку
        [HttpDelete("order/{id}")]
        public async Task<IActionResult> CancelOrder(int id)
        {
            try
            {
                int userId = GetCurrentUserId();
                await _repository.CancelOrderAsync(userId, id);
                return Ok(new { success = true, message = "Ордер отменен" });
            }
            // Ордер не найден или чужой
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { success = false, message = ex.Message });
            }
            // Ошибки логики (если вдруг будут)
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
            // Системные ошибки
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }
}
