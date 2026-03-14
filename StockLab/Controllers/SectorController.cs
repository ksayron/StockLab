using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Models.DTOs;
using StockLab.Services;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SectorController(SectorService sectorService) : ControllerBase
    {
        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> GetAll()
        {
            try
            {
                var sectors = await sectorService.GetAllSectorsAsync();
                return Ok(new ResponseWrapper(true, "Сектора получены", sectors));
            }
            catch (Exception ex) { return StatusCode(500, new ResponseWrapper(false, ex.Message)); }
        }

        [HttpGet("{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetById(int id)
        {
            try
            {
                var sector = await sectorService.GetByIdAsync(id);
                if (sector == null) return NotFound(new ResponseWrapper(false, "Сектор не найден"));
                return Ok(new ResponseWrapper(true, "Сектор найден", sector));
            }
            catch (Exception ex) { return StatusCode(500, new ResponseWrapper(false, ex.Message)); }
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] CreateSectorDto dto)
        {
            try
            {
                var newId = await sectorService.AddSectorAsync(dto.Name, dto.Description);
                return CreatedAtAction(nameof(GetById), new { id = newId },
                    new ResponseWrapper(true, "Сектор успешно создан", newId));
            }
            catch (InvalidOperationException ex) { return Conflict(new ResponseWrapper(false, ex.Message)); }
            catch (Exception ex) { return StatusCode(500, new ResponseWrapper(false, ex.Message)); }
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateSectorDto dto)
        {
            try
            {
                await sectorService.UpdateSectorAsync(id, dto.Name, dto.Description);
                return Ok(new ResponseWrapper(true, "Сектор успешно обновлен"));
            }
            catch (KeyNotFoundException ex) { return NotFound(new ResponseWrapper(false, ex.Message)); }
            catch (InvalidOperationException ex) { return Conflict(new ResponseWrapper(false, ex.Message)); }
            catch (Exception ex) { return StatusCode(500, new ResponseWrapper(false, ex.Message)); }
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                await sectorService.DeleteSectorAsync(id);
                return Ok(new ResponseWrapper(true, "Сектор успешно удален"));
            }
            catch (KeyNotFoundException ex) { return NotFound(new ResponseWrapper(false, ex.Message)); }
            catch (InvalidOperationException ex) { return BadRequest(new ResponseWrapper(false, ex.Message)); }
            catch (Exception ex) { return StatusCode(500, new ResponseWrapper(false, ex.Message)); }
        }
    }
}
