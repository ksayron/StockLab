using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using StockLab.Services.Interfaces;
using System.Security.Claims;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")] // Весь контроллер доступен только Админам
    public class AdminController : ControllerBase
    {
        private readonly IAdminRepository _repository;
        private readonly IHashService _hashService; // Добавляем сервис хеширования

        public AdminController(IAdminRepository repository, IHashService hashService)
        {
            _repository = repository;
            _hashService = hashService;
        }

        // Вспомогательный метод
        private int GetCurrentAdminId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier);
            // Если claim нет, то Authorize не пропустил бы, но на всякий случай
            return claim != null ? int.Parse(claim.Value) : 0;
        }

        // ==========================================
        // УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ
        // ==========================================

        // POST /api/admin/users/5/ban
        [HttpPost("users/{userId}/ban")]
        public async Task<IActionResult> BanUser(int userId)
        {
            try
            {
                await _repository.BanUserAsync(GetCurrentAdminId(), userId, true);
                return Ok(new { success = true, message = "Пользователь заблокирован" });
            }
            catch (InvalidOperationException ex) // "Нельзя забанить себя"
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
            catch (KeyNotFoundException ex) // "Пользователь не найден"
            {
                return NotFound(new { success = false, message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // POST /api/admin/users/5/unban
        [HttpPost("users/{userId}/unban")]
        public async Task<IActionResult> UnbanUser(int userId)
        {
            try
            {
                await _repository.BanUserAsync(GetCurrentAdminId(), userId, false);
                return Ok(new { success = true, message = "Пользователь разблокирован" });
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { success = false, message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // POST /api/admin/create
        // Вместо Promote теперь создание нового аккаунта
        [HttpPost("create")]
        public async Task<IActionResult> CreateAdmin([FromBody] CreateAdminDto dto)
        {
            // Важно: Хешируем пароль перед отправкой в БД
            string passwordHash = _hashService.IsHashSupported(dto.Password)
                ? dto.Password
                : _hashService.Hash(dto.Password);

            try
            {
                await _repository.CreateNewAdminAsync(dto.Username, passwordHash);
                return Ok(new { success = true, message = "Новый администратор успешно создан" });
            }
            catch (InvalidOperationException ex) // "Имя занято"
            {
                return Conflict(new { success = false, message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // POST /api/admin/users/5/balance
        [HttpPost("users/{userId}/balance")]
        public async Task<IActionResult> AdjustBalance(int userId, [FromBody] BalanceAdjustmentDto dto)
        {
            try
            {
                await _repository.AdjustBalanceAsync(userId, dto.NewBalance);
                return Ok(new { success = true, message = $"Баланс обновлен: {dto.NewBalance}" });
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { success = false, message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // GET /api/admin/users/5
        [HttpGet("users/{userId}")]
        public async Task<IActionResult> GetUser(int userId)
        {
            try
            {
                var user = await _repository.GetUserDetailsAsync(userId);

                // Если репозиторий вернул null (курсор пуст)
                if (user == null)
                    return NotFound(new { success = false, message = "Пользователь не найден" });

                return Ok(new { success = true, data = user });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // GET /api/admin/export
        [HttpGet("export")]
        public async Task<IActionResult> ExportData()
        {
            try
            {
                // 1. Получаем JSON строку из БД
                string json = await _repository.ExportDatabaseJsonAsync();

                // 2. Конвертируем в байты
                byte[] fileBytes = System.Text.Encoding.UTF8.GetBytes(json);
                string fileName = $"stocklab_backup_{DateTime.Now:yyyyMMdd_HHmm}.json";

                // 3. Возвращаем файл для скачивания (Content-Disposition: attachment)
                return File(fileBytes, "application/json", fileName);
            }
            catch (Exception ex)
            {
                // В случае ошибки возвращаем JSON с ошибкой, а не файл
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // POST /api/admin/import
        [HttpPost("import")]
        [DisableRequestSizeLimit] // Отключает лимит на тело запроса (Kestrel)
        [RequestFormLimits(MultipartBodyLengthLimit = 524288000)]
        public async Task<IActionResult> ImportData(IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest(new { success = false, message = "Файл пустой" });

            if (!file.FileName.EndsWith(".json"))
                return BadRequest(new { success = false, message = "Поддерживается только .json" });

            try
            {
                // 1. Читаем файл в строку
                using var stream = new StreamReader(file.OpenReadStream());
                string jsonContent = await stream.ReadToEndAsync();

                // 2. Отправляем в БД
                await _repository.ImportDatabaseJsonAsync(jsonContent);

                return Ok(new { success = true, message = "Импорт успешен" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // ==========================================
        // МОНИТОРИНГ РЫНКА
        // ==========================================

        // GET /api/admin/companies/5/orders
        [HttpGet("companies/{companyId}/orders")]
        public async Task<IActionResult> GetCompanyOrders(int companyId)
        {
            try
            {
                var orders = await _repository.GetCompanyOrdersAsync(companyId);
                return Ok(new { success = true, data = orders });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // GET /api/admin/companies/5/trades
        [HttpGet("companies/{companyId}/trades")]
        public async Task<IActionResult> GetCompanyTrades(int companyId)
        {
            try
            {
                var trades = await _repository.GetCompanyTradesAsync(companyId);
                return Ok(new { success = true, data = trades });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // GET /api/admin/logs (Добавленный ранее метод просмотра ошибок)
        [HttpGet("logs")]
        public async Task<IActionResult> GetSystemLogs([FromQuery] int? minutes)
        {
            try
            {
                
                var logs = await _repository.GetSystemLogsAsync(minutes);
                return Ok(new { success = true, data = logs });

            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
        [HttpGet("users")]
        public async Task<IActionResult> GetAllUsers()
        {
            try
            {
                var users = await _repository.GetAllUsersAsync();
                return Ok(new { success = true, data = users });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }   
}
