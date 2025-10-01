# Π Grid Engine v1.30 Release Notes

**Release Date**: 2025-10-02  
**Version**: 1.30  
**Previous Version**: 1.25

## 🎉 Major Release: Multi-Symbol Trading Support

### 🚀 What's New

**Multi-Symbol Trading Engine**
- 完全重构的多品种交易系统
- 支持同时在多个品种上运行网格和随机交易策略
- 每个品种独立维护自己的交易逻辑和网格结构

### 🔧 Key Features

#### 1. **多品种网格交易**
- 每个启用的品种都会独立运行网格策略
- 自动在网格位置加仓，无需手动干预
- 支持上涨追多、下跌追空的趋势网格模式

#### 2. **多品种随机交易**
- 从所有启用的品种中随机选择进行交易
- 按设定时间间隔执行随机交易
- 支持双向、只开多、只开空模式

#### 3. **智能品种管理**
- 可视化品种选择器，支持一键启用/禁用
- 绿色表示已启用，灰色表示未启用
- 当前图表品种用蓝色高亮显示

### 🛠️ Technical Improvements

#### 新增核心函数
```mql4
ManageLogic_Grid_MultiSymbol()     // 多品种网格交易主函数
ManageLogic_Random_MultiSymbol()   // 多品种随机交易主函数
ManageLogic_Grid_ForSymbol()       // 单品种网格交易逻辑
OpenOrderForSymbol_Grid()          // 品种专用网格开单
OpenOrderForSymbol_Random()        // 品种专用随机开单
CheckAndOpenGridOrders_ForSymbol() // 品种专用网格检查
HasOrderAtPrice_ForSymbol()        // 品种专用价格检查
```

#### 修复的关键问题
- **Critical Bug**: 修复了多品种交易不生效的问题
- **Grid Trading**: 每个品种现在都能正确维护独立的网格结构
- **Random Trading**: 随机交易现在会从所有启用品种中选择
- **Price Handling**: 每个品种使用自己的价格数据，避免价格混乱

### 📊 Performance Impact

**Before v1.30**:
- 只有当前图表品种会执行交易逻辑
- 其他启用的品种被忽略
- 多品种功能形同虚设

**After v1.30**:
- 所有启用品种同时运行交易策略
- 网格模式：每个品种独立维护网格位置
- 随机模式：从启用品种池中随机选择交易

### 🎯 How to Use

1. **启用品种**: 在品种选择器中点击需要交易的品种（变为绿色）
2. **选择模式**: 设置 `InpTradingMode` (0=网格, 1=随机)
3. **配置参数**: 设置网格间隔、随机间隔等参数
4. **开始交易**: EA会自动为所有启用品种执行交易策略

### 🔄 Backward Compatibility

- 完全向后兼容，现有配置无需修改
- 保留了原有的单品种交易函数
- 现有的界面和操作方式保持不变

### ⚠️ Important Notes

- 多品种交易会增加持仓数量，请注意风险管理
- 建议先在模拟账户测试多品种功能
- 确保有足够的保证金支持多品种交易
- 可以随时通过品种选择器启用/禁用特定品种

### 📈 Upgrade Instructions

1. 备份当前EA文件
2. 替换为新版本文件
3. 重新编译并加载到图表
4. 在品种选择器中选择需要交易的品种
5. 开始享受真正的多品种交易体验！

---

**感谢使用 Π Grid Engine！**  
如有问题或建议，请访问: https://github.com/kissMoona/-
