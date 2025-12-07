using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Oracle.ManagedDataAccess.Client;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SectorController : ControllerBase
    {
        private readonly ISectorRepository _repository;

        public SectorController(ISectorRepository repository)
        {
            _repository = repository;
        }

        // ==========================================
        // PUBLIC (Доступно всем, даже без токена)
        // ==========================================

        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> GetAll()
        {
            try
            {
                var sectors = await _repository.GetAllSectorsAsync();
                return Ok(new ResponseWrapper(true, "Сектора получены", sectors));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ResponseWrapper(false, ex.Message));
            }
        }

        [HttpGet("{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetById(int id)
        {
            try
            {
                var sector = await _repository.GetSectorByIdAsync(id);
                if (sector == null)
                    return NotFound(new ResponseWrapper(false, "Сектор не найден"));

                return Ok(new ResponseWrapper(true, "Сектор найден", sector));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new ResponseWrapper(false, ex.Message));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ResponseWrapper(false, ex.Message));
            }
        }

        // ==========================================
        // ADMIN (Только роль Admin)
        // ==========================================

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] CreateSectorDto dto)
        {
            try
            {
                var newId = await _repository.AddSectorAsync(dto.Name, dto.Description);
                return CreatedAtAction(nameof(GetById), new { id = newId },
                    new ResponseWrapper(true, "Сектор успешно создан", newId));
            }
            catch (InvalidOperationException ex) // "Имя занято"
            {
                return Conflict(new ResponseWrapper(false, ex.Message));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ResponseWrapper(false, ex.Message));
            }
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateSectorDto dto)
        {
            try
            {
                await _repository.UpdateSectorAsync(id, dto.Name, dto.Description);
                return Ok(new ResponseWrapper(true, "Сектор успешно обновлен"));
            }
            catch (KeyNotFoundException ex) // "Не найден"
            {
                return NotFound(new ResponseWrapper(false, ex.Message));
            }
            catch (InvalidOperationException ex) // "Имя занято"
            {
                return Conflict(new ResponseWrapper(false, ex.Message));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ResponseWrapper(false, ex.Message));
            }
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                await _repository.DeleteSectorAsync(id);
                return Ok(new ResponseWrapper(true, "Сектор успешно удален"));
            }
            catch (KeyNotFoundException ex) // "Не найден"
            {
                return NotFound(new ResponseWrapper(false, ex.Message));
            }
            catch (InvalidOperationException ex) // "Содержит компании" (FK)
            {
                return BadRequest(new ResponseWrapper(false, ex.Message));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ResponseWrapper(false, ex.Message));
            }
        }
    }
}
