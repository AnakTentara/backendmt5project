# TradeMachine Dashboard API Documentation

**Version:** 3.0  
**Base URL:** `http://127.0.0.1:5000/api/`

---

## 📡 Authentication

No authentication required (local-only API). Add this comment for production use.

---

## 🔥 Brute Mode Commands

### Activate Brute Mode
```bash
POST /api/brute/on
Content-Type: application/json

{ }
```

**Response:**
```json
{
  "success": true,
  "action": "brute_on",
  "message": "Brute mode activated"
}
```

**Effect:** Starts aggressive scalping with ultra-tight SL.

---

### Deactivate Brute Mode
```bash
POST /api/brute/off
Content-Type: application/json

{ }
```

**Response:**
```json
{
  "success": true,
  "action": "brute_off",
  "message": "Brute mode deactivated"
}
```

**Effect:** Closes all brute positions and stops aggressive trading.

---

### Get Brute Mode Status
```bash
GET /api/brute/status
```

**Response:**
```json
{
  "active": true,
  "momentum_bullish": false,
  "momentum_bearish": true,
  "orders_this_min": 15,
  "max_orders_min": 60,
  "total_orders": 142,
  "reentry_count": 3,
  "sl_plus_locked": true,
  "locked_sl_plus": 245123.5,
  "sl_hit_pending": false,
  "session_pnl": 45.50,
  "ultra_tight_sl": 0.05,
  "reentry_delay": 2
}
```

---

## 🚨 Emergency Commands

### Emergency Stop (CRITICAL)
```bash
POST /api/emergency/stop
Content-Type: application/json

{ }
```

**Response:**
```json
{
  "success": true,
  "action": "emergency_stop",
  "priority": "critical"
}
```

**Effect:** Immediately closes ALL positions including regular trades. DO NOT USE DURING LIVE TRADING UNLESS EMERGENCY!

---

## ⚙️ Configuration Management

### Set Configuration Parameters
```bash
POST /api/config/set
Content-Type: application/json

{
  "max_orders_per_min": 30,
  "ultra_tight_sl": 0.08,
  "reentry_delay": 3,
  "fixed_lots": 0.02
}
```

**Valid Keys:**
- `max_orders_per_min` - Max orders per minute (1-100)
- `ultra_tight_sl` - Ultra-tight SL distance in points (0.00-0.10)
- `reentry_delay` - Delay after SL hit before re-entry (1-10 seconds)
- `reentry_max` - Maximum re-entries per sequence (1-20)
- `fixed_lots` - Fixed lot size or 0 for risk-based

**Invalid Key Example:**
```json
{
  "invalid_key": 123
}
// Returns: { "success": false, "error": "Invalid keys: [invalid_key]", "valid_keys": [...] }
```

---

## 📊 Data Endpoints

### List Recent Trades
```bash
GET /api/trades/list?limit=50
```

**Response:**
```json
{
  "trades": [
    {
      "id": "BRU_001",
      "type": "BUY",
      "entry": 245123.5,
      "exit": 245125.0,
      "lots": 0.01,
      "profit": 1.50,
      "time": "2026-08-29T10:30:00Z"
    }
  ],
  "total": 142,
  "pending": 3
}
```

---

### Session Metrics
```bash
GET /api/metrics/session
```

**Response:**
```json
{
  "total_trades": 142,
  "winning_trades": 89,
  "losing_trades": 53,
  "win_rate": 0.627,
  "total_profit": 125.50,
  "total_loss": -82.30,
  "net_profit": 43.20,
  "max_drawdown": 15.20,
  "sharpe_ratio": 1.85
}
```

---

### Symbol Information
```bash
GET /api/symbol/info
```

**Response:**
```json
{
  "symbol": "VOL_80",
  "price": 245234.5,
  "spread": 72,
  "volume_tick": 12345,
  "trend": "BULLISH",
  "support": 244800.0,
  "resistance": 245800.0
}
```

---

## 🔧 Health & Diagnostics

### Health Check
```bash
GET /api/health
```

**Response:**
```json
{
  "status": "ok",
  "service": "TradeMachine WebBridge",
  "timestamp": "2026-08-29T10:30:00Z",
  "cmd_file": "C:\\...\\TradeMachine_CMD.txt",
  "resp_file": "C:\\...\\TradeMachine_RESP.txt"
}
```

---

## 📝 Error Codes

| Code | Description | Action |
|------|-------------|--------|
| 400 | Bad Request | Check request format |
| 404 | Not Found | Endpoint doesn't exist |
| 405 | Method Not Allowed | Use correct HTTP method |
| 500 | Internal Server Error | Check server logs |

---

## 💻 cURL Examples

### Activate Brute Mode
```bash
curl -X POST http://127.0.0.1:5000/api/brute/on
```

### Get Status
```bash
curl http://127.0.0.1:5000/api/brute/status
```

### Emergency Stop
```bash
curl -X POST http://127.0.0.1:5000/api/emergency/stop
```

### Update Config
```bash
curl -X POST http://127.0.0.1:5000/api/config/set \
  -H "Content-Type: application/json" \
  -d '{"max_orders_per_min": 40}'
```

---

## 🛠️ Installation

```bash
cd MQL5\Scripts\TradeMachine
pip install -r requirements.txt
python WebBridge.py
```

API will be available at: `http://127.0.0.1:5000`

---

## 🔒 Security Notes

For **production deployment**:
1. Add basic authentication
2. Limit CORS to trusted origins only
3. Implement rate limiting
4. Enable logging of all requests
5. Consider adding token-based auth

---

*Document Version: 3.0 | Last Updated: 2026-08-29*