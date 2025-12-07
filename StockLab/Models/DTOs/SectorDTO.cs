namespace StockLab.Models.DTOs
{
    // Used for reading data (GET)
    public class SectorDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
    }

    // Used for creating/updating data (POST/PUT)
    public class CreateSectorDto
    {
        public string Name { get; set; }
        public string Description { get; set; }
    }
}
