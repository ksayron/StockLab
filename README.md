# StockLab

A stock market simulation platform with a bot tournament system. Users trade shares of companies in a simulated market, while AI bots compete in timed tournaments. The platform features real-time dashboards, order matching, market dynamics, and a full admin panel.

---

## Tech Stack

### Backend — `StockLab/`
| Layer | Technology |
|---|---|
| Runtime | .NET 8 / ASP.NET Core |
| ORM | Entity Framework Core 8 (Npgsql) |
| Database | PostgreSQL 16 (Docker) |
| Background jobs | Hangfire + Hangfire.PostgreSql |
| In-process events | MediatR 12 |
| Real-time | SignalR |
| Auth | JWT Bearer tokens |
| Password hashing | BCrypt.Net-Next |
| Validation | FluentValidation |
| API docs | Swagger / Swashbuckle |

### Frontend — `StockLab_Client/`
| Layer | Technology |
|---|---|
| Framework | Vue 3 + Vite |
| UI library | PrimeVue |
| HTTP client | Axios |
| Charts | Chart.js / PrimeVue Charts |
| Real-time | SignalR JS client |

---

## Architecture

```
StockLab/
├── Controllers/          # REST API endpoints (9 controllers)
├── Data/
│   ├── AppDbContext.cs   # EF Core context, fluent config, seed data
│   └── Entities/         # 15 domain entities (User, Order, Trade, etc.)
├── Events/               # MediatR domain events
│   ├── OrderPlacedEvent.cs
│   ├── OrderCancelledEvent.cs
│   ├── TradeExecutedEvent.cs
│   └── Handlers/         # Event handlers that enqueue Hangfire jobs
├── Jobs/                 # Hangfire recurring background jobs
│   ├── OrderMatchingJob.cs       (every 5s + triggered on order place)
│   ├── BotTradingJob.cs          (every 3s, runs during active tournament)
│   ├── MarketDynamicsJob.cs      (every 60s, volatility adjustments)
│   ├── AnalyticsBroadcastJob.cs  (every 3s, SignalR push to dashboards)
│   └── NotificationDispatchJob.cs (every 2s, unread notification delivery)
├── Services/             # Business logic (10 services)
│   ├── OrderMatchingService.cs   # Price-time priority matching engine
│   ├── TradingService.cs         # Order placement / cancellation
│   ├── BotService.cs             # Tournament lifecycle + bot generation
│   ├── CompanyService.cs         # IPO creation, delisting, price history
│   ├── PortfolioService.cs       # Net worth, 24h P&L
│   ├── UserService.cs            # Auth, registration, deposit
│   ├── NotificationService.cs    # Trade alerts, personal notifications
│   ├── AdminService.cs           # Ban/unban, balance adjust, import/export
│   ├── AnalyticsService.cs       # Windrose, heatmap, top active companies
│   └── SectorService.cs          # Sector CRUD
├── Hubs/                 # SignalR hubs (NotificationHub, DashboardHub, MarketHub)
├── Models/DTOs/          # Request/response shapes
└── Program.cs            # DI registration, Hangfire setup, auto-migration
```

### Event flow

```
PlaceOrder API
    └─► TradingService.PlaceOrderAsync
            └─► MediatR: OrderPlacedEvent
                    └─► OrderPlacedEventHandler
                            └─► Hangfire.Enqueue<OrderMatchingJob>(companyId)
                                    └─► OrderMatchingService.MatchOrdersAsync
                                            └─► MediatR: TradeExecutedEvent
                                                    └─► NotificationService (trade alerts)
                                                    └─► SignalR: price update broadcast
```

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Node.js 18+](https://nodejs.org/)

---

## Quick Start

### 1. Start databases

```bash
docker compose up -d
```

Two PostgreSQL containers start:
- `localhost:5432` — main app DB (`stocklab`)
- `localhost:5433` — Hangfire job DB (`stocklab_hangfire`)

### 2. Run database migrations

```bash
# Install EF Core tools (one-time)
dotnet tool install --global dotnet-ef

cd StockLab
dotnet ef migrations add InitialCreate
dotnet ef database update
```

This creates all tables and seeds:
- 4 roles: `Admin`, `User`, `Bot`, `Issuer`
- Default admin: **username** `admin` / **password** `admin123`

### 3. Start the backend

```bash
cd StockLab
dotnet run
```

| Endpoint | URL |
|---|---|
| API | http://localhost:5147/api |
| Swagger | http://localhost:5147/swagger |
| Hangfire dashboard | http://localhost:5147/hangfire |

### 4. Start the frontend

```bash
cd StockLab_Client
npm install
npm run dev
```

Frontend runs at **http://localhost:5173**

---

## Key Features

### Trading
- Limit order book (BUY / SELL)
- Price-time priority matching engine
- Automatic refund of unspent balance on partial fills
- Volatility bounds check (orders outside ±volatility% are rejected)

### Bot Tournament
- Admin generates a season: creates N bots + bot-owned companies with IPO orders
- Starting tournament snapshots each bot's net worth as baseline
- `BotTradingJob` runs every 3s while tournament is ACTIVE — each tick a random bot picks a random company and places a BUY or SELL order
- At finalization, ROI is calculated per bot and ranked into tiers (Gold / Silver / Bronze / Wood)
- Tournament can be paused and resumed

### Market Dynamics
- **Overheat**: 15+ trades in 1 minute → volatility reduced by 5%
- **Stagnation**: no trades in 15+ minutes → volatility increased by 10% (capped at 50%)

### Analytics (real-time via SignalR)
- **Windrose chart** — bot performance grouped by Top 10% / Average / Bottom 10%, axes are greed, panic, memory, bet size, ROI
- **Market heatmap** — 24h price change per company, BULLISH / BEARISH sentiment
- **Top 5 active companies** — by trade count in last 24h

### Admin Panel
- User management: ban/unban, balance adjustment, create admin accounts
- Company management: IPO, update, delist
- Sector management
- JSON import / export of full market data
- System error logs
- Hangfire Dashboard link (job monitoring)

---

## Database Schema (key entities)

```
User ──< Order ──< Trade >── Order
User ──< PortfolioItem >── Company
User ──< UserNotification >── Notification
Company >── Sector
Company ──< PriceLog
Tournament ──< NetWorthSnapshot >── User (Bot)
Tournament ──< TournamentHistory >── User (Bot)
User (Bot) ── BotConfig
```

---

## Connection Strings

Configured in `StockLab/appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=stocklab;Username=stocklab;Password=stocklab123",
    "HangfireConnection": "Host=localhost;Port=5433;Database=stocklab_hangfire;Username=stocklab;Password=stocklab123"
  }
}
```

---

## Development Notes

- Migrations live in `StockLab/Migrations/` (auto-applied on startup via `db.Database.Migrate()`)
- Hangfire dashboard is open (no auth) in development — restrict in production
- Bot usernames follow the pattern `BOT_<name>`, bot-owned companies follow `ISSUER_<ticker>`
- All passwords are BCrypt-hashed (cost factor 11)
- The `refactor` branch contains the full Oracle → PostgreSQL/EF Core migration history
