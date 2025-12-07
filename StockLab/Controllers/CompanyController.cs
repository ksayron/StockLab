using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Oracle.ManagedDataAccess.Client;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CompanyController : ControllerBase
    {
        private readonly ICompanyRepository _repository;

        public CompanyController(ICompanyRepository repository)
        {
            _repository = repository;
        }

        // =====================================================
        // PUBLIC (GET)
        // =====================================================

        // Единый метод для получения списка (Фильтр, Поиск, Сортировка)
        // GET /api/company?search=apple&sectorId=5&sortBy=PRICE&sortDir=DESC
        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> GetCompanies(
            [FromQuery] string? search,
            [FromQuery] int? sectorId,
            [FromQuery] string sortBy = "NAME",
            [FromQuery] string sortDir = "ASC")
        {
            // Валидация параметров сортировки
            if (!new[] { "NAME", "PRICE", "VOLATILITY" }.Contains(sortBy.ToUpper()))
                sortBy = "NAME";
            if (!new[] { "ASC", "DESC" }.Contains(sortDir.ToUpper()))
                sortDir = "ASC";

            try
            {
                var result = await _repository.GetCompaniesAsync(search, sectorId, sortBy.ToUpper(), sortDir.ToUpper());
                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetById(int id)
        {
            try
            {
                var company = await _repository.GetByIdAsync(id);
                if (company == null)
                    return NotFound(new { success = false, message = "Компания не найдена" });

                return Ok(new { success = true, data = company });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // =====================================================
        // ADMIN (POST/PUT/DELETE)
        // =====================================================

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] CreateCompanyDto dto)
        {
            try
            {
                var newId = await _repository.CreateCompanyIpoAsync(dto);
                return CreatedAtAction(nameof(GetById), new { id = newId },
                    new { success = true, message = "Компания создана, IPO запущено", id = newId });
            }
            catch (InvalidOperationException ex) // Имя занято
            {
                return Conflict(new { success = false, message = ex.Message });
            }
            catch (KeyNotFoundException ex) // Неверный Сектор ID
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] UpdateCompanyDto dto)
        {
            try
            {
                await _repository.UpdateCompanyAsync(id, dto);
                return Ok(new { success = true, message = "Компания обновлена" });
            }
            catch (KeyNotFoundException ex) // Не найдена
            {
                return NotFound(new { success = false, message = ex.Message });
            }
            catch (InvalidOperationException ex) // Имя занято
            {
                return Conflict(new { success = false, message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delist(int id)
        {
            try
            {
                await _repository.DelistCompanyAsync(id);
                return Ok(new { success = true, message = "Компания делистингована (цена сброшена)" });
            }
            catch (KeyNotFoundException ex) // Не найдена
            {
                return NotFound(new { success = false, message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("{id}/history")]
        [AllowAnonymous]
        public async Task<IActionResult> GetHistory(int id, [FromQuery] int hours = 24)
        {
            try
            {
                var history = await _repository.GetPriceHistoryAsync(id, hours);
                return Ok(new { success = true, data = history });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }
}
