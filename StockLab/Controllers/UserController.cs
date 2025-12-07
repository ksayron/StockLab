using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Oracle.ManagedDataAccess.Client;
using StockLab.Models.DTOs;
using StockLab.Repositories.Interfaces;
using StockLab.Services.Implementations;
using StockLab.Services.Interfaces;
using System;
using System.Security.Claims;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class UserController : ControllerBase
    {
        private readonly IUserRepository _userRepository;
        private readonly IHashService _hashService;
        private readonly IJwtService _jwtService;

        public UserController(IUserRepository userRepository, IHashService hashService, IJwtService jwtService)
        {
            _userRepository = userRepository;
            _hashService = hashService;
            _jwtService = jwtService;
        }

        // ---------------------------------------------------------
        // 1. LOGIN
        // ---------------------------------------------------------
        [HttpPost("login")]
        [AllowAnonymous]
        public async Task<IActionResult> Login([FromBody] LoginRequest req)
        {
            // Хешируем пароль, если он еще не хеширован
            string passwordHash = _hashService.IsHashSupported(req.PasswordHash)
                ? req.PasswordHash
                : _hashService.Hash(req.PasswordHash);

            try
            {
                // Вызываем репозиторий (он теперь сам проверяет статус из БД)
                var authResult = await _userRepository.AuthenticateAsync(req.Username, passwordHash);

                // Генерируем JWT
                var token = _jwtService.GenerateToken(
                    userId: authResult.UserId,
                    username: req.Username,
                    role: authResult.RoleName
                );

                // Устанавливаем Secure Cookie
                var cookieOptions = new CookieOptions
                {
                    HttpOnly = true,
                    Secure = true, // В продакшене обязательно true
                    SameSite = SameSiteMode.None,
                    Expires = DateTime.UtcNow.AddHours(2) // Синхронизируем со временем жизни токена
                };
                Response.Cookies.Append("AuthToken", token, cookieOptions);

                return Ok(new { token, role = authResult.RoleName });
            }
            catch (UnauthorizedAccessException ex) // Ловим "Неподходящие логин и пароль" или "заблокирован"
            {
                return Unauthorized(new ResponseWrapper(false, ex.Message));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ResponseWrapper(false, ex.Message));
            }
        }

        // ---------------------------------------------------------
        // 2. REGISTER
        // ---------------------------------------------------------
        [HttpPost("register")]
        [AllowAnonymous]
        public async Task<IActionResult> Register([FromBody] RegisterRequest req)
        {
            string passwordHash = _hashService.IsHashSupported(req.PasswordHash)
                ? req.PasswordHash
                : _hashService.Hash(req.PasswordHash);

            try
            {
                await _userRepository.RegisterAsync(req.Username, req.Email, passwordHash);
                return Ok(new ResponseWrapper(true, "User registered successfully"));
            }
            catch (InvalidOperationException ex) // Ловим "Имя занято" или "Зарезервированный префикс"
            {
                return Conflict(new ResponseWrapper(false, ex.Message));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ResponseWrapper(false, ex.Message));
            }
        }

        // ---------------------------------------------------------
        // 3. LOGOUT (Новый метод)
        // ---------------------------------------------------------
        [HttpPost("logout")]
        public IActionResult Logout()
        {
            // Чтобы "разлогинить" пользователя, мы перезаписываем куку с истекшим сроком действия
            Response.Cookies.Append("AuthToken", "", new CookieOptions
            {
                HttpOnly = true,
                Secure = true,
                SameSite = SameSiteMode.Strict,
                Expires = DateTime.UtcNow.AddDays(-1) // Ставим дату в прошлом
            });

            return Ok(new ResponseWrapper(true, "Logged out successfully"));
        }

        // ---------------------------------------------------------
        // 4. GET PROFILE
        // ---------------------------------------------------------
        [HttpGet("profile")]
        [Authorize]
        public async Task<IActionResult> GetProfile()
        {
            try
            {
                // Используем правильный ClaimType (в зависимости от настроек в Program.cs)
                var idClaim = User.FindFirst(ClaimTypes.NameIdentifier);
                if (idClaim == null || !int.TryParse(idClaim.Value, out int userId))
                {
                    return Unauthorized(new ResponseWrapper(false, "Invalid Token"));
                }

                var userProfile = await _userRepository.GetUserProfileAsync(userId);
                return Ok(new ResponseWrapper(true, "Profile fetched", userProfile));
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

        // ---------------------------------------------------------
        // 5. DEPOSIT FUNDS
        // ---------------------------------------------------------
        [HttpPost("deposit")]
        [Authorize(Roles = "User")] // Админам деньги не нужны :)
        public async Task<IActionResult> Deposit([FromBody] DepositRequest req)
        {
            try
            {
                var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);
                await _userRepository.DepositCashAsync(userId, req.Amount);
                return Ok(new ResponseWrapper(true, $"Deposited {req.Amount:C}"));
            }
            catch (InvalidOperationException ex) // "Нельзя начислять негативные суммы"
            {
                return BadRequest(new ResponseWrapper(false, ex.Message));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new ResponseWrapper(false, ex.Message));
            }
        }

        // ---------------------------------------------------------
        // DEBUG (Можно удалить перед продом)
        // ---------------------------------------------------------
        [HttpGet("debug-claims")]
        [Authorize]
        public IActionResult DebugClaims()
        {
            return Ok(User.Claims.Select(c => new { c.Type, c.Value }));
        }
    }
}