# Π Grid Engine

A professional dual-mode trading Expert Advisor for MetaTrader 4.

## 🎯 Features

### Trading Modes
- **Grid Trading Mode**: Automated grid-based trading with configurable step size
- **Random Trading Mode**: Time-interval based random direction trading

### Core Functions
- ✅ Dual trading mode support (Grid / Random)
- ✅ Bidirectional / Buy Only / Sell Only modes
- ✅ Breakeven protection
- ✅ Real-time information dashboard
- ✅ Multi-level alert system
- ✅ Daily statistics tracking
- ✅ One-click position closing

### Alert System
- Position count alerts
- Margin usage alerts
- Drawdown alerts

## 📊 Parameters

### Basic Settings
- **Magic Number**: 31415926 (π)
- **Trading Mode**: 0=Grid, 1=Random
- **Trading Hours**: Configurable start/end time

### Trading Parameters
- **Lot Size**: Base trading volume
- **Stop Loss**: Configurable in points
- **Take Profit**: Configurable in points
- **Breakeven**: Trailing stop protection

### Grid Trading
- **Grid Step**: Distance between grid levels (default: $10)

### Random Trading
- **Interval**: Time between random orders (default: 300s)

### Alerts
- **Max Orders Alert**: Position count threshold (default: 40)
- **Margin Alert**: Margin usage threshold (default: 80%)
- **Drawdown Alert**: Drawdown threshold (default: 15%)

## 🚀 Installation

1. Copy `Pi_Grid_Engine.mq4` to your MT4 `Experts` folder
2. Restart MT4 or refresh Expert Advisors
3. Drag the EA onto your chart
4. Configure parameters as needed
5. Enable AutoTrading

## 📈 Dashboard

The EA includes a real-time information panel showing:
- Long/Short positions
- Total positions and locked pairs
- Account balance and equity
- Floating P&L
- Margin usage
- Daily statistics
- Current trading mode
- Alert indicators

## 🎮 Interactive Controls

Three buttons for manual control:
- **Close All**: One-click close all positions
- **Buy Only**: Toggle buy-only mode
- **Sell Only**: Toggle sell-only mode

## 📝 Version History

### v1.20 (2025-10-01)
- Initial release
- Dual trading mode support
- Professional dashboard
- Alert system
- Daily statistics

## ⚠️ Risk Warning

Trading involves risk. This EA is provided for educational purposes. 
Always test on a demo account before using real money.

## 📄 License

Copyright 2024, Rex

## 🔗 Links

- GitHub: https://github.com/yourname/Pi_Grid_Engine
