# CAFFE POS — Sistem Kasir & Manajemen Kafe Modern

> Flutter-based Point of Sale (POS) system for Indonesian F&B businesses, with role-based access, inventory management, shift tracking, and Telegram bot notifications.

---

## Screenshots

> _Coming soon — add screenshots here (login screen, cashier view, owner dashboard, receipt)_

| Login | Cashier | Owner Dashboard |
|-------|---------|-----------------|
| ![login](docs/screenshots/login.png) | ![cashier](docs/screenshots/cashier.png) | ![owner](docs/screenshots/owner.png) |

---

## Features

### Cashier Role
- Browse menu by category and add items to cart
- Product modifier/customization support
- Payment processing with receipt generation
- Shift open/close management

### Owner Role
- Dashboard with sales overview and key metrics
- Product & category management (add, edit, delete)
- Inventory & raw material stock tracking
- Recipe management with ingredient cost calculation
- Sales reports with bar chart visualization
- Order history and shift reports
- Business settings & configuration

### Integrations
- **Telegram Bot Notifications** — real-time order and shift alerts via Telegram
  - Simulation (mock) mode for demo/development
  - Direct Bot API mode for testing
  - Relay Webhook via Cloudflare Worker for production
- **Receipt printing** — formatted receipt display per transaction

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) — SDK ^3.13.3 |
| UI Components | shadcn_flutter ^0.0.55 |
| Font | Nunito Sans |
| State Management | Provider |
| Storage | shared_preferences |
| HTTP | http ^1.6.0 |
| Localization | intl ^0.20.3 |
| Notifications | Telegram Bot API |

---

## Project Structure

```
lib/
├── data/           # Mock data for demo
├── models/         # Data models (Product, Order, Cart, Shift, User, etc.)
├── repositories/   # Data access layer
├── screens/
│   ├── cashier/    # Cashier role screens
│   ├── checkout/   # Payment & success screens
│   ├── order/      # Order management
│   ├── owner/      # Owner dashboard & management screens
│   ├── receipt/    # Receipt screen
│   └── shift/      # Shift closing screen
├── services/
│   ├── config/     # Business configuration service
│   ├── payment/    # Payment service (mock + interface)
│   └── telegram/   # Telegram bot integration services
├── state/          # App state (Provider)
├── theme/          # App theme & styling
├── utils/          # Helpers (cart calc, recipe calc, time, shift guard)
└── widgets/        # Reusable UI components
```

---

## Getting Started

### Prerequisites
- Flutter SDK ^3.13.3
- Dart SDK
- Android Studio / VS Code with Flutter extension

### Installation

```bash
# Clone the repository
git clone https://github.com/KarrelGustavHanafi/cafe-pos-demo.git
cd cafe-pos-demo

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Demo Credentials

| Role | Username | Password |
|------|----------|----------|
| Owner | `owner` | `owner123` |
| Cashier | `kasir` | `kasir123` |

> This project uses mock data. No backend or database setup required to run the demo.

---

## Telegram Integration Setup

See [TELEGRAM_SETUP.md](TELEGRAM_SETUP.md) for full configuration guide covering:
- Simulation (mock) mode — default for demo
- Direct Bot API — for testing with a real bot
- Relay Webhook via Cloudflare Worker — for production deployment

---

## Development Notes

- Built as a **demo/portfolio project** simulating a real-world F&B POS system
- All data is mock/in-memory — no real database connected
- Developed with AI-augmented workflow using **Hermes Agent** (Claude, ChatGPT, DeepSeek, Gemini)

---

## License

This project is for portfolio and demonstration purposes only.
