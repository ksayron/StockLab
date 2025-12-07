namespace StockLab.Models.DTOs
{


    public class AuthResult
    {
        public int UserId { get; set; }
        public string RoleName { get; set; }
        public bool IsBanned { get; set; }
    }
    public class UserProfileDto
    {
        public int UserId { get; set; }
        public string Username { get; set; }
        public string Email { get; set; }
        public decimal Balance { get; set; }
        public string RoleName { get; set; }
        public DateTime CreatedAt { get; set; }
    }
    public class UserDTO
    {
        public int Id { get; set; }
        public string Username { get; set; } = "";
        public string PasswordHash { get; set; }
        public string Email { get; set; } = "";
        public int RoleId { get; set; }
        public decimal Balance { get; set; }
    }
}
