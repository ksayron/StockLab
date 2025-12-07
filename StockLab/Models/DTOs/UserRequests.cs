namespace StockLab.Models.DTOs
{
    public class LoginRequest
    {
        public string Username { get; set; } = "";
        public string PasswordHash { get; set; } = "";
    }
    public class RegisterRequest
    {
        public string Username { get; set; } = "";
        public string PasswordHash { get; set; } = "";
        public string Email { get; set; } = "";
    }

    public class DepositRequest
    {
        public int Amount { get; set; } = 0;
    }

    public record ResponseWrapper(bool Success, string Message, object? Data = null);

}
