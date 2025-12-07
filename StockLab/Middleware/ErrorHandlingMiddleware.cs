using System.Net;
using System.Text.Json;

namespace StockLab.Middleware
{
    public class ErrorHandlingMiddleware
    {
        private readonly RequestDelegate _next;

        public ErrorHandlingMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext ctx)
        {
            try
            {
                await _next(ctx);
            }
            catch (Exception ex)
            {
                ctx.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
                ctx.Response.ContentType = "application/json";
                var resp = JsonSerializer.Serialize(new { success = false, message = ex.Message });
                await ctx.Response.WriteAsync(resp);
            }
        }
    }
}
