# Changelog

All notable changes to Π Grid Engine will be documented in this file.

## [1.21] - 2025-10-01

### Fixed

- **Panel Button Display Issue**: Fixed buttons not showing on the information panel
  - Adjusted button positions from Y+280 to Y+330 (below panel background)
  - Reduced panel background height from 350 to 320 pixels
  - Fixed button visibility by setting `OBJPROP_HIDDEN = false`
  - Added `OBJPROP_ZORDER = 1` to ensure buttons appear on top
  - Added `EnsureButtonsExist()` function to recreate buttons if they disappear

- **Button State Management**: Improved button click responsiveness
  - Fixed button state reset immediately after click events
  - Enhanced visual feedback with immediate color updates
  - Prevented buttons from getting stuck in pressed state
  - Added `ChartRedraw()` calls for instant visual updates

### Changed

- **Default Settings**: Updated default parameter values for better user experience
  - Set `InpEnableAlerts = false` (disabled alerts by default)
  - Set `InpEnableDailyLossLimit = false` (disabled daily loss limit by default)

### Technical Improvements

- Enhanced button layer management with proper Z-order
- Improved button recreation mechanism for runtime stability
- Optimized chart redraw calls for better performance

---

## [1.20] - 2025-10-01

### Added

- Initial release of Π Grid Engine
- Grid trading mode with configurable step size
- Random trading mode with time intervals
- Dual mode support (Bidirectional / Buy Only / Sell Only)
- Real-time information dashboard with statistics
- Interactive control buttons (Close All / Buy Only / Sell Only)
- Multi-level alert system (Position / Margin / Drawdown)
- Daily statistics tracking with auto-reset
- Breakeven protection system
- Professional logging system with categorized tags
- Magic number: 31415926 (π)

### Features

- Grid trading with automatic level management
- Random trading with configurable intervals
- Locked pair detection and display
- Maximum position tracking
- Today's order count and P&L
- Margin usage monitoring
- Real-time alert notifications
- Trading time control
- Parameter hot-reload support

### Technical

- Clean code architecture
- Comprehensive error handling
- Optimized performance
- Professional UI design
- English logging for debugging
- Modular function design

---

## Future Plans

### v1.30 (Planned)

- [ ] Maximum position limit
- [ ] Profit lock mechanism
- [ ] Auto-close locked pairs
- [ ] Partial take profit
- [ ] Dynamic grid adjustment
- [ ] Volatility-based grid sizing

### v1.40 (Planned)

- [ ] Multi-timeframe support
- [ ] Advanced statistics
- [ ] Trade history export
- [ ] Performance analytics
- [ ] Risk management enhancements

---

**Note**: This project follows [Semantic Versioning](https://semver.org/).
