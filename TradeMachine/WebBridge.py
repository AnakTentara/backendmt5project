#!/usr/bin/env python3
"""
WebBridge.py - Bridge for TradeMachine Dashboard
===============================================
Receives HTTP POST requests from dashboard and writes to MT5-readable files
"""

import os
import json
import time
from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Allow cross-origin requests from dashboard

# Configuration
TRADE_MACHINE_PATH = os.path.expanduser(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075")
DATA_DIR = os.path.join(TRADE_MACHINE_PATH, "Data")

# Ensure data directory exists
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

CMD_FILE = os.path.join(DATA_DIR, "TradeMachine_CMD.txt")
RESP_FILE = os.path.join(DATA_DIR, "TradeMachine_RESP.txt")


def write_command(command: str, payload: str = None):
    """Write command to file that MT5 can read"""
    cmd_json = {
        "command": command,
        "payload": payload or {},
        "timestamp": datetime.now().isoformat()
    }
    
    try:
        with open(CMD_FILE, 'w', encoding='utf-8') as f:
            json.dump(cmd_json, f)
        
        print(f"[CMD] Wrote: {command} -> {CMD_FILE}")
        return True
    except Exception as e:
        print(f"[ERROR] Failed to write command: {e}")
        return False


def write_response(status: str, message: str, data: dict = None):
    """Write response to file that MT5 can read"""
    resp = {
        "status": status,
        "message": message,
        "data": data or {},
        "timestamp": datetime.now().isoformat()
    }
    
    try:
        with open(RESP_FILE, 'w', encoding='utf-8') as f:
            json.dump(resp, f)
        
        print(f"[RESP] Wrote: {status} -> {RESP_FILE}")
        return True
    except Exception as e:
        print(f"[ERROR] Failed to write response: {e}")
        return False


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "ok",
        "service": "TradeMachine WebBridge",
        "timestamp": datetime.now().isoformat(),
        "cmd_file": CMD_FILE if os.path.exists(CMD_FILE) else "N/A",
        "resp_file": RESP_FILE if os.path.exists(RESP_FILE) else "N/A"
    })


@app.route('/api/brute/on', methods=['POST'])
def brute_on():
    """Activate Brute Mode"""
    print("[ACTION] Brute Mode ON requested")
    success = write_command("brute_on", {})
    return jsonify({"success": success, "action": "brute_on"})


@app.route('/api/brute/off', methods=['POST'])
def brute_off():
    """Deactivate Brute Mode"""
    print("[ACTION] Brute Mode OFF requested")
    success = write_command("brute_off", {})
    return jsonify({"success": success, "action": "brute_off"})


@app.route('/api/brute/status', methods=['GET'])
def brute_status():
    """Get Brute Mode Status"""
    print("[ACTION] Brute Mode Status requested")
    
    # MT5 will write actual status here via HTTPReceiver
    # For now, return dummy response
    return jsonify({
        "active": False,
        "momentum_bullish": False,
        "momentum_bearish": False,
        "orders_this_min": 0,
        "total_orders": 0,
        "sl_plus_locked": False,
        "session_pnl": 0.0,
        "ultra_tight_sl": 0.05,
        "reentry_delay": 2
    })


@app.route('/api/emergency/stop', methods=['POST'])
def emergency_stop():
    """Emergency Stop - Close all positions"""
    print("🚨 [EMERGENCY] Emergency Stop requested!")
    success = write_command("emergency_stop", {})
    return jsonify({"success": success, "action": "emergency_stop", "priority": "critical"})


@app.route('/api/config/set', methods=['POST'])
def set_config():
    """Set Configuration Parameters"""
    config_data = request.get_json()
    
    valid_keys = ["max_orders_per_min", "ultra_tight_sl", "reentry_delay", 
                  "reentry_max", "fixed_lots"]
    
    invalid_keys = [k for k in config_data.keys() if k not in valid_keys]
    if invalid_keys:
        return jsonify({"success": False, "error": f"Invalid keys: {invalid_keys}", "valid_keys": valid_keys})
    
    success = write_command("config_set", config_data)
    return jsonify({"success": success, "updated": config_data})


@app.route('/api/trades/list', methods=['GET'])
def list_trades():
    """List recent trades (requires MT5 integration for real data)"""
    # Placeholder - will implement later
    return jsonify({
        "trades": [],
        "total": 0,
        "pending": 0,
        "error": "Requires MT5 integration"
    })


@app.route('/api/metrics/session', methods=['GET'])
def get_session_metrics():
    """Get session metrics (requires MT5 integration)"""
    return jsonify({
        "total_trades": 0,
        "winning_trades": 0,
        "losing_trades": 0,
        "win_rate": 0.0,
        "total_profit": 0.0,
        "total_loss": 0.0,
        "max_drawdown": 0.0,
        "sharpe_ratio": 0.0,
        "error": "Requires MT5 integration"
    })


@app.route('/api/symbol/info', methods=['GET'])
def get_symbol_info():
    """Get current symbol information"""
    # Placeholder - will fetch from MT5 when integrated
    return jsonify({
        "symbol": "VOL_80",
        "price": 0,
        "spread": 0,
        "volume": 0,
        "error": "Requires MT5 integration"
    })


@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404


@app.errorhandler(405)
def method_not_allowed(error):
    return jsonify({"error": "Method not allowed"}), 405


@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500


# Startup message
print("=" * 60)
print("TradeMachine WebBridge")
print("=" * 60)
print(f"Command File: {CMD_FILE}")
print(f"Response File: {RESP_FILE}")
print(f"Flask running on http://127.0.0.1:5000")
print("=" * 60)


if __name__ == '__main__':
    # Run Flask development server
    app.run(host='127.0.0.1', port=5000, debug=False, use_reloader=False)
