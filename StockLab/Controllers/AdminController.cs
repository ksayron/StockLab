using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Models.DTOs;
using StockLab.Services;
using System.Security.Claims;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")]
    public class AdminController(AdminService adminService) : ControllerBase
    {
        private int GetCurrentAdminId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier);
            return claim != null ? int.Parse(claim.Value) : 0;
        }

        [HttpPost("users/{userId}/ban")]
        public async Task<IActionResult> BanUser(int userId)
        {
            try
            {
                await adminService.BanUserAsync(GetCurrentAdminId(), userId, true);
                return Ok(new { success = true, message = "Пользователь заблокирован" });
            }
            catch (InvalidOperationException ex) { return BadRequest(new { success = false, message = ex.Message }); }
            catch (KeyNotFoundException ex) { return NotFound(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpPost("users/{userId}/unban")]
        public async Task<IActionResult> UnbanUser(int userId)
        {
            try
            {
                await adminService.BanUserAsync(GetCurrentAdminId(), userId, false);
                return Ok(new { success = true, message = "Пользователь разблокирован" });
            }
            catch (KeyNotFoundException ex) { return NotFound(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpPost("create")]
        public async Task<IActionResult> CreateAdmin([FromBody] CreateAdminDto dto)
        {
            try
            {
                await adminService.CreateNewAdminAsync(dto.Username, dto.Password);
                return Ok(new { success = true, message = "Новый администратор успешно создан" });
            }
            catch (InvalidOperationException ex) { return Conflict(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpPost("users/{userId}/balance")]
        public async Task<IActionResult> AdjustBalance(int userId, [FromBody] BalanceAdjustmentDto dto)
        {
            try
            {
                await adminService.AdjustBalanceAsync(userId, dto.NewBalance);
                return Ok(new { success = true, message = $"Баланс обновлен: {dto.NewBalance}" });
            }
            catch (KeyNotFoundException ex) { return NotFound(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("users/{userId}")]
        public async Task<IActionResult> GetUser(int userId)
        {
            try
            {
                var user = await adminService.GetUserDetailsAsync(userId);
                if (user == null) return NotFound(new { success = false, message = "Пользователь не найден" });
                return Ok(new { success = true, data = user });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("users")]
        public async Task<IActionResult> GetAllUsers()
        {
            try
            {
                var users = await adminService.GetAllUsersAsync();
                return Ok(new { success = true, data = users });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("export")]
        public async Task<IActionResult> ExportData()
        {
            try
            {
                string json = await adminService.ExportDatabaseJsonAsync();
                byte[] fileBytes = System.Text.Encoding.UTF8.GetBytes(json);
                string fileName = $"stocklab_backup_{DateTime.Now:yyyyMMdd_HHmm}.json";
                return File(fileBytes, "application/json", fileName);
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpPost("import")]
        [DisableRequestSizeLimit]
        [RequestFormLimits(MultipartBodyLengthLimit = 524288000)]
        public async Task<IActionResult> ImportData(IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest(new { success = false, message = "Файл пустой" });
            if (!file.FileName.EndsWith(".json"))
                return BadRequest(new { success = false, message = "Поддерживается только .json" });
            try
            {
                using var stream = new StreamReader(file.OpenReadStream());
                string jsonContent = await stream.ReadToEndAsync();
                await adminService.ImportDatabaseJsonAsync(jsonContent);
                return Ok(new { success = true, message = "Импорт успешен" });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("companies/{companyId}/orders")]
        public async Task<IActionResult> GetCompanyOrders(int companyId)
        {
            try
            {
                var orders = await adminService.GetCompanyOrdersAsync(companyId);
                return Ok(new { success = true, data = orders });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("companies/{companyId}/trades")]
        public async Task<IActionResult> GetCompanyTrades(int companyId)
        {
            try
            {
                var trades = await adminService.GetCompanyTradesAsync(companyId);
                return Ok(new { success = true, data = trades });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("logs")]
        public async Task<IActionResult> GetSystemLogs([FromQuery] int? minutes)
        {
            try
            {
                var logs = await adminService.GetSystemLogsAsync(minutes);
                return Ok(new { success = true, data = logs });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }
    }
}
