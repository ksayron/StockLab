using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Services;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AnalyticsController(AnalyticsService analyticsService) : ControllerBase
    {
        [HttpGet("windrose")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetWindrose()
        {
            var data = await analyticsService.GetWindroseDataAsync();
            return Ok(new { success = true, data });
        }

        [HttpGet("heatmap")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetHeatmap()
        {
            var data = await analyticsService.GetMarketHeatmapAsync();
            return Ok(new { success = true, data });
        }

        [HttpGet("top5")]
        public async Task<IActionResult> GetTop5()
        {
            var data = await analyticsService.GetTopActiveCompaniesAsync();
            return Ok(new { success = true, data });
        }
    }
}
