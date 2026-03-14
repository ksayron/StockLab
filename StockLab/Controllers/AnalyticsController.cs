using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Repositories.Interfaces;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AnalyticsController : ControllerBase
    {
        private readonly IAnalyticsRepository _repository;

        public AnalyticsController(IAnalyticsRepository repository)
        {
            _repository = repository;
        }

        [HttpGet("windrose")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetWindrose()
        {
            var data = await _repository.GetWindroseDataAsync();
            return Ok(new { success = true, data });
        }

        [HttpGet("heatmap")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetHeatmap()
        {
            var data = await _repository.GetMarketHeatmapAsync();
            return Ok(new { success = true, data });
        }

        [HttpGet("top5")]
        public async Task<IActionResult> GetTop5()
        {
            var data = await _repository.GetTopActiveCompaniesAsync();
            return Ok(new { success = true, data });
        }
    }
}
