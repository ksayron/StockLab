using FluentValidation;
using FluentValidation.AspNetCore;
using Hangfire;
using Hangfire.PostgreSql;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using StockLab.Data;
using StockLab.Hubs;
using StockLab.Jobs;
using StockLab.Middleware;
using StockLab.Services;
using StockLab.Services.Implementations;
using StockLab.Services.Interfaces;
using System.Reflection;
using System.Security.Claims;
using System.Text;

namespace StockLab
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            builder.Services.AddControllers();
            builder.Services.AddFluentValidationAutoValidation();
            builder.Services.AddValidatorsFromAssemblyContaining<Program>();
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen();

            // EF Core + PostgreSQL
            builder.Services.AddDbContext<AppDbContext>(opt =>
                opt.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

            // MediatR
            builder.Services.AddMediatR(cfg =>
                cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));

            // Hangfire
            builder.Services.AddHangfire(config => config
                .SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
                .UseSimpleAssemblyNameTypeSerializer()
                .UseRecommendedSerializerSettings()
                .UsePostgreSqlStorage(opt =>
                    opt.UseNpgsqlConnection(builder.Configuration.GetConnectionString("HangfireConnection"))));
            builder.Services.AddHangfireServer();

            // JWT Authentication
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
                            Encoding.UTF8.GetBytes(builder.Configuration["JwtSettings:Key"]!))
                    };
                    options.Events = new JwtBearerEvents
                    {
                        OnMessageReceived = context =>
                        {
                            string? token = null;
                            string? authHeader = context.Request.Headers["Authorization"];
                            if (!string.IsNullOrEmpty(authHeader) && authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                                token = authHeader["Bearer ".Length..].Trim();
                            if (string.IsNullOrEmpty(token) && context.Request.Cookies.ContainsKey("AuthToken"))
                            {
                                token = context.Request.Cookies["AuthToken"];
                                context.Request.Headers.Remove("Authorization");
                            }
                            if (!string.IsNullOrEmpty(token))
                            {
                                token = token.Replace("\"", "").Trim();
                                try
                                {
                                    var handler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
                                    var principal = handler.ValidateToken(token, context.Options.TokenValidationParameters, out _);
                                    context.Principal = principal;
                                    context.Success();
                                }
                                catch (Exception ex) { Console.WriteLine("[TOKEN ERROR] " + ex.Message); }
                            }
                            return Task.CompletedTask;
                        },
                        OnAuthenticationFailed = context =>
                        {
                            Console.WriteLine("[AUTH FAILED] " + context.Exception.Message);
                            return Task.CompletedTask;
                        }
                    };
                });

            // Application Services
            builder.Services.AddSingleton<IJwtService, JwtService>();
            builder.Services.AddSingleton<ConnectionManager>();

            builder.Services.AddScoped<UserService>();
            builder.Services.AddScoped<TradingService>();
            builder.Services.AddScoped<OrderMatchingService>();
            builder.Services.AddScoped<CompanyService>();
            builder.Services.AddScoped<PortfolioService>();
            builder.Services.AddScoped<SectorService>();
            builder.Services.AddScoped<AdminService>();
            builder.Services.AddScoped<BotService>();
            builder.Services.AddScoped<NotificationService>();
            builder.Services.AddScoped<AnalyticsService>();

            // Hangfire Jobs
            builder.Services.AddScoped<OrderMatchingJob>();
            builder.Services.AddScoped<BotTradingJob>();
            builder.Services.AddScoped<MarketDynamicsJob>();
            builder.Services.AddScoped<AnalyticsBroadcastJob>();
            builder.Services.AddScoped<NotificationDispatchJob>();

            // CORS
            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AllowFrontend", policy =>
                {
                    policy.WithOrigins("http://localhost:5173")
                          .AllowCredentials()
                          .AllowAnyHeader()
                          .AllowAnyMethod();
                });
            });

            builder.Services.AddSignalR();

            var app = builder.Build();

            // Auto-migrate on startup
            using (var scope = app.Services.CreateScope())
            {
                var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                dbContext.Database.Migrate();
            }

            // Hangfire Dashboard (open in dev)
            app.UseHangfireDashboard("/hangfire", new DashboardOptions
            {
                Authorization = [new HangfireNoAuthFilter()]
            });

            // Register recurring jobs
            RecurringJob.AddOrUpdate<OrderMatchingJob>("order-matching-fallback", j => j.MatchAllAsync(), "*/5 * * * * *");
            RecurringJob.AddOrUpdate<BotTradingJob>("bot-trading", j => j.ExecuteAsync(), "*/3 * * * * *");
            RecurringJob.AddOrUpdate<MarketDynamicsJob>("market-dynamics", j => j.ExecuteAsync(), "0 * * * * *");
            RecurringJob.AddOrUpdate<AnalyticsBroadcastJob>("analytics-broadcast", j => j.ExecuteAsync(), "*/3 * * * * *");
            RecurringJob.AddOrUpdate<NotificationDispatchJob>("notification-dispatch", j => j.ExecuteAsync(), "*/2 * * * * *");

            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }

            app.UseMiddleware<ErrorHandlingMiddleware>();
            app.UseCors("AllowFrontend");
            app.UseAuthentication();
            app.UseAuthorization();

            app.MapHub<NotificationHub>("/hubs/notifications");
            app.MapHub<DashboardHub>("/hubs/dashboard");

            app.UseHttpsRedirection();
            app.MapControllers();

            app.Run();
        }
    }

    /// <summary>Open Hangfire dashboard in development. Restrict in production.</summary>
    public class HangfireNoAuthFilter : Hangfire.Dashboard.IDashboardAuthorizationFilter
    {
        public bool Authorize(Hangfire.Dashboard.DashboardContext context) => true;
    }
}
