using MediatR;
using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Events;
using StockLab.Models.DTOs;

namespace StockLab.Services
{
    public class TradingService(AppDbContext db, IMediator mediator)
    {
        public async Task<int> PlaceOrderAsync(int userId, PlaceOrderDto dto)
        {
            var company = await db.Companies.FindAsync(dto.CompanyId)
                ?? throw new KeyNotFoundException("Компания не найдена");

            if (company.Status != CompanyStatus.ACTIVE)
                throw new InvalidOperationException("Компания не активна");

            var user = await db.Users.FindAsync(userId)
                ?? throw new KeyNotFoundException("Пользователь не найден");

            var type = Enum.Parse<OrderType>(dto.Type.ToUpper());

            if (type == OrderType.BUY)
            {
                decimal required = dto.LimitPrice * dto.Quantity;
                if (user.Balance < required)
                    throw new InvalidOperationException("Недостаточно средств");
                user.Balance -= required;
            }
            else
            {
                var holding = await db.PortfolioItems
                    .FirstOrDefaultAsync(p => p.UserId == userId && p.CompanyId == dto.CompanyId);
                if (holding == null || holding.QuantityOwned < dto.Quantity)
                    throw new InvalidOperationException("Недостаточно акций");
                holding.QuantityOwned -= dto.Quantity;
                if (holding.QuantityOwned == 0)
                    db.PortfolioItems.Remove(holding);
            }

            var order = new Order
            {
                UserId = userId,
                CompanyId = dto.CompanyId,
                Type = type,
                LimitPrice = dto.LimitPrice,
                OriginalQty = dto.Quantity,
                RemainingQty = dto.Quantity
            };

            db.Orders.Add(order);
            await db.SaveChangesAsync();

            await mediator.Publish(new OrderPlacedEvent(order.Id, dto.CompanyId, userId, dto.Type.ToUpper()));

            return order.Id;
        }

        public async Task CancelOrderAsync(int userId, int orderId)
        {
            var order = await db.Orders.FindAsync(orderId)
                ?? throw new KeyNotFoundException("Ордер не найден");

            if (order.UserId != userId)
                throw new KeyNotFoundException("Ордер не найден");

            if (order.Status != OrderStatus.OPEN && order.Status != OrderStatus.PARTIAL)
                throw new InvalidOperationException("Отменить можно только открытые ордера");

            if (order.Type == OrderType.BUY)
            {
                var user = await db.Users.FindAsync(userId)!;
                user!.Balance += order.RemainingQty * order.LimitPrice;
            }
            else
            {
                var holding = await db.PortfolioItems
                    .FirstOrDefaultAsync(p => p.UserId == userId && p.CompanyId == order.CompanyId);
                if (holding == null)
                {
                    db.PortfolioItems.Add(new PortfolioItem
                    {
                        UserId = userId,
                        CompanyId = order.CompanyId,
                        QuantityOwned = order.RemainingQty
                    });
                }
                else
                {
                    holding.QuantityOwned += order.RemainingQty;
                }
            }

            order.Status = OrderStatus.CANCELLED;
            order.RemainingQty = 0;
            await db.SaveChangesAsync();
        }

        public async Task<IEnumerable<OrderDto>> GetUserOrdersAsync(int userId)
        {
            return await db.Orders
                .Where(o => o.UserId == userId)
                .Include(o => o.Company)
                .OrderByDescending(o => o.CreatedAt)
                .Select(o => new OrderDto
                {
                    Id = o.Id,
                    Ticker = o.Company.Ticker,
                    Type = o.Type.ToString(),
                    Status = o.Status.ToString(),
                    LimitPrice = o.LimitPrice,
                    OriginalQty = o.OriginalQty,
                    RemainingQty = o.RemainingQty,
                    CreatedAt = o.CreatedAt
                })
                .ToListAsync();
        }
    }
}
