using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Models.DTOs;
using StockLab.Services;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")]
    public class BotController(BotService botService, PortfolioService portfolioService, TradingService tradingService) : ControllerBase
    {
        [HttpPost("season")]
        public async Task<IActionResult> GenerateSeason([FromBody] GenerateSeasonDto dto)
        {
            try
            {
                await botService.GenerateSeasonAsync(dto.BotCount);
                return Ok(new { success = true, message = $"Сезон создан. {dto.BotCount} ботов сгенерировано." });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpPost("start")]
        public async Task<IActionResult> StartTournament()
        {
            try
            {
                await botService.StartTournamentAsync();
                return Ok(new { success = true, message = "Турнир запущен/возобновлен." });
            }
            catch (Exception ex) { return BadRequest(new { success = false, message = ex.Message }); }
        }

        [HttpPost("pause")]
        public async Task<IActionResult> PauseTournament()
        {
            try
            {
                await botService.PauseTournamentAsync();
                return Ok(new { success = true, message = "Турнир на паузе." });
            }
            catch (Exception ex) { return BadRequest(new { success = false, message = ex.Message }); }
        }

        [HttpPost("finalize")]
        public async Task<IActionResult> FinalizeTournament()
        {
            try
            {
                await botService.FinalizeTournamentAsync();
                return Ok(new { success = true, message = "Турнир завершен." });
            }
            catch (Exception ex) { return BadRequest(new { success = false, message = ex.Message }); }
        }

        [HttpGet("status")]
        public async Task<IActionResult> GetStatus()
        {
            try
            {
                var status = await botService.GetTournamentStatusAsync();
                return Ok(new { success = true, status });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet]
        public async Task<IActionResult> GetAllBots()
        {
            try
            {
                var bots = await botService.GetAllBotsAsync();
                return Ok(new { success = true, data = bots });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetBotDetails(int id)
        {
            try
            {
                var bot = await botService.GetBotDetailsAsync(id);
                if (bot == null) return NotFound(new { success = false, message = "Бот не найден" });
                return Ok(new { success = true, data = bot });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("summary/{id}")]
        public async Task<IActionResult> GetSummary(int id)
        {
            try
            {
                var summary = await portfolioService.GetSummaryAsync(id);
                return Ok(new { success = true, data = summary });
            }
            catch (KeyNotFoundException ex) { return NotFound(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("items/{id}")]
        public async Task<IActionResult> GetItems(int id)
        {
            try
            {
                var items = await portfolioService.GetItemsAsync(id);
                return Ok(new { success = true, data = items });
            }
            catch (KeyNotFoundException ex) { return NotFound(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("orders/{id}")]
        public async Task<IActionResult> GetOrders(int id)
        {
            try
            {
                var orders = await tradingService.GetUserOrdersAsync(id);
                return Ok(new { success = true, data = orders });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }
    }
}
