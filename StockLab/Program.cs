
using FluentValidation;
using FluentValidation.AspNetCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using StockLab.Hubs;
using StockLab.Middleware;
using StockLab.Repositories.Implementations;
using StockLab.Repositories.Interfaces;
using StockLab.Services.Implementations;
using StockLab.Services.Interfaces;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace StockLab
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.

            builder.Services.AddControllers();
            builder.Services.AddFluentValidationAutoValidation();
            builder.Services.AddValidatorsFromAssemblyContaining<Program>();
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen();

            var jwtKey = builder.Configuration["Jwt:Key"] ?? "SuperSecretKey12345";
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));

            builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                .AddJwtBearer(options =>
                {
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = false,
                        ValidateAudience = false,
                        ValidateLifetime = false,
                        ValidateIssuerSigningKey = true,
                        RoleClaimType = ClaimTypes.Role,
                        NameClaimType = ClaimTypes.NameIdentifier,

                        ValidIssuer = builder.Configuration["JwtSettings:Issuer"],
                        ValidAudience = builder.Configuration["JwtSettings:Audience"],
                        IssuerSigningKey = new SymmetricSecurityKey(
                        Encoding.UTF8.GetBytes(builder.Configuration["JwtSettings:Key"]))
                    };

                    options.Events = new JwtBearerEvents
                    {
                        OnMessageReceived = context =>
                        {
                            string token = null;


                            string authHeader = context.Request.Headers["Authorization"];
                            if (!string.IsNullOrEmpty(authHeader) && authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                            {
                                token = authHeader.Substring("Bearer ".Length).Trim();
                            }

                            if (string.IsNullOrEmpty(token) && context.Request.Cookies.ContainsKey("AuthToken"))
                            {
                                token = context.Request.Cookies["AuthToken"];
                                context.Request.Headers.Remove("Authorization");
                            }

                            if (!string.IsNullOrEmpty(token))
                            {
                                Console.WriteLine(token);
                                // Чистка
                                token = token.Replace("\"", "").Trim().Trim(new char[] { '\uFEFF', '\u200B', ' ', '\r', '\n', '\t' });
                                Console.WriteLine(token);
                                try
                                {
                                    var handler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();

                                    var principal = handler.ValidateToken(token, context.Options.TokenValidationParameters, out var validatedToken);

                                    context.Principal = principal;
                                    context.Success();

                                    return Task.CompletedTask;
                                }
                                catch (Exception ex)
                                {                                 
                                    Console.WriteLine($"[MANUAL VALIDATION ERROR] Токен есть, но невалиден: {ex.Message}");

                                }
                            }
                            else
                            {
                                Console.WriteLine("[DEBUG] Токен не найден.");
                            }

                            return Task.CompletedTask;
                        },

                        OnAuthenticationFailed = context =>
                        {
                            Console.WriteLine($"[FATAL] Ошибка валидации ASP.NET: {context.Exception.Message}");
                            return Task.CompletedTask;
                        },

                        OnTokenValidated = context =>
                        {
                            Console.WriteLine("[SUCCESS] Токен успешно прошел проверку!");
                            return Task.CompletedTask;
                        }
                    };
                });

            builder.Services.AddSingleton<IDbConnectionFactory, OracleConnectionFactory>();
            builder.Services.AddScoped<IUserService, OracleUserService>();      
            builder.Services.AddScoped<IHashService, Md5HashService>();
            builder.Services.AddSingleton<IJwtService,JwtService>();

            builder.Services.AddScoped<IUserRepository, OracleUserRepository>();
            builder.Services.AddScoped<ISectorRepository, OracleSectorRepository>();
            builder.Services.AddScoped<ICompanyRepository, OracleCompanyRepository>();
            builder.Services.AddScoped<ITradingRepository, OracleTradingRepository>();
            builder.Services.AddScoped<IPortfolioRepository, OraclePortfolioRepository>();
            builder.Services.AddScoped<IAdminRepository, OracleAdminRepository>();
            builder.Services.AddScoped<INotificationsRepository, OracleNotificationsRepository>();
            builder.Services.AddScoped<IBotRepository, OracleBotRepository>();
            builder.Services.AddScoped<IAnalyticsRepository, OracleAnalyticsRepository>();

            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AllowFrontend", builder =>
                {
                    builder
                        .WithOrigins($"http://localhost:5173") // ⚠️ Поставь свой фронтенд
                        .AllowCredentials()
                        .AllowAnyHeader()
                        .AllowAnyMethod();
                });
            });
            builder.Services.AddSignalR();
            builder.Services.AddSingleton<ConnectionManager>();
            //builder.Services.AddHostedService<MarketBackgroundService>();
            builder.Services.AddHostedService<NotificationBackgroundService>();
            builder.Services.AddHostedService<AnalyticsBroadcastService>();

            var app = builder.Build();

            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }

            app.UseMiddleware<ErrorHandlingMiddleware>();
            app.UseCors("AllowFrontend");
            app.UseAuthentication();
            app.UseAuthorization();
            //app.MapHub<MarketHub>("/hubs/market");
            app.MapHub<NotificationHub>("/hubs/notifications");
            app.MapHub<DashboardHub>("/hubs/dashboard");

            app.UseHttpsRedirection();


            app.MapControllers();

            app.Run();
        }
    }
}
