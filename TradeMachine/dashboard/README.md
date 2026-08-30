# TradeMachine Dashboard

Frontend for the TradeMachine VOL_80 trading engine. Talks to the Flask
`WebBridge.py` on `127.0.0.1:5000`.

## Setup

```bash
cd Scripts/TradeMachine/dashboard
npm install
cp .env.example .env      # then edit if needed
npm run dev               # http://127.0.0.1:5173
```

By default `VITE_USE_MOCK_API=true`, so the dashboard runs on simulated data and
needs no backend. Set it to `false` once the bridge is running:

```bash
python WebBridge.py       # from Scripts/TradeMachine
```

### Scripts

| Command | Purpose |
|---|---|
| `npm run dev` | Dev server with HMR |
| `npm run build` | Typecheck then production build to `dist/` |
| `npm run typecheck` | Types only |
| `npm run lint` | ESLint, zero warnings tolerated |
| `npm run tokens:dart` | Regenerate the Flutter theme from design tokens |

`dist/` is a plain static bundle. Flask can serve it directly; no Node runtime
is needed in production.

## Architecture

```
src/
  api/          Transport boundary. Contracts, HTTP client, repositories.
  config/       Environment parsing and validation.
  design/       Design tokens — the single source of truth for visuals.
  domain/       Constants, formatters, selectors. Pure logic, no React.
  hooks/        TanStack Query hooks. The only way components get server state.
  components/   Presentational primitives.
  features/     Feature-first modules, mirroring Flutter's lib/features/.
  layout/       App shell.
  pages/        Route compositions.
```

Two rules hold the structure together:

1. **Nothing outside `src/api/` performs I/O.** Components consume hooks; hooks
   consume the repository interface. No component imports `fetch` or a URL.
2. **Nothing outside `src/design/tokens.ts` defines a colour.** Hex literals in
   components are a bug — they bypass the token pipeline and never reach the
   generated Flutter theme.

### Data flow

```
Component → hook (TanStack Query) → repository interface
                                      ├── HttpTradeMachineRepository → Zod → Flask
                                      └── MockTradeMachineRepository → Zod → fixtures
```

Both repositories parse through the *same* schemas, so the mock cannot drift
into fiction: a contract change breaks both.

## Backend state as of this build

Four endpoints are still placeholders on the backend, three of them returning
`"error": "Requires MT5 integration"`. The dashboard surfaces this rather than
hiding it — affected figures render with a `~` marker and a note.

| Endpoint | State |
|---|---|
| `GET /api/health` | Working |
| `POST /api/brute/on` \| `off` | Working (writes command file) |
| `POST /api/emergency/stop` | Working (writes command file) |
| `POST /api/config/set` | Partial — see below |
| `GET /api/brute/status` | **Stub** — hardcoded, never reads `TradeMachine_RESP.txt` |
| `GET /api/trades/list` | **Stub** |
| `GET /api/metrics/session` | **Stub** |
| `GET /api/symbol/info` | **Stub** |

### Known backend issues the UI works around

These were found while building against the MQL5 source. Each is handled at the
contract layer rather than patched over in components:

1. **Config keys are mostly ignored.** Flask validates all five keys, but
   `ParseConfigChange()` in `HTTPReceiver.mqh` only parses `max_orders`. The
   other four are acknowledged with `success: true` and discarded. The config
   form marks them `NOT APPLIED`.
2. **Command name mismatch.** `Types.mqh` defines `"set_config"`; both
   `HTTPReceiver.mqh` and `WebBridge.py` use `"config_set"`.
3. **Field name drift.** `/api/symbol/info` is documented as returning
   `volume_tick` but returns `volume`. The schema accepts both.
4. **`net_profit` is documented but not implemented.** Derived client-side from
   profit and loss when absent.
5. **Port mismatch.** `Config.mqh` declares `Inp_HTTP_Port = 8080`; the Flask
   bridge listens on 5000. The dashboard targets 5000.
6. **Margin thresholds appear inverted.** `Inp_MarginCloseLevel` (300%) sits
   above `Inp_MarginAlertLevel` (200%), so positions would force-close before
   any warning fires. The Risk page displays the values as configured and flags
   the contradiction rather than silently reordering them.

