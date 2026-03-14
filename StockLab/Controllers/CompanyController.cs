using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Models.DTOs;
using StockLab.Services;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CompanyController(CompanyService companyService) : ControllerBase
    {
        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> GetCompanies(
            [FromQuery] string? search,
            [FromQuery] int? sectorId,
            [FromQuery] string sortBy = "NAME",
            [FromQuery] string sortDir = "ASC")
        {
            if (!new[] { "NAME", "PRICE", "VOLATILITY" }.Contains(sortBy.ToUpper())) sortBy = "NAME";
            if (!new[] { "ASC", "DESC" }.Contains(sortDir.ToUpper())) sortDir = "ASC";
            try
            {
                var result = await companyService.GetCompaniesAsync(search, sectorId, sortBy.ToUpper(), sortDir.ToUpper());
                return Ok(new { success = true, data = result });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetById(int id)
        {
            try
            {
                var company = await companyService.GetByIdAsync(id);
                if (company == null) return NotFound(new { success = false, message = "Компания не найдена" });
                return Ok(new { success = true, data = company });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpGet("{id}/history")]
        [AllowAnonymous]
        public async Task<IActionResult> GetHistory(int id, [FromQuery] int hours = 24)
        {
            try
            {
                var history = await companyService.GetPriceHistoryAsync(id, hours);
                return Ok(new { success = true, data = history });
            }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] CreateCompanyDto dto)
        {
            try
            {
                var newId = await companyService.CreateCompanyIpoAsync(dto);
                return CreatedAtAction(nameof(GetById), new { id = newId },
                    new { success = true, message = "Компания создана, IPO запущено", id = newId });
            }
            catch (InvalidOperationException ex) { return Conflict(new { success = false, message = ex.Message }); }
            catch (KeyNotFoundException ex) { return BadRequest(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] UpdateCompanyDto dto)
        {
            try
            {
                await companyService.UpdateCompanyAsync(id, dto);
                return Ok(new { success = true, message = "Компания обновлена" });
            }
            catch (KeyNotFoundException ex) { return NotFound(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delist(int id)
        {
            try
            {
                await companyService.DelistCompanyAsync(id);
                return Ok(new { success = true, message = "Компания делистингована" });
            }
            catch (KeyNotFoundException ex) { return NotFound(new { success = false, message = ex.Message }); }
            catch (Exception ex) { return StatusCode(500, new { success = false, message = ex.Message }); }
        }
    }
}
