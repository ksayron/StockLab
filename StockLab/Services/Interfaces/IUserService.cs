using StockLab.Models.DTOs;

namespace StockLab.Services.Interfaces
{
    public interface IUserService
    {
        Task<IEnumerable<UserDTO>> GetUsersAsync();
        Task<int?> AuthLoginAsync(string username, string passwordHash);
        Task AddUserAsync(RegisterRequest req);
        Task<UserDTO?> GetUserByUsernameAsync(string username);
    }
}
