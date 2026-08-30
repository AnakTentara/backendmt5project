# TradeMachine v3.0 - VOL_80 Aggressive Trading System

[![Status](https://img.shields.io/badge/Status-Production%20Beta-blue)](https://haikaldev.my.id) [![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-green)](https://www.metaquotes.net/metatrader5) [![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://python.org)

## 🚀 Overview

Advanced algorithmic trading system for **VOL_80 (Volatility 80 Index)** on Deriv/MT5. Features aggressive brute mode scalping, multi-ticket support, and HTTP dashboard integration.

**Key Features:**
- ✅ Multi-timeframe analysis (M5 → H4)
- ✅ Pattern detection (Flag, Consolidation, CHOCH)
- ✅ Supply/Demand zones with 1:1 bounce/retest logic
- ✅ Ultra-tight SL brute mode (0.00-0.10 pts)
- ✅ Position cap handling (100-lot limit)
- ✅ HTTP POST command receiver for web dashboard
- ✅ Error handling & performance monitoring

---

## 📋 Installation Guide

### Prerequisites
- MetaTrader 5 terminal installed
- Python 3.10+ installed
- Access to Deriv broker account (or compatible)

### Step 1: Install MT5 Modules
1. Open MetaEditor in MT5
2. Copy all `.mqh` files to `MQL5\Scripts\TradeMachine\`
3. Copy `TradeMachine.mq5` as your Expert Advisor
4. Compile successfully (no errors/warnings)

### Step 2: Install Python Dependencies
```bash
cd MQL5\Scripts\TradeMachine
pip install -r requirements.txt
```

Verify Flask is installed:
```bash
python -c "import flask; print('Flask:', flask.__version__)"
```

### Step 3: Run WebBridge
```bash
python WebBridge.py
```

Expected output:
```
============================================================
TradeMachine WebBridge
============================================================
Command File: C:\...\TradeMachine_CMD.txt
Response File: C:\...\TradeMachine_RESP.txt
Flask running on http://127.0.0.1:5000
============================================================
```

Keep this window open while trading!

### Step 4: Configure EA Settings
1. In MT5, add **VOL_80** to Market Watch (Ctrl + U)
2. Open **TradeMachine** EA properties
3. Set inputs:
   - Max risk per trade: **1-3%**
   - Use spread filter: **Enabled**
   - Brute mode initial state: **Disabled** (activate via dashboard later)
4. Allow live trading: **Yes**
5. Auto-start: **Optional** (recommend manual start after testing)

### Step 5: Test Setup
Run pyScript to verify VOL_80 specs:
```bash
python pyScript.py
```

Expected output includes leverage table showing minimum 1:245 required.

---

## 🔥 Brute Mode Activation

Brute mode requires dashboard control for safety. Here's how to activate it:

### Method 1: Dashboard Web Interface (Recommended)
1. Start WebBridge: `python WebBridge.py`
2. Open browser to: `http://localhost:5000` (dashboard coming soon)
3. Click **"Activate Brute Mode"** button
4. Monitor activity and adjust parameters via API

### Method 2: Direct HTTP Command (Testing)
```bash
curl -X POST http://127.0.0.1:5000/api/brute/on
```

Response should show `"success": true`.

### Method 3: Manual Testing (Standalone)
For standalone testing without full dashboard:
1. Open **BruteTest_EA.mq5** in Strategy Tester
2. Run test on VOL_80 M5 chart
3. Observe automatic activation and behavior

### Deactivating Brute Mode
```bash
curl -X POST http://127.0.0.1:5000/api/brute/off
```

Or from dashboard UI.

---

## ⚙️ Configuration Parameters

### Critical Settings
| Parameter | Default | Recommended Range | Description |
|-----------|---------|-------------------|-------------|
| `Inp_MaxRiskPercent` | 3.0 | 1.0 - 5.0 | Risk % per trade |
| `Inp_Brute_UltraTightSL` | 0.05 | 0.01 - 0.10 pts | SL distance for brute |
| `Inp_Brute_MaxOrdersPerMin` | 20 | 10 - 60 | Rate limit |
| `Inp_Brute_ReentryOnSL` | true | true/false | Re-enter after SL hit |
| `Inp_Brute_SLPlusLock` | true | true/false | Lock midpoint SL on reversal |

### Advanced Settings
See `Config.mqh` for complete parameter list with descriptions.

---

## 📊 Monitoring & Alerts

### Real-time Dashboard Metrics
Access via WebBridge API endpoints:

```bash
GET /api/brute/status         # Current brute status
GET /api/metrics/session      # Session performance
GET /api/symbol/info          # Live symbol data
```

### Log Files Location
```
MQL5\Data\Terminal_Dir\TradeMachine_Log.csv
MQL5\Data\Terminal_Dir\TradeMachine_Errors.csv
MQL5\Data\Terminal_Dir\TradeMachine_ErrorLog.txt
```

### Alert Triggers
- Margin level < 200% ⚠️ Warning
- Margin level < 100% 🚨 Critical - auto-close
- Spread > 150 pts 🛑 Pause trading
- Too many consecutive errors 🔄 Panic mode

---

## 🎯 Backtesting & Validation

### Required Data
- Minimum 6 months VOL_80 M5 historical data
- Walk-forward validation (70/30 train/test split)

### Performance Targets
| Metric | Target | Acceptable |
|--------|--------|------------|
| Profit Factor | > 1.5 | > 1.2 |
| Win Rate | > 50% | > 40% |
| Max Drawdown | < 20% | < 30% |
| Expectancy | > 0.5R | > 0.3R |

### Steps
1. Run Strategy Tester with default parameters
2. Optimize key settings (ultra_tight_sl, max_orders_per_min)
3. Walk-forward validate monthly
4. Forward test demo for 2 weeks minimum

---

## 🆘 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Cannot connect to WebBridge" | Ensure WebBridge.py running on port 5000 |
| "Symbol not found" | Add VOL_80 to Market Watch first |
| "Spread too wide" | Adjust Inp_Brute_MinBodyRatio lower or pause trading |
| "Invalid trade parameters" | Check leverage ≥ 1:245 requirement |
| "Margin call" | Reduce Inp_MaxRiskPercent or increase account size |
| "Order rejected" | Verify SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOP_LEVEL) |

### Debug Commands
```bash
# Get current status
curl http://127.0.0.1:5000/api/brute/status

# Emergency stop
curl -X POST http://127.0.0.1:5000/api/emergency/stop

# Check health
curl http://127.0.0.1:5000/api/health
```

---

## 🔒 Safety & Risk Management

⚠️ **CRITICAL SAFETY REMINDERS:**

1. **Leverage Requirement**: Minimum 1:245 recommended, 1:2000 preferred
2. **Margin Safety**: Always maintain > 300% margin level
3. **Spread Limits**: Do not trade if spread > 100 points
4. **Emergency Stop**: Know how to trigger immediately
5. **Position Caps**: 100 lots max per ticket (multi-ticket splits available)
6. **Daily Loss Limit**: Consider implementing manual circuit breaker

---

## 📱 Development Status

| Component | Status | Notes |
|-----------|--------|-------|
| Core Engine | ✅ Complete | All modules implemented |
| Brute Mode | ✅ Complete | Full logic with re-entry |
| HTTP Receiver | ✅ Complete | File-based bridge |
| WebBridge API | ✅ Complete | Flask server ready |
| Dashboard UI | 🔴 Planned | Coming in v3.1 |
| Backtesting | ⏳ Pending | User needs to run tests |
| Live Testing | ⏳ Pending | Demo testing required |

---

## 📞 Support & Resources

- **Author**: HaikalDev
- **Website**: https://haikaldev.my.id
- **Documentation**: See TRADING_PLAN.md and Dashboard_API.md
- **Version**: 3.0.0 Beta
- **Last Updated**: 2026-08-29

---

## 📜 License

This software is provided "as is" for educational purposes only. Trading involves significant risk of loss. Use at your own discretion.

**DISCLAIMER**: This is a beta product. Use caution when deploying with real funds. Start with small position sizes and demo accounts.

---

## 🔮 Future Roadmap

v3.1 (Planned):
- [ ] React/Vue dashboard frontend
- [ ] WebSocket real-time streaming
- [ ] Email/Push notifications
- [ ] Performance analytics charts
- [ ] Mobile app integration

v3.2 (Vision):
- [ ] Multi-symbol support
- [ ] Machine learning enhancement (optional)
- [ ] Cloud backup of trade history
- [ ] Social trading features

---

*Happy Trading! May your wins be many and losses few.* 🚀📈