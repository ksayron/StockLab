using StockLab.Models.DTOs;

namespace StockLab.Repositories.Interfaces
{
    public interface IUserRepository
    {
        /// <summary>
        /// Validates credentials against Oracle DB using the Guest connection.
        /// </summary>
        Task<AuthResult> AuthenticateAsync(string username, string passwordHash);

        /// <summary>
        /// Registers a new user using the Guest connection.
        /// </summary>
        Task RegisterAsync(string username, string email, string passwordHash);

        /// <summary>
        /// Fetches profile details using the User connection.
        /// </summary>
        Task<UserProfileDto> GetUserProfileAsync(int userId);

        /// <summary>
        /// Adds funds to the user's balance using the User connection.
        /// </summary>
        Task DepositCashAsync(int userId, decimal amount);
    }
}
