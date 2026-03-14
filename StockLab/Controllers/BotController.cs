using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")] // Только админы могут управлять симуляцией
    public class BotController : ControllerBase
    {
        private readonly IBotRepository _botRepository;
        private readonly IPortfolioRepository _portfolioRepository;
        private readonly ITradingRepository _tradingRepository;

        public BotController(IBotRepository botRepository, IPortfolioRepository portfolioRepository, ITradingRepository tradingRepository)
        {
            _botRepository = botRepository;
            _portfolioRepository = portfolioRepository;
            _tradingRepository = tradingRepository;
        }

        // ==========================================
        // УПРАВЛЕНИЕ ТУРНИРОМ
        // ==========================================

        // POST /api/bot/season (Хард ресет и генерация)
        [HttpPost("season")]
        public async Task<IActionResult> GenerateSeason([FromBody] GenerateSeasonDto dto)
        {
            try
            {
                await _botRepository.GenerateAndStartSeasonAsync(dto.BotCount);
                return Ok(new { success = true, message = $"Сезон создан. {dto.BotCount} ботов сгенерировано." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // POST /api/bot/start (Ручной старт / Возобновление)
        [HttpPost("start")]
        public async Task<IActionResult> StartTournament()
        {
            try
            {
                await _botRepository.StartTournamentAsync();
                return Ok(new { success = true, message = "Турнир запущен/возобновлен." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        // POST /api/bot/pause
        [HttpPost("pause")]
        public async Task<IActionResult> PauseTournament()
        {
            try
            {
                await _botRepository.PauseTournamentAsync();
                return Ok(new { success = true, message = "Турнир на паузе." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        // POST /api/bot/finalize
        [HttpPost("finalize")]
        public async Task<IActionResult> FinalizeTournament()
        {
            try
            {
                await _botRepository.FinalizeTournamentAsync();
                return Ok(new { success = true, message = "Турнир завершен." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        // GET /api/bot/status
        [HttpGet("status")]
        public async Task<IActionResult> GetStatus()
        {
            try
            {
                var status = await _botRepository.GetTournamentStatusAsync();
                return Ok(new { success = true, status = status }); // ACTIVE, PAUSED, FINISHED, PLANNED
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // ==========================================
        // ДАННЫЕ БОТОВ
        // ==========================================

        // GET /api/bot
        [HttpGet]
        public async Task<IActionResult> GetAllBots()
        {
            try
            {
                var bots = await _botRepository.GetAllBotsAsync();
                return Ok(new { success = true, data = bots });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // GET /api/bot/5
        [HttpGet("{id}")]
        public async Task<IActionResult> GetBotDetails(int id)
        {
            try
            {
                var bot = await _botRepository.GetBotDetailsAsync(id);
                if (bot == null)
                    return NotFound(new { success = false, message = "Бот не найден" });

                return Ok(new { success = true, data = bot });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // GET api/portfolio/summary
        [HttpGet("summary/{id}")]
        public async Task<IActionResult> GetSummary(int id)
        {
            try
            {
                var summary = await _portfolioRepository.GetSummaryAsync(id);
                return Ok(new { success = true, data = summary });
            }
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(new { success = false, message = ex.Message });
            }
            catch (KeyNotFoundException ex)
            {
                // Если пользователь не найден в БД (например, удален админом, но токен остался)
                return NotFound(new { success = false, message = ex.Message });
            }
            catch (Exception ex)
            {
                // Любые другие ошибки БД (Soft Error -> Exception)
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("items/{id}")]
        public async Task<IActionResult> GetItems(int id)
        {
            try
            {
                var items = await _portfolioRepository.GetItemsAsync(id);
                return Ok(new { success = true, data = items });
            }
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(new { success = false, message = ex.Message });
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

        // GET api/Bot/orders - заявки
        [HttpGet("orders/{id}")]
        public async Task<IActionResult> GetOrders(int id)
        {
            try
            {
                var orders = await _tradingRepository.GetUserOrdersAsync(id);
                return Ok(new { success = true, data = orders });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }
}
