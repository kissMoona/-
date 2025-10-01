# Changelog

All notable changes to Π Grid Engine will be documented in this file.

## [1.30] - 2025-10-02

### 🚀 Major Feature: Multi-Symbol Trading Support

#### Added

- **Multi-Symbol Grid Trading**: `ManageLogic_Grid_MultiSymbol()` function that processes all enabled symbols simultaneously
- **Multi-Symbol Random Trading**: `ManageLogic_Random_MultiSymbol()` function that randomly selects from enabled symbols
- **Symbol-Specific Functions**:
  - `ManageLogic_Grid_ForSymbol()` - Individual symbol grid logic
  - `OpenOrderForSymbol_Grid()` - Grid order placement for specific symbols
  - `OpenOrderForSymbol_Random()` - Random order placement for specific symbols
  - `CheckAndOpenGridOrders_ForSymbol()` - Symbol-specific grid level checking
  - `HasOrderAtPrice_ForSymbol()` - Symbol-specific price level validation

#### Fixed

- **Critical Bug**: Multi-symbol trading now works correctly - previously only the current chart symbol was processed
- **Grid Trading**: Each enabled symbol now maintains its own independent grid structure
- **Random Trading**: Now randomly selects from all enabled symbols instead of only current chart symbol
- **Order Management**: Proper symbol-specific order tracking and management

#### Improved

- **Trading Logic**: Complete separation of single-symbol and multi-symbol trading logic
- **Price Handling**: Each symbol uses its own price data (`MarketInfo()` instead of `SymbolInfo()`)
- **Error Handling**: Enhanced error checking for invalid symbol prices
- **Logging**: More detailed logging with symbol-specific information

#### Technical Changes

- Maintained backward compatibility with original functions
- Added comprehensive multi-symbol support without breaking existing functionality
- Enhanced symbol selector interface integration
- Improved code organization with clear function separation

### 🎯 Impact
- **Before**: Only current chart symbol would trade, other enabled symbols were ignored
- **After**: All enabled symbols trade simultaneously according to selected mode (Grid/Random)
- **Grid Mode**: Each symbol maintains independent grid levels and auto-adds positions
- **Random Mode**: Randomly selects symbols from enabled list for each trade interval

---

## [1.25] - 2025-10-01

### Added

- **Comprehensive Server Information**: Added server name, account number, connection status, and trade permissions display
- **Enhanced Account Information**: Added free margin, leverage ratio, account currency, and account type (demo/real) display
- **Professional Information Alignment**: Implemented fixed-width column layout (40px labels, 90px values) for consistent alignment

### Improved

- **Symbol Selector Layout**: Optimized to 9 columns with better spacing (75px width, 5px spacing)
- **Panel Dimensions**: Increased panel height to 380px to accommodate new information
- **Button Positioning**: Adjusted control buttons to Y+390 for proper layout
- **Visual Consistency**: All panel sections now use uniform alignment for professional appearance

### Technical

- Enhanced UI responsiveness with better space utilization
- Improved code organization for information display functions
- Consistent styling across all panel components

---

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
