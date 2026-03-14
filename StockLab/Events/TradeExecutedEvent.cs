using MediatR;

namespace StockLab.Events
{
    public record TradeExecutedEvent(
        int TradeId,
        int CompanyId,
        string CompanyName,
        string Ticker,
        int BuyerUserId,
        int SellerUserId,
        decimal Price,
        int Quantity) : INotification;
}
