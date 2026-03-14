using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockLab.Models.DTOs;
using StockLab.Services;
using StockLab.Services.Interfaces;
using System.Security.Claims;

namespace StockLab.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class UserController(UserService userService, IJwtService jwtService) : ControllerBase
    {
        [HttpPost("login")]
        [AllowAnonymous]
        public async Task<IActionResult> Login([FromBody] LoginRequest req)
        {
            try
            {
                var authResult = await userService.AuthenticateAsync(req.Username, req.PasswordHash);
                var token = jwtService.GenerateToken(authResult.UserId, req.Username, authResult.RoleName);
                Response.Cookies.Append("AuthToken", token, new CookieOptions
                {
                    HttpOnly = true, Secure = true, SameSite = SameSiteMode.None,
                    Expires = DateTime.UtcNow.AddHours(2)
                });
                return Ok(new { token, role = authResult.RoleName });
            }
            catch (UnauthorizedAccessException ex) { return Unauthorized(new ResponseWrapper(false, ex.Message)); }
            catch (Exception ex) { return StatusCode(500, new ResponseWrapper(false, ex.Message)); }
        }

        [HttpPost("register")]
        [AllowAnonymous]
        public async Task<IActionResult> Register([FromBody] RegisterRequest req)
        {
            try
            {
                await userService.RegisterAsync(req.Username, req.Email, req.PasswordHash);
                return Ok(new ResponseWrapper(true, "User registered successfully"));
            }
            catch (InvalidOperationException ex) { return Conflict(new ResponseWrapper(false, ex.Message)); }
            catch (Exception ex) { return StatusCode(500, new ResponseWrapper(false, ex.Message)); }
        }

        [HttpPost("logout")]
        public IActionResult Logout()
        {
            Response.Cookies.Append("AuthToken", "", new CookieOptions
            {
                HttpOnly = true, Secure = true, SameSite = SameSiteMode.Strict,
                Expires = DateTime.UtcNow.AddDays(-1)
            });
            return Ok(new ResponseWrapper(true, "Logged out successfully"));
        }

        [HttpGet("profile")]
        [Authorize]
        public async Task<IActionResult> GetProfile()
        {
            try
            {
                var idClaim = User.FindFirst(ClaimTypes.NameIdentifier);
                if (idClaim == null || !int.TryParse(idClaim.Value, out int userId))
                    return Unauthorized(new ResponseWrapper(false, "Invalid Token"));
                var profile = await userService.GetUserProfileAsync(userId);
                return Ok(new ResponseWrapper(true, "Profile fetched", profile));
            }
            catch (KeyNotFoundException ex) { return NotFound(new ResponseWrapper(false, ex.Message)); }
            catch (Exception ex) { return StatusCode(500, new ResponseWrapper(false, ex.Message)); }
        }

        [HttpPost("deposit")]
        [Authorize(Roles = "User")]
        public async Task<IActionResult> Deposit([FromBody] DepositRequest req)
        {
            try
            {
                var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
                await userService.DepositCashAsync(userId, req.Amount);
                return Ok(new ResponseWrapper(true, $"Deposited {req.Amount:C}"));
            }
            catch (InvalidOperationException ex) { return BadRequest(new ResponseWrapper(false, ex.Message)); }
            catch (Exception ex) { return StatusCode(500, new ResponseWrapper(false, ex.Message)); }
        }

        [HttpGet("debug-claims")]
        [Authorize]
        public IActionResult DebugClaims() => Ok(User.Claims.Select(c => new { c.Type, c.Value }));
    }
}
