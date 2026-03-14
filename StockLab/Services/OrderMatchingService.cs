using MediatR;
using Microsoft.EntityFrameworkCore;
using StockLab.Data;
using StockLab.Data.Entities;
using StockLab.Events;

namespace StockLab.Services
{
    public class OrderMatchingService(AppDbContext db, IMediator mediator)
    {
        public async Task MatchOrdersAsync(int companyId)
        {
            var company = await db.Companies.FindAsync(companyId);
            if (company == null || company.Status != CompanyStatus.ACTIVE) return;

            var buyOrders = await db.Orders
                .Where(o => o.CompanyId == companyId && o.Type == OrderType.BUY
                    && (o.Status == OrderStatus.OPEN || o.Status == OrderStatus.PARTIAL))
                .OrderByDescending(o => o.LimitPrice).ThenBy(o => o.CreatedAt)
                .ToListAsync();

            var sellOrders = await db.Orders
                .Where(o => o.CompanyId == companyId && o.Type == OrderType.SELL
                    && (o.Status == OrderStatus.OPEN || o.Status == OrderStatus.PARTIAL))
                .OrderBy(o => o.LimitPrice).ThenBy(o => o.CreatedAt)
                .ToListAsync();

            bool anyMatch = false;

            foreach (var buy in buyOrders)
            {
                foreach (var sell in sellOrders)
                {
                    if (sell.RemainingQty == 0) continue;
                    if (buy.RemainingQty == 0) break;
                    if (buy.LimitPrice < sell.LimitPrice) break;

                    // Trade price = price of whichever order was placed first
                    decimal tradePrice = buy.CreatedAt <= sell.CreatedAt ? buy.LimitPrice : sell.LimitPrice;

                    // Volatility bounds check
                    decimal minPrice = company.CurrentPrice * (1 - company.Volatility);
                    decimal maxPrice = company.CurrentPrice * (1 + company.Volatility);
                    if (tradePrice < minPrice || tradePrice > maxPrice)
                        continue;

                    int qty = Math.Min(buy.RemainingQty, sell.RemainingQty);

                    // Create trade record
                    var trade = new Trade
                    {
                        BuyOrderId = buy.Id,
                        SellOrderId = sell.Id,
                        Price = tradePrice,
                        Quantity = qty
                    };
                    db.Trades.Add(trade);

                    // Update order quantities and statuses
                    buy.RemainingQty -= qty;
                    sell.RemainingQty -= qty;
                    buy.Status = buy.RemainingQty == 0 ? OrderStatus.FILLED : OrderStatus.PARTIAL;
                    sell.Status = sell.RemainingQty == 0 ? OrderStatus.FILLED : OrderStatus.PARTIAL;

                    // Credit buyer portfolio
                    var buyerHolding = await db.PortfolioItems
                        .FirstOrDefaultAsync(p => p.UserId == buy.UserId && p.CompanyId == companyId);
                    if (buyerHolding == null)
                        db.PortfolioItems.Add(new PortfolioItem { UserId = buy.UserId, CompanyId = companyId, QuantityOwned = qty });
                    else
                        buyerHolding.QuantityOwned += qty;

                    // Credit seller balance
                    var seller = await db.Users.FindAsync(sell.UserId);
                    if (seller != null) seller.Balance += qty * tradePrice;

                    // Refund buyer overpayment
                    decimal overpayment = (buy.LimitPrice - tradePrice) * qty;
                    if (overpayment > 0)
                    {
                        var buyer = await db.Users.FindAsync(buy.UserId);
                        if (buyer != null) buyer.Balance += overpayment;
                    }

                    // Update price and log
                    company.CurrentPrice = tradePrice;
                    company.LastTradeAt = DateTime.UtcNow;
                    db.PriceLogs.Add(new PriceLog { CompanyId = companyId, Price = tradePrice });

                    anyMatch = true;

                    await db.SaveChangesAsync();

                    await mediator.Publish(new TradeExecutedEvent(
                        trade.Id, companyId, company.Name, company.Ticker,
                        buy.UserId, sell.UserId, tradePrice, qty));
                }
            }

            if (anyMatch)
                await ApplyMarketDynamicsAsync(company);
        }

        private async Task ApplyMarketDynamicsAsync(Company company)
        {
            var oneMinuteAgo = DateTime.UtcNow.AddMinutes(-1);
            int recentTrades = await db.Trades
                .Where(t => t.BuyOrder.CompanyId == company.Id && t.ExecutedAt >= oneMinuteAgo)
                .CountAsync();

            // Overheat: reduce volatility if 15+ trades/min
            if (recentTrades >= 15)
            {
                company.Volatility = Math.Max(0.01m, company.Volatility * 0.95m);
                await db.SaveChangesAsync();
            }
        }
    }
}
