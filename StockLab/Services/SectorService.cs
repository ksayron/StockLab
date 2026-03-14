using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Models.DTOs;

namespace StockLab.Services
{
    public class SectorService(AppDbContext db)
    {
        public async Task<IEnumerable<SectorDto>> GetAllSectorsAsync()
        {
            return await db.Sectors
                .Select(s => new SectorDto { Id = s.Id, Name = s.Name, Description = s.Description })
                .ToListAsync();
        }

        public async Task<SectorDto?> GetByIdAsync(int id)
        {
            return await db.Sectors
                .Where(s => s.Id == id)
                .Select(s => new SectorDto { Id = s.Id, Name = s.Name, Description = s.Description })
                .FirstOrDefaultAsync();
        }

        public async Task<int> AddSectorAsync(string name, string? description)
        {
            if (await db.Sectors.AnyAsync(s => s.Name == name))
                throw new InvalidOperationException("Сектор с таким именем уже существует");

            var sector = new Sector { Name = name, Description = description };
            db.Sectors.Add(sector);
            await db.SaveChangesAsync();
            return sector.Id;
        }

        public async Task UpdateSectorAsync(int id, string name, string? description)
        {
            var sector = await db.Sectors.FindAsync(id)
                ?? throw new KeyNotFoundException("Сектор не найден");

            if (await db.Sectors.AnyAsync(s => s.Name == name && s.Id != id))
                throw new InvalidOperationException("Сектор с таким именем уже существует");

            sector.Name = name;
            sector.Description = description;
            await db.SaveChangesAsync();
        }

        public async Task DeleteSectorAsync(int id)
        {
            var sector = await db.Sectors.FindAsync(id)
                ?? throw new KeyNotFoundException("Сектор не найден");

            if (await db.Companies.AnyAsync(c => c.SectorId == id))
                throw new InvalidOperationException("Нельзя удалить сектор, содержащий компании");

            db.Sectors.Remove(sector);
            await db.SaveChangesAsync();
        }
    }
}