### Security

The bridge has **no authentication** and runs `CORS(app)` fully open. Anything
that can reach port 5000 can trigger an emergency stop, which closes every open
position at market. Keep it bound to loopback. Before exposing it to any
network, the backend needs auth, origin restriction, and rate limiting.

## Design decisions worth knowing

**Teal/amber instead of green/red.** Roughly 1 in 12 men has a red-green colour
vision deficiency, and profit/loss is the most consequential signal here.
Direction is additionally encoded with arrow glyphs and sign prefixes, so colour
is never the only carrier of meaning.

**Monospace tabular numerals for every figure.** Values update once per second;
proportional digits would make columns twitch.

**No optimistic UI on commands.** A `success` response only means Flask wrote the
command file. MT5 polls it on its own 1-second cycle and may reject it. Flipping
a toggle immediately would assert a state the engine has not reached, so the UI
shows "queued" and waits for the next status poll to confirm.

**Emergency stop is deliberately slow.** Modal, plain-language consequences, and
a 2-second arming delay that defeats double-click muscle memory. Focus lands on
Cancel, not Confirm. It is irreversible and closes regular trades too.

**Spread has permanent screen real estate.** At ~72pts on VOL_80, a round trip
pays ~144pts before it profits. That cost drives whether trading is viable at
all, so it is never more than a glance away.

## Porting to Flutter

The React code itself does not port — but four things do, and they were built
for it:

### 1. Design tokens → `ThemeData`

```bash
npm run tokens:dart      # writes generated/app_theme.dart
```

Copy that file into the Flutter project. Every colour, spacing value, radius,
and type-scale entry comes across. Re-run after any token change; never hand-edit
the generated file.

### 2. API contracts → Dart models

`src/api/contracts.ts` is the wire-format specification. Each schema maps 1:1 to
a Dart model. Conventions chosen to make it mechanical:

- `snake_case` → `camelCase` renaming happens once, in each schema's
  `.transform()`. Mirror it in `fromJson`.
- Tolerant defaults (`.catch()`) instead of optionals wherever a sensible zero
  exists, so Dart null-safety does not have to thread nullables through the UI.
- Timestamps stay ISO-8601 strings, matching `DateTime.parse`.

```dart
// Example: BruteStatus
factory BruteStatus.fromJson(Map<String, dynamic> json) => BruteStatus(
      isActive: json['active'] as bool? ?? false,
      ordersThisMinute: (json['orders_this_min'] as num?)?.toInt() ?? 0,
      // ...
    );
```

### 3. Repository interface → Dart abstract class

`src/api/repository.ts` is already the shape of the Dart abstraction:

```dart
abstract class TradeMachineRepository {
  Future<HealthStatus> getHealth();
  Future<BruteStatus> getBruteStatus();
  Future<CommandAck> setBruteMode(bool active);
  Future<CommandAck> emergencyStop();
  Future<CommandAck> updateConfig(ConfigUpdate update);
  Future<TradeList> getTrades(int limit);
  Future<SessionMetrics> getSessionMetrics();
  Future<SymbolInfo> getSymbolInfo();
}
```

Implement it over `package:http`, register with `get_it`, and swap the hooks for
Riverpod providers. No call sites move.

### 4. Domain logic → copy nearly verbatim

`src/domain/selectors.ts` and `formatters.ts` are pure functions with no React
dependency. `assessSpread`, `maxLotsForBalance`, `ticketsRequired`,
`capitalPhaseProgress` translate to Dart almost line for line. `Intl.NumberFormat`
maps onto `package:intl`'s `NumberFormat`.

### What does not port

Charts. `lightweight-charts` has no Flutter equivalent — use `fl_chart` or
`k_chart` instead. Chart usage is isolated behind wrapper components so pages do
not need restructuring.

### Android-specific note

`127.0.0.1` on an Android device refers to the device itself, not your machine.
Use `10.0.2.2` for the emulator, or the host's LAN IP for a physical device —
and since the bridge has no authentication, do not put it on an untrusted
network without adding auth first.
