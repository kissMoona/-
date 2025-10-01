//+------------------------------------------------------------------+
//|                            Pi_Grid_Engine.mq4                    |
//|                           Copyright 2024, Rex                    |
//+------------------------------------------------------------------+
//| VERSION HISTORY:                                                 |
//| v1.30 (2025-10-02) - 多品种交易支持                              |
//|   ✓ 修复多品种交易中随机和网格交易不生效的问题                    |
//|   ✓ 新增 ManageLogic_Grid_MultiSymbol() 函数                    |
//|   ✓ 新增 ManageLogic_Random_MultiSymbol() 函数                  |
//|   ✓ 新增品种专用开单函数 OpenOrderForSymbol_Grid/Random()        |
//|   ✓ 新增品种专用网格检查函数 CheckAndOpenGridOrders_ForSymbol()  |
//|   ✓ 支持多品种同时运行网格和随机交易策略                          |
//|   ✓ 优化品种选择器界面和交互体验                                  |
//|                                                                  |
//| v1.25 (Previous) - 基础网格和随机交易系统                        |
//|   • 双模式交易系统（网格/随机）                                   |
//|   • 品种选择器界面                                               |
//|   • 基础风控和统计功能                                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Rex"
#property link      "https://github.com/kissMoona/-"
#property version   "1.30"
#property description "Π Grid Engine - Multi-Symbol Trading System"
#property strict

//--- 输入参数
//--- 面板设置
input bool   InpShowPanel = true;          // 是否显示信息面板
input int    InpPanelX = 150;               // 面板X轴位置
input int    InpPanelY = 100;               // 面板Y轴位置
//--- 基础设置
input int    InpMagicNo = 31415926;        // Magic Number
input int    InpTradingMode = 0;           // Trading Mode (0=Grid, 1=Random)
input string InpStartTime = "00:00";       // Start Time
input string InpEndTime = "23:59";         // End Time

//--- 交易参数
input double InpLotSize = 0.01;            // 基础交易手数
input int    InpBaseSL = 0;                // 基础止损点数
input int    InpBaseTP = 0;                // 基础止盈点数
input int    InpTPA = 0;                   // 保本损（点数）

//--- 网格交易参数
input double InpGridStep = 10.0;           // 网格间隔（美元）

//--- 随机交易参数
input int    InpRandomInterval = 300;       // 随机交易间隔（秒）

//--- 警报设置
input bool   InpEnableAlerts = false;       // 启用警报
input int    InpMaxOrdersAlert = 40;       // 持仓数警报阈值
input double InpMarginAlert = 80.0;        // 保证金使用率警报(%)
input double InpDrawdownAlert = 15.0;      // 浮亏百分比警报(%)

//--- 风险控制
input double InpMaxDailyLoss = 100.0;      // 日最大亏损($)
input bool   InpEnableDailyLossLimit = false; // 启用日亏损限制

// Telegram功能已简化

//--- 全局变量
datetime g_last_trade_time = 0; // 用于存储最后开仓时间
double g_first_order_price = 0.0; // 第一个订单的开仓价格
int g_first_order_type = -1; // 第一个订单的类型（OP_BUY 或 OP_SELL）
int g_trade_mode = 0; // 交易模式：0=双向，1=只开多，2=只开空

//--- 统计变量
int g_today_orders = 0; // 今日开单数
double g_today_profit = 0.0; // 今日盈亏
int g_max_positions = 0; // 历史最大持仓数
datetime g_last_reset_date = 0; // 上次重置日期
double g_day_start_balance = 0.0; // 当日开始余额

//--- 品种选择器变量
string g_available_symbols[]; // 可用品种列表
bool g_symbol_enabled[]; // 品种是否启用交易
bool g_symbol_first_order_opened[]; // 品种是否已开首单
int g_symbol_scroll_offset = 0; // 滚动偏移量
int g_symbols_per_row = 4; // 每行显示品种数
int g_symbol_rows = 4; // 显示行数
int g_symbols_per_page = 16; // 每页显示品种数 (4x4)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- 初始化随机数生成器
    MathSrand(GetTickCount());

    //--- 初始化计时器
    g_last_trade_time = 0;
    g_first_order_price = 0.0;
    g_first_order_type = -1;
    
    //--- 初始化统计变量
    g_today_orders = 0;
    g_today_profit = 0.0;
    g_max_positions = 0;
    g_last_reset_date = TimeCurrent();
    g_day_start_balance = AccountBalance();
    
    //--- 初始化品种列表
    LoadAvailableSymbols();

    Print("[INIT] Π Grid Engine v1.30 Started - Multi-Symbol Support");
    if(InpTradingMode == 0)
        Print("[INIT] Mode: Grid Trading | Grid Step: $", InpGridStep);
    else
        Print("[INIT] Mode: Random Trading | Interval: ", InpRandomInterval, "s");
    
    //--- 创建按钮（使用中性颜色）
    if(InpShowPanel)
    {
        // 操作按钮（放在面板外部下方，确保可见）
        CreateButton("YDA_Btn_CloseAll", InpPanelX + 10, InpPanelY + 390, 140, 28, "一键平仓", clrWhite, C'180,50,50');
        CreateButton("YDA_Btn_BuyOnly", InpPanelX + 160, InpPanelY + 390, 140, 28, "只开多", clrWhite, C'60,60,80');
        CreateButton("YDA_Btn_SellOnly", InpPanelX + 310, InpPanelY + 390, 140, 28, "只开空", clrWhite, C'60,60,80');
        
        
        // 品种选择器说明文字（不需要翻页按钮了）
        // 所有品种一次性显示
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("[DEINIT] Π Grid Engine Stopped | Reason Code: ", reason);
    
    //--- 保存品种启用状态（除非是账户切换或删除EA）
    if(reason != REASON_ACCOUNT && reason != REASON_REMOVE)
    {
        SaveSymbolStates();
    }
    
    //--- 清理面板对象
    if(InpShowPanel)
    {
        ObjectsDeleteAll(0, "YDA_Panel_");
        ObjectsDeleteAll(0, "YDA_Btn_");
        ObjectsDeleteAll(0, "YDA_Sidebar_");
        ObjectsDeleteAll(0, "YDA_SymbolSelector_");
        ObjectDelete(0, "YDA_Panel_BG");
        ObjectDelete(0, "YDA_Sidebar_BG");
        ObjectDelete(0, "YDA_SymbolSelector_BG");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- 检查并更新现有订单的SL/TP
    UpdateOrdersOnParameterChange();

    //--- 检查是否需要重置每日统计
    CheckDailyReset();
    
    //--- 更新面板
    if(InpShowPanel)
    {
        UpdateDashboard();
        DisplaySymbolSelector(InpPanelX, InpPanelY);
    }
    
    //--- 检查警报
    if(InpEnableAlerts)
        CheckAlerts();

    //--- 管理保本损 (Breakeven)
    ManageTrailingStop();

    //--- 检查是否在交易时间内 (只对开仓有效)
    if(!IsTradeTime())
        return;
    
    //--- 检查日亏损限制
    if(!CheckDailyLossLimit())
        return;

    //--- 执行交易逻辑（支持多品种）
    if(InpTradingMode == 0)
        ManageLogic_Grid_MultiSymbol();  // 多品种网格交易
    else
        ManageLogic_Random_MultiSymbol(); // 多品种随机交易
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    //--- 处理按钮点击事件
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        Print("[EVENT] Button clicked: ", sparam);  // 调试信息
        
        if(sparam == "YDA_Btn_CloseAll")
        {
            // 立即重置按钮状态
            ObjectSetInteger(0, "YDA_Btn_CloseAll", OBJPROP_STATE, false);
            PlaySound("alert.wav");
            CloseAllPositions();
        }
        else if(sparam == "YDA_Btn_BuyOnly")
        {
            // 立即重置按钮状态
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_STATE, false);
            PlaySound("ok.wav");
            ToggleBuyOnlyMode();
            // 立即更新按钮显示
            UpdateButtonStates();
            ChartRedraw();
        }
        else if(sparam == "YDA_Btn_SellOnly")
        {
            // 立即重置按钮状态
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_STATE, false);
            PlaySound("ok.wav");
            ToggleSellOnlyMode();
            // 立即更新按钮显示
            UpdateButtonStates();
            ChartRedraw();
        }
        // 手数调整按钮已移除
        else if(StringFind(sparam, "YDA_Btn_Symbol_") == 0)
        {
            // 品种按钮点击 - 切换启用/禁用
            string idx_str = StringSubstr(sparam, 15); // 提取索引
            int idx = (int)StringToInteger(idx_str);
            if(idx >= 0 && idx < ArraySize(g_available_symbols))
            {
                // 立即重置按钮状态
                ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
                
                // 播放点击音效
                PlaySound("tick.wav");
                
                // 先更新颜色（即时视觉反馈）
                bool will_enable = !g_symbol_enabled[idx];
                UpdateSymbolButtonColor(idx, will_enable);
                
                // 强制刷新图表
                ChartRedraw();
                
                // 然后执行开单/平仓操作（异步）
                ToggleSymbol(idx);
            }
        }
    }
}


//+------------------------------------------------------------------+
//| 获取持仓统计信息（统计所有启用品种）                              |
//+------------------------------------------------------------------+
void GetPositionStats(int &long_pos, int &short_pos, double &total_pl)
{
    long_pos = 0;
    short_pos = 0;
    total_pl = 0.0;
    
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == InpMagicNo)
            {
                // 检查订单品种是否在启用列表中
                string order_symbol = OrderSymbol();
                bool is_enabled_symbol = false;
                
                for(int j = 0; j < ArraySize(g_available_symbols); j++)
                {
                    if(g_available_symbols[j] == order_symbol && g_symbol_enabled[j])
                    {
                        is_enabled_symbol = true;
                        break;
                    }
                }
                
                // 只统计已启用品种的订单
                if(is_enabled_symbol)
                {
                    if(OrderType() == OP_BUY)
                        long_pos++;
                    else if(OrderType() == OP_SELL)
                        short_pos++;
                        
                    total_pl += OrderProfit() + OrderSwap() + OrderCommission();
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 生成订单备注                                                      |
//+------------------------------------------------------------------+
string GenerateOrderComment(string prefix, string symbol_name, int order_number)
{
    // 格式：[模式]-品种-序号-日期时间
    // 例如：Grid-XAUUSD-#15-1001_1046
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    string time_str = StringFormat("%02d%02d_%02d%02d", 
        dt.mon, dt.day, dt.hour, dt.min);
    
    string comment = StringFormat("%s-%s-#%d-%s", 
        prefix, symbol_name, order_number, time_str);
    
    return comment;
}

//+------------------------------------------------------------------+
//| 多品种网格交易逻辑                                                |
//+------------------------------------------------------------------+
void ManageLogic_Grid_MultiSymbol()
{
    // 遍历所有启用的品种
    for(int symbol_idx = 0; symbol_idx < ArraySize(g_available_symbols); symbol_idx++)
    {
        if(!g_symbol_enabled[symbol_idx]) continue; // 跳过未启用的品种
        
        string symbol = g_available_symbols[symbol_idx];
        ManageLogic_Grid_ForSymbol(symbol, symbol_idx);
    }
}

//+------------------------------------------------------------------+
//| 单个品种的网格交易逻辑                                            |
//+------------------------------------------------------------------+
void ManageLogic_Grid_ForSymbol(string symbol, int symbol_idx)
{
    int magic_number = InpMagicNo;
    
    // 获取品种价格
    double ask = MarketInfo(symbol, MODE_ASK);
    double bid = MarketInfo(symbol, MODE_BID);
    if(ask == 0 || bid == 0) return; // 价格无效
    
    double current_price = (ask + bid) / 2.0;
    
    //--- 检查该品种是否有持仓
    int total_orders = 0;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == symbol && OrderMagicNumber() == magic_number)
            {
                total_orders++;
            }
        }
    }
    
    //--- 如果没有持仓且未开过首单，开第一个订单
    if(total_orders == 0 && !g_symbol_first_order_opened[symbol_idx])
    {
        int direction;
        if(g_trade_mode == 1) // 只开多
            direction = OP_BUY;
        else if(g_trade_mode == 2) // 只开空
            direction = OP_SELL;
        else // 双向模式
            direction = (MathRand() % 2 == 0) ? OP_BUY : OP_SELL;
            
        string comment = GenerateOrderComment("Grid", symbol, 1);
        if(OpenOrderForSymbol_Grid(symbol, direction, current_price, comment))
        {
            g_today_orders++;
            g_symbol_first_order_opened[symbol_idx] = true; // 标记已开首单
            Print("═══ [网格] 首单开启 ═══ ", symbol, " | ", (direction == OP_BUY ? "多单" : "空单"), " | 价格: ", DoubleToString(current_price, (int)MarketInfo(symbol, MODE_DIGITS)));
        }
        return;
    }
    
    //--- 检查是否需要在网格位置开新单
    CheckAndOpenGridOrders_ForSymbol(symbol, current_price);
}

//+------------------------------------------------------------------+
//| 网格交易逻辑（保持原有逻辑用于当前品种）                          |
//+------------------------------------------------------------------+
void ManageLogic_Grid()
{
    int magic_number = InpMagicNo;
    double current_price = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) + SymbolInfoDouble(Symbol(), SYMBOL_BID)) / 2.0;
    
    //--- 获取当前品种索引
    int symbol_idx = -1;
    for(int i = 0; i < ArraySize(g_available_symbols); i++)
    {
        if(g_available_symbols[i] == Symbol())
        {
            symbol_idx = i;
            break;
        }
    }
    
    if(symbol_idx < 0) return; // 品种未找到
    
    //--- 检查是否有持仓
    int total_orders = 0;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            {
                total_orders++;
            }
        }
    }
    
    //--- 如果没有持仓且未开过首单，开第一个订单
    if(total_orders == 0 && !g_symbol_first_order_opened[symbol_idx])
    {
        int direction;
        if(g_trade_mode == 1) // 只开多
            direction = OP_BUY;
        else if(g_trade_mode == 2) // 只开空
            direction = OP_SELL;
        else // 双向模式
            direction = (MathRand() % 2 == 0) ? OP_BUY : OP_SELL;
            
        string comment = GenerateOrderComment("Grid", Symbol(), 1);
        if(OpenOrder(direction, current_price, comment))
        {
            g_first_order_price = current_price;
            g_first_order_type = direction;
            g_today_orders++;
            g_symbol_first_order_opened[symbol_idx] = true; // 标记已开首单
            Print("═══ [网格] 首单开启 ═══ ", Symbol(), " | ", (direction == OP_BUY ? "多单" : "空单"), " | 价格: ", DoubleToString(current_price, _Digits));
        }
        return;
    }
    
    //--- 检查是否需要在网格位置开新单
    CheckAndOpenGridOrders(current_price);
}

//+------------------------------------------------------------------+
//| 多品种随机交易逻辑                                                |
//+------------------------------------------------------------------+
void ManageLogic_Random_MultiSymbol()
{
    datetime current_time = TimeCurrent();
    
    //--- 检查开仓时间间隔
    if(current_time - g_last_trade_time < InpRandomInterval)
    {
        return;
    }
    
    //--- 更新开仓时间
    g_last_trade_time = current_time;
    
    // 获取所有启用的品种
    string enabled_symbols[];
    int enabled_count = 0;
    
    for(int i = 0; i < ArraySize(g_available_symbols); i++)
    {
        if(g_symbol_enabled[i])
        {
            ArrayResize(enabled_symbols, enabled_count + 1);
            enabled_symbols[enabled_count] = g_available_symbols[i];
            enabled_count++;
        }
    }
    
    if(enabled_count == 0) return; // 没有启用的品种
    
    //--- 随机选择一个启用的品种
    int random_idx = MathRand() % enabled_count;
    string selected_symbol = enabled_symbols[random_idx];
    
    //--- 随机选择交易方向
    int direction;
    if(g_trade_mode == 1) // 只开多
        direction = OP_BUY;
    else if(g_trade_mode == 2) // 只开空
        direction = OP_SELL;
    else // 双向模式
        direction = (MathRand() % 2 == 0) ? OP_BUY : OP_SELL;
    
    //--- 获取品种价格
    double ask = MarketInfo(selected_symbol, MODE_ASK);
    double bid = MarketInfo(selected_symbol, MODE_BID);
    if(ask == 0 || bid == 0) return; // 价格无效
    
    double current_price = (ask + bid) / 2.0;
    
    //--- 生成订单备注
    string comment = GenerateOrderComment("Random", selected_symbol, g_today_orders + 1);
    
    //--- 开单
    if(OpenOrderForSymbol_Random(selected_symbol, direction, current_price, comment))
    {
        g_today_orders++;
        Print("═══ [随机] 新单 ═══ ", selected_symbol, " | ", (direction == OP_BUY ? "多单" : "空单"), " | 价格: ", DoubleToString(current_price, (int)MarketInfo(selected_symbol, MODE_DIGITS)));
    }
}

//+------------------------------------------------------------------+
//| 随机交易逻辑（保持原有逻辑用于当前品种）                          |
//+------------------------------------------------------------------+
void ManageLogic_Random()
{
    datetime current_time = TimeCurrent();
    int magic_number = InpMagicNo;
    
    //--- 检查开仓时间间隔
    if(current_time - g_last_trade_time < InpRandomInterval)
    {
        return;
    }
    
    //--- 更新开仓时间
    g_last_trade_time = current_time;
    
    //--- 随机选择交易方向
    int direction;
    if(g_trade_mode == 1) // 只开多
        direction = OP_BUY;
    else if(g_trade_mode == 2) // 只开空
        direction = OP_SELL;
    else // 双向模式
        direction = (MathRand() % 2 == 0) ? OP_BUY : OP_SELL;
    
    //--- 获取当前价格
    double current_price = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) + SymbolInfoDouble(Symbol(), SYMBOL_BID)) / 2.0;
    
    //--- 生成订单备注
    string comment = GenerateOrderComment("Random", Symbol(), g_today_orders + 1);
    
    //--- 开单
    if(OpenOrder(direction, current_price, comment))
    {
        g_today_orders++;
        Print("═══ [随机] 新单 ═══ ", Symbol(), " | ", (direction == OP_BUY ? "多单" : "空单"), " | 价格: ", DoubleToString(current_price, _Digits));
    }
}

//+------------------------------------------------------------------+
//| 为指定品种开网格订单                                              |
//+------------------------------------------------------------------+
bool OpenOrderForSymbol_Grid(string symbol, int direction, double target_price, string comment)
{
    double ask = MarketInfo(symbol, MODE_ASK);
    double bid = MarketInfo(symbol, MODE_BID);
    double point = MarketInfo(symbol, MODE_POINT);
    int digits = (int)MarketInfo(symbol, MODE_DIGITS);
    
    if(ask == 0 || bid == 0) return false;
    
    //--- 计算SL和TP
    double sl_price = 0;
    double tp_price = 0;
    double open_price;
    
    if(direction == OP_BUY)
    {
        open_price = ask;
        if(InpBaseSL > 0)
            sl_price = NormalizeDouble(ask - InpBaseSL * point, digits);
        if(InpBaseTP > 0)
            tp_price = NormalizeDouble(ask + InpBaseTP * point, digits);
    }
    else // OP_SELL
    {
        open_price = bid;
        if(InpBaseSL > 0)
            sl_price = NormalizeDouble(bid + InpBaseSL * point, digits);
        if(InpBaseTP > 0)
            tp_price = NormalizeDouble(bid - InpBaseTP * point, digits);
    }
    
    int ticket = OrderSend(symbol, direction, InpLotSize, open_price, 3, sl_price, tp_price, 
                          comment, InpMagicNo, 0, clrNONE);
    
    if(ticket > 0)
    {
        Print("✓ [网格] #", ticket, " | ", symbol, " | ", (direction == OP_BUY ? "多" : "空"), " | ", DoubleToString(open_price, digits), " | ", InpLotSize, "手");
        return true;
    }
    else
    {
        int error = GetLastError();
        Print("✖ [网格失败] ", symbol, " | ", (direction == OP_BUY ? "多单" : "空单"), " | 错误: ", error);
        return false;
    }
}

//+------------------------------------------------------------------+
//| 为指定品种开随机订单                                              |
//+------------------------------------------------------------------+
bool OpenOrderForSymbol_Random(string symbol, int direction, double target_price, string comment)
{
    double ask = MarketInfo(symbol, MODE_ASK);
    double bid = MarketInfo(symbol, MODE_BID);
    double point = MarketInfo(symbol, MODE_POINT);
    int digits = (int)MarketInfo(symbol, MODE_DIGITS);
    
    if(ask == 0 || bid == 0) return false;
    
    //--- 计算SL和TP
    double sl_price = 0;
    double tp_price = 0;
    double open_price;
    
    if(direction == OP_BUY)
    {
        open_price = ask;
        if(InpBaseSL > 0)
            sl_price = NormalizeDouble(ask - InpBaseSL * point, digits);
        if(InpBaseTP > 0)
            tp_price = NormalizeDouble(ask + InpBaseTP * point, digits);
    }
    else // OP_SELL
    {
        open_price = bid;
        if(InpBaseSL > 0)
            sl_price = NormalizeDouble(bid + InpBaseSL * point, digits);
        if(InpBaseTP > 0)
            tp_price = NormalizeDouble(bid - InpBaseTP * point, digits);
    }
    
    int ticket = OrderSend(symbol, direction, InpLotSize, open_price, 3, sl_price, tp_price, 
                          comment, InpMagicNo, 0, clrNONE);
    
    if(ticket > 0)
    {
        Print("✓ [随机] #", ticket, " | ", symbol, " | ", (direction == OP_BUY ? "多" : "空"), " | ", DoubleToString(open_price, digits), " | ", InpLotSize, "手");
        return true;
    }
    else
    {
        int error = GetLastError();
        Print("✖ [随机失败] ", symbol, " | ", (direction == OP_BUY ? "多单" : "空单"), " | 错误: ", error);
        return false;
    }
}

//+------------------------------------------------------------------+
//| 检查指定品种并在网格位置开单                                      |
//+------------------------------------------------------------------+
void CheckAndOpenGridOrders_ForSymbol(string symbol, double current_price)
{
    int magic_number = InpMagicNo;
    double grid_step = InpGridStep;
    
    //--- 获取该品种所有已开订单的价格和类型
    double order_prices[];
    int order_types[];
    int order_count = 0;
    
    ArrayResize(order_prices, 100);
    ArrayResize(order_types, 100);
    
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == symbol && OrderMagicNumber() == magic_number)
            {
                order_prices[order_count] = OrderOpenPrice();
                order_types[order_count] = OrderType();
                order_count++;
            }
        }
    }
    
    if(order_count == 0) return;
    
    //--- 找出最高和最低的订单价格
    double highest_price = order_prices[0];
    double lowest_price = order_prices[0];
    
    for(int i = 1; i < order_count; i++)
    {
        if(order_prices[i] > highest_price) highest_price = order_prices[i];
        if(order_prices[i] < lowest_price) lowest_price = order_prices[i];
    }
    
    //--- 检查是否需要在上方开多单
    if(g_trade_mode != 2) // 非只开空模式
    {
        double next_buy_level = highest_price + grid_step;
        if(current_price >= next_buy_level)
        {
            if(!HasOrderAtPrice_ForSymbol(symbol, next_buy_level, grid_step / 2.0))
            {
                string comment = GenerateOrderComment("Grid", symbol, order_count + 1);
                if(OpenOrderForSymbol_Grid(symbol, OP_BUY, next_buy_level, comment))
                {
                    g_today_orders++;
                    Print("▲ [网格-上涨] ", symbol, " | 多单 | ", DoubleToString(next_buy_level, (int)MarketInfo(symbol, MODE_DIGITS)), " | 今日: ", g_today_orders);
                }
            }
        }
    }
    
    //--- 检查是否需要在下方开空单
    if(g_trade_mode != 1) // 非只开多模式
    {
        double next_sell_level = lowest_price - grid_step;
        if(current_price <= next_sell_level)
        {
            if(!HasOrderAtPrice_ForSymbol(symbol, next_sell_level, grid_step / 2.0))
            {
                string comment = GenerateOrderComment("Grid", symbol, order_count + 1);
                if(OpenOrderForSymbol_Grid(symbol, OP_SELL, next_sell_level, comment))
                {
                    g_today_orders++;
                    Print("▼ [网格-下跌] ", symbol, " | 空单 | ", DoubleToString(next_sell_level, (int)MarketInfo(symbol, MODE_DIGITS)), " | 今日: ", g_today_orders);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 检查指定品种指定价格附近是否已有订单                              |
//+------------------------------------------------------------------+
bool HasOrderAtPrice_ForSymbol(string symbol, double price, double tolerance)
{
    int magic_number = InpMagicNo;
    
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == symbol && OrderMagicNumber() == magic_number)
            {
                if(MathAbs(OrderOpenPrice() - price) < tolerance)
                {
                    return true;
                }
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| 检查并在网格位置开单                                              |
//+------------------------------------------------------------------+
void CheckAndOpenGridOrders(double current_price)
{
    int magic_number = InpMagicNo;
    double grid_step = InpGridStep;
    
    //--- 获取所有已开订单的价格和类型
    double order_prices[];
    int order_types[];
    int order_count = 0;
    
    ArrayResize(order_prices, 100);
    ArrayResize(order_types, 100);
    
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            {
                order_prices[order_count] = OrderOpenPrice();
                order_types[order_count] = OrderType();
                order_count++;
            }
        }
    }
    
    if(order_count == 0) return;
    
    //--- 找出最高和最低的订单价格
    double highest_price = order_prices[0];
    double lowest_price = order_prices[0];
    
    for(int i = 1; i < order_count; i++)
    {
        if(order_prices[i] > highest_price) highest_price = order_prices[i];
        if(order_prices[i] < lowest_price) lowest_price = order_prices[i];
    }
    
    //--- 检查是否需要在上方开多单
    if(g_trade_mode != 2) // 非只开空模式
    {
        double next_buy_level = highest_price + grid_step;
        if(current_price >= next_buy_level)
        {
            if(!HasOrderAtPrice(next_buy_level, grid_step / 2.0))
            {
                string comment = GenerateOrderComment("Grid", Symbol(), order_count + 1);
                if(OpenOrder(OP_BUY, next_buy_level, comment))
                {
                    g_today_orders++;
                    Print("▲ [网格-上涨] ", Symbol(), " | 多单 | ", DoubleToString(next_buy_level, _Digits), " | 今日: ", g_today_orders);
                }
            }
        }
    }
    
    //--- 检查是否需要在下方开空单
    if(g_trade_mode != 1) // 非只开多模式
    {
        double next_sell_level = lowest_price - grid_step;
        if(current_price <= next_sell_level)
        {
            if(!HasOrderAtPrice(next_sell_level, grid_step / 2.0))
            {
                string comment = GenerateOrderComment("Grid", Symbol(), order_count + 1);
                if(OpenOrder(OP_SELL, next_sell_level, comment))
                {
                    g_today_orders++;
                    Print("▼ [网格-下跌] ", Symbol(), " | 空单 | ", DoubleToString(next_sell_level, _Digits), " | 今日: ", g_today_orders);
                }
            }
        }
    }
    
    //--- 反向单逻辑已禁用（纯趋势追踪网格）
    //--- 上涨开多，下跌开空，不做反向对冲
}

//+------------------------------------------------------------------+
//| 检查指定价格附近是否已有订单                                      |
//+------------------------------------------------------------------+
bool HasOrderAtPrice(double price, double tolerance)
{
    int magic_number = InpMagicNo;
    
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            {
                if(MathAbs(OrderOpenPrice() - price) < tolerance)
                {
                    return true;
                }
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| 开单函数                                                          |
//+------------------------------------------------------------------+
bool OpenOrder(int direction, double target_price, string comment_prefix)
{
    int magic_number = InpMagicNo;
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double point = _Point;
    
    //--- 使用传入的comment_prefix作为备注
    string comment = comment_prefix;
    
    //--- 计算SL和TP
    double sl_price, tp_price;
    int sl_points = InpBaseSL;
    int tp_points = InpBaseTP;
    
    double open_price;
    if(direction == OP_BUY)
    {
        open_price = ask;
        sl_price = (sl_points > 0) ? (ask - sl_points * point) : 0;
        tp_price = (tp_points > 0) ? (ask + tp_points * point) : 0;
    }
    else // OP_SELL
    {
        open_price = bid;
        sl_price = (sl_points > 0) ? (bid + sl_points * point) : 0;
        tp_price = (tp_points > 0) ? (bid - tp_points * point) : 0;
    }
    
    //--- 价格标准化
    if(sl_price > 0) sl_price = NormalizeDouble(sl_price, _Digits);
    if(tp_price > 0) tp_price = NormalizeDouble(tp_price, _Digits);
    open_price = NormalizeDouble(open_price, _Digits);
    
    double lot_size = InpLotSize;
    int ticket = OrderSend(Symbol(), direction, lot_size, open_price, 3, sl_price, tp_price, comment, magic_number, 0, clrNONE);
    
    if(ticket < 0)
    {
        int last_error = GetLastError();
        Print("✖ [失败] ", Symbol(), " | ", (direction == OP_BUY ? "多单" : "空单"), " | 错误: ", last_error);
        return false;
    }
    else
    {
        Print("✓ [成功] #", ticket, " | ", Symbol(), " | ", (direction == OP_BUY ? "多" : "空"), " | ", DoubleToString(open_price, _Digits), " | ", lot_size, "手");
        return true;
    }
}

//+------------------------------------------------------------------+
//| 管理保本损 (Breakeven)                                           |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    //--- 如果保本损功能禁用，则不执行任何操作
    if(InpTPA <= 0)
        return;

    const int breakeven_plus_points = 10; // 保本时，在开仓价基础上增加的点数
    double point = _Point;

    //--- 遍历所有持仓
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol())
            {
                int magic = OrderMagicNumber();
                if(magic == InpMagicNo)
                {
                    //--- 获取订单基本信息
                    int type = OrderType();
                    double open_price = OrderOpenPrice();
                    double current_sl = OrderStopLoss();
                    double current_tp = OrderTakeProfit();
                    double current_price;
                    double profit_pips;

                    if(type == OP_BUY)
                    {
                        current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
                        profit_pips = (current_price - open_price) / point;
                    }
                    else // OP_SELL
                    {
                        current_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
                        profit_pips = (open_price - current_price) / point;
                    }

                    //--- 保本损逻辑
                    if(profit_pips >= InpTPA)
                    {
                        // 检查是否已经保本，避免重复修改
                        bool isBreakevenTriggered = false;
                        if (type == OP_BUY && current_sl >= open_price && current_sl != 0) isBreakevenTriggered = true;
                        if (type == OP_SELL && current_sl <= open_price && current_sl != 0) isBreakevenTriggered = true;
                        
                        if(!isBreakevenTriggered)
                        {
                            double new_sl = 0;
                            if(type == OP_BUY)
                            {
                                new_sl = open_price + breakeven_plus_points * point;
                                if(new_sl > current_sl)
                                {
                                    if(!OrderModify(OrderTicket(), open_price, NormalizeDouble(new_sl, _Digits), current_tp, 0, clrNONE))
                                    {
                                        if(GetLastError() != 1) Print("[ERROR] Breakeven Modify Failed (BUY) | Ticket: ", OrderTicket(), " | Error: ", GetLastError());
                                    }
                                }
                            }
                            else // OP_SELL
                            {
                                new_sl = open_price - breakeven_plus_points * point;
                                if(new_sl < current_sl || current_sl == 0)
                                {
                                     if(!OrderModify(OrderTicket(), open_price, NormalizeDouble(new_sl, _Digits), current_tp, 0, clrNONE))
                                     {
                                        if(GetLastError() != 1) Print("[ERROR] Breakeven Modify Failed (SELL) | Ticket: ", OrderTicket(), " | Error: ", GetLastError());
                                     }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


//+------------------------------------------------------------------+
//| 检查是否在交易时间段内                                            |
//+------------------------------------------------------------------+
bool IsTradeTime()
{
    datetime current_time_struct = TimeCurrent();
    int current_hour = TimeHour(current_time_struct);
    int current_min = TimeMinute(current_time_struct);

    int start_hour = (int)StringSubstr(InpStartTime, 0, 2);
    int start_min = (int)StringSubstr(InpStartTime, 3, 2);
    int end_hour = (int)StringSubstr(InpEndTime, 0, 2);
    int end_min = (int)StringSubstr(InpEndTime, 3, 2);

    int current_minutes = current_hour * 60 + current_min;
    int start_total_minutes = start_hour * 60 + start_min;
    int end_total_minutes = end_hour * 60 + end_min;

    if (start_total_minutes <= end_total_minutes)
    {
        return (current_minutes >= start_total_minutes && current_minutes <= end_total_minutes);
    }
    else
    {
        return (current_minutes >= start_total_minutes || current_minutes <= end_total_minutes);
    }
}
//+------------------------------------------------------------------+
//| 信息面板相关函数                                                 |
//+------------------------------------------------------------------+
void CreateLabel(const string name, const int x, const int y, const string text, const color clr, const int font_size)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, 0); // 0 = CORNER_UPPER_LEFT
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, name, OBJPROP_BACK, false);  // 在K线前面
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void UpdateDashboard()
{
    //--- 统计持仓和盈亏（使用统一函数）
    int long_positions = 0;
    int short_positions = 0;
    double floating_pl = 0.0;
    
    GetPositionStats(long_positions, short_positions, floating_pl);
    
    int total_positions = long_positions + short_positions;
    int locked_pairs = MathMin(long_positions, short_positions);
    
    // 更新最大持仓记录
    if(total_positions > g_max_positions)
        g_max_positions = total_positions;
    
    // 计算今日盈亏
    g_today_profit = AccountBalance() - g_day_start_balance;

    //--- 获取账户信息
    double account_balance = AccountBalance();
    double account_equity = AccountEquity();
    double margin_used = AccountMargin();
    double margin_free = AccountFreeMargin();
    double margin_level = (margin_used > 0) ? (account_equity / margin_used * 100.0) : 0;
    
    // 计算浮亏百分比
    double drawdown_percent = (account_equity > 0) ? ((account_balance - account_equity) / account_equity * 100.0) : 0;

    //--- 创建面板背景（现代化设计）
    string bg_name = "YDA_Panel_BG";
    if(ObjectFind(0, bg_name) < 0)
    {
        ObjectCreate(0, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, bg_name, OBJPROP_CORNER, 0);
        ObjectSetInteger(0, bg_name, OBJPROP_XDISTANCE, InpPanelX);
        ObjectSetInteger(0, bg_name, OBJPROP_YDISTANCE, InpPanelY);
        ObjectSetInteger(0, bg_name, OBJPROP_XSIZE, 460);
        ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, 380);  // 继续增加面板高度，容纳服务器信息
        ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR, C'15,15,25');  // 深蓝黑色
        ObjectSetInteger(0, bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, bg_name, OBJPROP_BORDER_COLOR, C'100,180,255');
        ObjectSetInteger(0, bg_name, OBJPROP_BACK, false);  // 在K线前面
        ObjectSetInteger(0, bg_name, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, bg_name, OBJPROP_SELECTABLE, false);
    }
    
    //--- 左侧信息栏已移除（简化界面）


    //--- 主面板显示信息（优化排版）
    int y_pos = InpPanelY + 10;
    int x_pos = InpPanelX + 15;
    int x_pos2 = InpPanelX + 245; // 第二列
    int line_height = 16;
    
    // 使用固定宽度对齐 - 标签列宽度40，数值列宽度90
    int label_width = 40;   // 标签列宽度
    int value_width = 90;   // 数值列宽度

    // 标题（更大更醒目）
    string title_text = "Π GRID ENGINE";
    if(InpTradingMode == 1) title_text = "Π RANDOM MODE";
    CreateLabel("YDA_Panel_Title", x_pos + 100, y_pos, title_text, C'100,180,255', 14);
    
    // Live状态指示器（右上角）
    bool is_trading = IsTradeTime();
    color live_color = is_trading ? C'0,255,100' : C'255,100,100';
    string live_status = is_trading ? "● LIVE" : "● PAUSE";
    CreateLabel("YDA_Panel_LiveStatus", x_pos + 350, y_pos + 2, live_status, live_color, 11);
    
    // 服务器时间（小字，与LIVE字母左对齐）
    string server_time = TimeToString(TimeCurrent(), TIME_MINUTES);
    CreateLabel("YDA_Panel_ServerTime", x_pos + 365, y_pos + 16, server_time, C'120,120,150', 8);
    
    y_pos += 28;
    
    // 分隔线
    CreateLabel("YDA_Panel_Sep1", x_pos, y_pos, "_________________________________________________________", C'50,50,80', 8);
    y_pos += 8;
    
    // 第一部分：持仓统计
    CreateLabel("YDA_Panel_Section1", x_pos, y_pos, "■ 持仓统计", C'100,180,255', 10);
    y_pos += line_height;
    
    CreateLabel("YDA_Panel_LongLabel", x_pos, y_pos, "多单", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Long", x_pos + label_width, y_pos, (string)long_positions, C'0,255,100', 10);
    CreateLabel("YDA_Panel_ShortLabel", x_pos2, y_pos, "空单", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Short", x_pos2 + label_width, y_pos, (string)short_positions, C'255,100,100', 10);
    y_pos += line_height;
    
    CreateLabel("YDA_Panel_TotalLabel", x_pos, y_pos, "总持仓", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Total", x_pos + label_width, y_pos, (string)total_positions, C'200,200,200', 10);
    CreateLabel("YDA_Panel_LockedLabel", x_pos2, y_pos, "锁仓对", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Locked", x_pos2 + label_width, y_pos, (string)locked_pairs, C'255,200,0', 10);
    y_pos += line_height;
    
    CreateLabel("YDA_Panel_MaxPosLabel", x_pos, y_pos, "最大值", C'150,150,180', 9);
    CreateLabel("YDA_Panel_MaxPos", x_pos + label_width, y_pos, (string)g_max_positions, C'120,120,150', 9);
    
    // 交易模式
    string mode_text = "";
    color mode_color = C'200,200,200';
    if(g_trade_mode == 0) { mode_text = "双向"; mode_color = C'200,200,200'; }
    else if(g_trade_mode == 1) { mode_text = "只开多"; mode_color = C'0,255,100'; }
    else if(g_trade_mode == 2) { mode_text = "只开空"; mode_color = C'255,100,100'; }
    CreateLabel("YDA_Panel_TradeModeLabel", x_pos2, y_pos, "模式", C'150,150,180', 9);
    CreateLabel("YDA_Panel_TradeMode", x_pos2 + label_width, y_pos, mode_text, mode_color, 9);
    y_pos += line_height + 3;
    
    // 分隔线
    CreateLabel("YDA_Panel_Sep2", x_pos, y_pos, "_________________________________________________________", C'50,50,80', 8);
    y_pos += 8;
    
    // 第二部分：账户信息
    CreateLabel("YDA_Panel_Section2", x_pos, y_pos, "■ 账户信息", C'100,180,255', 10);
    y_pos += line_height;
    
    CreateLabel("YDA_Panel_BalanceLabel", x_pos, y_pos, "余额", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Balance", x_pos + label_width, y_pos, "$" + DoubleToString(account_balance, 2), C'200,200,200', 10);
    CreateLabel("YDA_Panel_EquityLabel", x_pos2, y_pos, "净值", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Equity", x_pos2 + label_width, y_pos, "$" + DoubleToString(account_equity, 2), C'200,200,200', 10);
    y_pos += line_height;
    
    color pl_color = (floating_pl >= 0) ? C'0,255,100' : C'255,100,100';
    string pl_sign = (floating_pl >= 0) ? "+" : "";
    CreateLabel("YDA_Panel_FloatPLLabel", x_pos, y_pos, "浮动", C'150,150,180', 9);
    CreateLabel("YDA_Panel_FloatPL", x_pos + label_width, y_pos, pl_sign + "$" + DoubleToString(floating_pl, 2), pl_color, 10);
    
    double margin_percent_display = (margin_free > 0) ? (margin_used / (margin_used + margin_free) * 100.0) : 0;
    color margin_color = (margin_percent_display > 80) ? C'255,100,100' : (margin_percent_display > 60) ? C'255,200,0' : C'0,255,100';
    CreateLabel("YDA_Panel_MarginLabel", x_pos2, y_pos, "保证金", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Margin", x_pos2 + label_width, y_pos, DoubleToString(margin_percent_display, 1) + "%", margin_color, 10);
    y_pos += line_height;
    
    // 添加更多账户信息
    CreateLabel("YDA_Panel_FreeMarginLabel", x_pos, y_pos, "可用", C'150,150,180', 9);
    CreateLabel("YDA_Panel_FreeMargin", x_pos + label_width, y_pos, "$" + DoubleToString(margin_free, 2), C'200,200,200', 10);
    
    // 账户杠杆
    int account_leverage = AccountLeverage();
    CreateLabel("YDA_Panel_LeverageLabel", x_pos2, y_pos, "杠杆", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Leverage", x_pos2 + label_width, y_pos, "1:" + (string)account_leverage, C'200,200,200', 10);
    y_pos += line_height;
    
    // 账户货币和服务器
    string account_currency = AccountCurrency();
    CreateLabel("YDA_Panel_CurrencyLabel", x_pos, y_pos, "货币", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Currency", x_pos + label_width, y_pos, account_currency, C'200,200,200', 10);
    
    // 账户类型
    string account_type = "";
    if(IsDemo()) account_type = "模拟";
    else account_type = "真实";
    CreateLabel("YDA_Panel_AccountTypeLabel", x_pos2, y_pos, "类型", C'150,150,180', 9);
    color account_type_color = IsDemo() ? C'255,200,0' : C'0,255,100';
    CreateLabel("YDA_Panel_AccountType", x_pos2 + label_width, y_pos, account_type, account_type_color, 10);
    y_pos += line_height;
    
    // 服务器信息
    string server_name = AccountServer();
    CreateLabel("YDA_Panel_ServerLabel", x_pos, y_pos, "服务器", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Server", x_pos + label_width, y_pos, server_name, C'200,200,200', 10);
    
    // 账户号码
    int account_number = AccountNumber();
    CreateLabel("YDA_Panel_AccountNumLabel", x_pos2, y_pos, "账号", C'150,150,180', 9);
    CreateLabel("YDA_Panel_AccountNum", x_pos2 + label_width, y_pos, (string)account_number, C'200,200,200', 10);
    y_pos += line_height;
    
    // 连接状态和延迟
    bool is_connected = IsConnected();
    string connection_status = is_connected ? "已连接" : "断开";
    color connection_color = is_connected ? C'0,255,100' : C'255,100,100';
    CreateLabel("YDA_Panel_ConnectionLabel", x_pos, y_pos, "连接", C'150,150,180', 9);
    CreateLabel("YDA_Panel_Connection", x_pos + label_width, y_pos, connection_status, connection_color, 10);
    
    // 交易许可状态
    bool trade_allowed = IsTradeAllowed();
    string trade_status = trade_allowed ? "允许" : "禁止";
    color trade_color = trade_allowed ? C'0,255,100' : C'255,100,100';
    CreateLabel("YDA_Panel_TradeAllowedLabel", x_pos2, y_pos, "交易", C'150,150,180', 9);
    CreateLabel("YDA_Panel_TradeAllowed", x_pos2 + label_width, y_pos, trade_status, trade_color, 10);
    y_pos += line_height + 3;
    
    // 分隔线
    CreateLabel("YDA_Panel_Sep3", x_pos, y_pos, "_________________________________________________________", C'50,50,80', 8);
    y_pos += 8;
    
    // 第三部分：今日统计
    CreateLabel("YDA_Panel_Section3", x_pos, y_pos, "■ 今日统计", C'100,180,255', 10);
    y_pos += line_height;
    
    CreateLabel("YDA_Panel_TodayOrdersLabel", x_pos, y_pos, "开单数", C'150,150,180', 9);
    CreateLabel("YDA_Panel_TodayOrders", x_pos + label_width, y_pos, (string)g_today_orders, C'200,200,200', 10);
    
    color today_pl_color = (g_today_profit >= 0) ? C'0,255,100' : C'255,100,100';
    string today_pl_sign = (g_today_profit >= 0) ? "+" : "";
    CreateLabel("YDA_Panel_TodayPLLabel", x_pos2, y_pos, "盈亏", C'150,150,180', 9);
    CreateLabel("YDA_Panel_TodayPL", x_pos2 + label_width, y_pos, today_pl_sign + "$" + DoubleToString(g_today_profit, 2), today_pl_color, 10);
    y_pos += line_height;
    
    // 日亏损限制已移除
    
    // 警报指示（如果有警报，显示在第二列）
    string alert_text = "";
    color alert_color = C'200,200,200';
    if(total_positions >= InpMaxOrdersAlert)
    {
        alert_text = "⚠ 持仓警报";
        alert_color = C'255,100,100';
    }
    else if(margin_percent_display >= InpMarginAlert)
    {
        alert_text = "⚠ 保证金";
        alert_color = C'255,150,0';
    }
    else if(drawdown_percent >= InpDrawdownAlert)
    {
        alert_text = "⚠ 回撤";
        alert_color = C'255,150,0';
    }
    
    if(alert_text != "")
    {
        CreateLabel("YDA_Panel_Alert", x_pos2, y_pos, alert_text, alert_color, 10);
        y_pos += line_height;
    }
    else
    {
        CreateLabel("YDA_Panel_Alert", x_pos2, y_pos, "", C'200,200,200', 10);
    }
    
    //--- 检查并重新创建按钮（如果丢失）
    EnsureButtonsExist();
    
    //--- 更新按钮状态
    UpdateButtonStates();
}

//+------------------------------------------------------------------+
//| 更新现有订单以匹配当前参数                                       |
//+------------------------------------------------------------------+
void UpdateOrdersOnParameterChange()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol())
            {
                int magic = OrderMagicNumber();
                // 检查是否是本EA管理的订单
                if(magic == InpMagicNo)
                {
                    // 根据当前参数重新计算SL和TP
                    double new_sl_price = 0;
                    double new_tp_price = 0;
                    int sl_points = InpBaseSL;
                    int tp_points = InpBaseTP;
                    double point = _Point;

                    // 只有当参数 > 0 时才计算 SL/TP
                    if(OrderType() == OP_BUY)
                    {
                        if(sl_points > 0)
                            new_sl_price = NormalizeDouble(OrderOpenPrice() - sl_points * point, _Digits);
                        if(tp_points > 0)
                            new_tp_price = NormalizeDouble(OrderOpenPrice() + tp_points * point, _Digits);
                    }
                    else // OP_SELL
                    {
                        if(sl_points > 0)
                            new_sl_price = NormalizeDouble(OrderOpenPrice() + sl_points * point, _Digits);
                        if(tp_points > 0)
                            new_tp_price = NormalizeDouble(OrderOpenPrice() - tp_points * point, _Digits);
                    }

                    // 检查SL/TP是否需要更新
                    // 重要: 如果保本损已触发，则不再调整止损
                    bool isBreakevenTriggered = false;
                    if (InpTPA > 0) 
                    {
                        if (OrderType() == OP_BUY && OrderStopLoss() >= OrderOpenPrice()) isBreakevenTriggered = true;
                        if (OrderType() == OP_SELL && OrderStopLoss() <= OrderOpenPrice() && OrderStopLoss() != 0) isBreakevenTriggered = true;
                    }

                    // 确定最终的 SL/TP
                    double target_sl = isBreakevenTriggered ? OrderStopLoss() : new_sl_price;
                    double target_tp = new_tp_price;

                    // 检查是否真的需要修改
                    // 如果参数都是 0，且订单已经没有 SL/TP，则不需要修改
                    bool need_update = false;
                    
                    // 检查 SL 是否需要更新
                    if(sl_points > 0 || OrderStopLoss() != 0)
                    {
                        if(MathAbs(OrderStopLoss() - target_sl) > point)
                            need_update = true;
                    }
                    
                    // 检查 TP 是否需要更新
                    if(tp_points > 0 || OrderTakeProfit() != 0)
                    {
                        if(MathAbs(OrderTakeProfit() - target_tp) > point)
                            need_update = true;
                    }
                    
                    if(need_update)
                    {
                        ResetLastError(); // 清除之前的错误
                        bool result = OrderModify(OrderTicket(), OrderOpenPrice(), target_sl, target_tp, 0, clrNONE);
                        int error = GetLastError();
                        
                        if(!result)
                        {
                            // 只记录真正的错误，忽略"no changes"和"no error"
                            if(error != 0 && error != 1) 
                            {
                                Print("[ERROR] Parameter Update Failed | Ticket: ", OrderTicket(), 
                                      " | Error: ", error, 
                                      " | Old SL: ", DoubleToString(OrderStopLoss(), _Digits),
                                      " | New SL: ", DoubleToString(target_sl, _Digits));
                            }
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 创建按钮                                                          |
//+------------------------------------------------------------------+
void CreateButton(string name, int x, int y, int width, int height, string text, color txt_color, color bg_color)
{
    // 删除旧按钮（如果存在）
    if(ObjectFind(0, name) >= 0)
        ObjectDelete(0, name);
    
    // 创建新按钮
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, name, OBJPROP_COLOR, txt_color);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);  // 按钮在最前面
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_STATE, false);  // 确保按钮初始状态为未按下
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, false); // 按钮需要可见，不隐藏
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);     // 设置较高的层级，确保在最前面
}

//+------------------------------------------------------------------+
//| 确保按钮存在（如果丢失则重新创建）                                |
//+------------------------------------------------------------------+
void EnsureButtonsExist()
{
    if(!InpShowPanel) return;
    
    // 检查并重新创建操作按钮
    if(ObjectFind(0, "YDA_Btn_CloseAll") < 0)
    {
        CreateButton("YDA_Btn_CloseAll", InpPanelX + 10, InpPanelY + 390, 140, 28, "一键平仓", clrWhite, C'180,50,50');
    }
    
    if(ObjectFind(0, "YDA_Btn_BuyOnly") < 0)
    {
        CreateButton("YDA_Btn_BuyOnly", InpPanelX + 160, InpPanelY + 390, 140, 28, "只开多", clrWhite, C'60,60,80');
    }
    
    if(ObjectFind(0, "YDA_Btn_SellOnly") < 0)
    {
        CreateButton("YDA_Btn_SellOnly", InpPanelX + 310, InpPanelY + 390, 140, 28, "只开空", clrWhite, C'60,60,80');
    }
}

//+------------------------------------------------------------------+
//| 更新按钮状态                                                      |
//+------------------------------------------------------------------+
void UpdateButtonStates()
{
    // 更新"只开多"按钮状态
    if(ObjectFind(0, "YDA_Btn_BuyOnly") >= 0)
    {
        if(g_trade_mode == 1)
        {
            // 激活状态：绿色背景 + 亮边框 + 加粗文字效果
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_BGCOLOR, C'0,180,80');
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_BORDER_COLOR, C'0,255,120');
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_COLOR, clrWhite);
            // 不使用STATE属性来表示激活，避免按钮卡住
        }
        else
        {
            // 未激活：灰色背景 + 白边框
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_BGCOLOR, C'60,60,80');
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_BORDER_COLOR, clrWhite);
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_COLOR, clrWhite);
        }
        // 始终确保按钮状态为未按下
        ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_STATE, false);
    }
    
    // 更新"只开空"按钮状态
    if(ObjectFind(0, "YDA_Btn_SellOnly") >= 0)
    {
        if(g_trade_mode == 2)
        {
            // 激活状态：红色背景 + 亮边框 + 加粗文字效果
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_BGCOLOR, C'200,60,60');
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_BORDER_COLOR, C'255,100,100');
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_COLOR, clrWhite);
            // 不使用STATE属性来表示激活，避免按钮卡住
        }
        else
        {
            // 未激活：灰色背景 + 白边框
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_BGCOLOR, C'60,60,80');
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_BORDER_COLOR, clrWhite);
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_COLOR, clrWhite);
        }
        // 始终确保按钮状态为未按下
        ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_STATE, false);
    }
}

//+------------------------------------------------------------------+
//| 一键平仓（支持多品种）                                            |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    int magic_number = InpMagicNo;
    int closed_count = 0;
    int failed_count = 0;
    int skipped_count = 0;
    
    Print("\n═════════ 一键平仓开始 ═════════");
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
            
        if(OrderMagicNumber() != magic_number)
            continue;
            
        string order_symbol = OrderSymbol();
        int ticket = OrderTicket();
        int order_type = OrderType();
        
        // 减少日志：找到订单不输出
        
        // 一键平仓：平掉所有订单，不检查是否启用
        {
            // 刷新报价
            RefreshRates();
            
            // 获取平仓价格（增加容错）
            double close_price = 0;
            if(OrderType() == OP_BUY)
            {
                close_price = MarketInfo(order_symbol, MODE_BID);
                if(close_price == 0) close_price = SymbolInfoDouble(order_symbol, SYMBOL_BID);
            }
            else // OP_SELL
            {
                close_price = MarketInfo(order_symbol, MODE_ASK);
                if(close_price == 0) close_price = SymbolInfoDouble(order_symbol, SYMBOL_ASK);
            }
            
            // 检查价格有效性
            if(close_price == 0)
            {
                Print("[ERROR] Invalid price for ", order_symbol, " | Ticket: ", ticket);
                failed_count++;
                continue;
            }
            
            // 尝试平仓（增加滑点，重试3次）
            bool closed = false;
            for(int retry = 0; retry < 3 && !closed; retry++)
            {
                if(retry > 0)
                {
                    Sleep(100);
                    RefreshRates();
                    // 重新获取价格
                    if(OrderType() == OP_BUY)
                        close_price = MarketInfo(order_symbol, MODE_BID);
                    else
                        close_price = MarketInfo(order_symbol, MODE_ASK);
                }
                
                if(OrderClose(ticket, OrderLots(), close_price, 10, clrNONE))
                {
                    closed = true;
                    closed_count++;
                    Print("✓ 平仓 #", ticket, " | ", order_symbol, " | ", (OrderType() == OP_BUY ? "多" : "空"));
                }
                else
                {
                    int error = GetLastError();
                    if(retry == 2)
                    {
                        Print("✖ 平仓失败 #", ticket, " | ", order_symbol, " | 错误: ", error);
                        failed_count++;
                    }
                }
            }
        }
    }
    
    Print("═════════ 平仓完成 ═════════\n成功: ", closed_count, " | 失败: ", failed_count, "\n");
    
    // 重置第一个订单记录
    g_first_order_price = 0.0;
    g_first_order_type = -1;
}


//+------------------------------------------------------------------+
//| 切换只开多模式                                                    |
//+------------------------------------------------------------------+
void ToggleBuyOnlyMode()
{
    if(g_trade_mode == 1)
    {
        g_trade_mode = 0; // 切换回双向模式
        Print("[MODE] Trade Mode: Bidirectional");
    }
    else
    {
        g_trade_mode = 1; // 切换到只开多
        Print("[MODE] Trade Mode: BUY Only");
    }
    
    UpdateButtonStates();
}

//+------------------------------------------------------------------+
//| 切换只开空模式                                                    |
//+------------------------------------------------------------------+
void ToggleSellOnlyMode()
{
    if(g_trade_mode == 2)
    {
        g_trade_mode = 0; // 切换回双向模式
        Print("[MODE] Trade Mode: Bidirectional");
    }
    else
    {
        g_trade_mode = 2; // 切换到只开空
        Print("[MODE] Trade Mode: SELL Only");
    }
    
    UpdateButtonStates();
}

//+------------------------------------------------------------------+
//| 检查每日重置                                                      |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    datetime current_time = TimeCurrent();
    MqlDateTime dt_current, dt_last;
    
    TimeToStruct(current_time, dt_current);
    TimeToStruct(g_last_reset_date, dt_last);
    
    // 检查是否是新的一天
    if(dt_current.day != dt_last.day || dt_current.mon != dt_last.mon || dt_current.year != dt_last.year)
    {
        // 重置每日统计
        g_today_orders = 0;
        g_day_start_balance = AccountBalance();
        g_last_reset_date = current_time;
        
        Print("[RESET] Daily Statistics Reset | Date: ", TimeToString(current_time, TIME_DATE));
    }
}

//+------------------------------------------------------------------+
//| 检查警报                                                          |
//+------------------------------------------------------------------+
void CheckAlerts()
{
    static datetime last_alert_time = 0;
    datetime current_time = TimeCurrent();
    
    // 每60秒最多触发一次警报，避免频繁提示
    if(current_time - last_alert_time < 60)
        return;
    
    // 统计持仓（使用统一函数）
    int long_positions = 0;
    int short_positions = 0;
    double total_profit = 0.0;
    
    GetPositionStats(long_positions, short_positions, total_profit);
    int total_positions = long_positions + short_positions;
    
    // 获取账户信息
    double account_equity = AccountEquity();
    double account_balance = AccountBalance();
    double margin_used = AccountMargin();
    double margin_free = AccountFreeMargin();
    
    // 计算保证金使用率
    double margin_percent = (margin_free > 0) ? (margin_used / (margin_used + margin_free) * 100.0) : 0;
    
    // 计算回撤百分比
    double drawdown_percent = (account_equity > 0) ? ((account_balance - account_equity) / account_equity * 100.0) : 0;
    
    bool alert_triggered = false;
    string alert_message = "";
    
    // 检查持仓数警报
    if(total_positions >= InpMaxOrdersAlert)
    {
        alert_message = StringFormat("[ALERT] Position Count: %d (Threshold: %d)", total_positions, InpMaxOrdersAlert);
        alert_triggered = true;
    }
    
    // 检查保证金警报
    if(margin_percent >= InpMarginAlert)
    {
        alert_message = StringFormat("[ALERT] Margin Used: %.1f%% (Threshold: %.1f%%)", margin_percent, InpMarginAlert);
        alert_triggered = true;
    }
    
    // 检查回撤警报
    if(drawdown_percent >= InpDrawdownAlert)
    {
        alert_message = StringFormat("[ALERT] Drawdown: %.1f%% (Threshold: %.1f%%)", drawdown_percent, InpDrawdownAlert);
        alert_triggered = true;
    }
    
    // 触发警报
    if(alert_triggered)
    {
        Print(alert_message);
        Alert(alert_message);
        last_alert_time = current_time;
    }
}

//+------------------------------------------------------------------+
//| 加载可用品种列表                                                  |
//+------------------------------------------------------------------+
void LoadAvailableSymbols()
{
    int total = SymbolsTotal(true); // 只获取市场报价窗口中的品种
    ArrayResize(g_available_symbols, total);
    ArrayResize(g_symbol_enabled, total);
    ArrayResize(g_symbol_first_order_opened, total);
    
    int count = 0;
    for(int i = 0; i < total; i++)
    {
        string symbol = SymbolName(i, true);
        if(symbol != "")
        {
            g_available_symbols[count] = symbol;
            // 默认只启用当前图表品种
            g_symbol_enabled[count] = (symbol == Symbol());
            g_symbol_first_order_opened[count] = false; // 初始化为未开首单
            count++;
        }
    }
    
    ArrayResize(g_available_symbols, count);
    ArrayResize(g_symbol_enabled, count);
    ArrayResize(g_symbol_first_order_opened, count);
    
    // 尝试恢复之前保存的状态
    RestoreSymbolStates();
    
    Print("[INIT] Loaded ", count, " symbols, Current: ", Symbol());
}

//+------------------------------------------------------------------+
//| 显示品种选择器（横向网格布局）                                    |
//+------------------------------------------------------------------+
void DisplaySymbolSelector(int panel_x, int panel_y)
{
    // 创建品种选择器背景（超宽显示）
    string selector_bg = "YDA_SymbolSelector_BG";
    if(ObjectFind(0, selector_bg) < 0)
    {
        ObjectCreate(0, selector_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, selector_bg, OBJPROP_CORNER, 0);
        ObjectSetInteger(0, selector_bg, OBJPROP_XDISTANCE, panel_x + 470);
        ObjectSetInteger(0, selector_bg, OBJPROP_YDISTANCE, panel_y);
        ObjectSetInteger(0, selector_bg, OBJPROP_XSIZE, 820);  // 调整宽度
        ObjectSetInteger(0, selector_bg, OBJPROP_YSIZE, 320);  // 调整高度
        ObjectSetInteger(0, selector_bg, OBJPROP_BGCOLOR, C'10,10,20');
        ObjectSetInteger(0, selector_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, selector_bg, OBJPROP_BORDER_COLOR, C'100,180,255');
        ObjectSetInteger(0, selector_bg, OBJPROP_BACK, false);  // 在K线前面
        ObjectSetInteger(0, selector_bg, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, selector_bg, OBJPROP_SELECTABLE, false);
    }
    
    // 显示标题和说明（居中对齐）
    CreateLabel("YDA_SymbolSelector_Title", panel_x + 780, panel_y + 10, "多品种交易", C'100,180,255', 11);
    
    // 统计启用的品种数
    int enabled_count = 0;
    for(int j = 0; j < ArraySize(g_symbol_enabled); j++)
    {
        if(g_symbol_enabled[j]) enabled_count++;
    }
    CreateLabel("YDA_SymbolSelector_Count", panel_x + 775, panel_y + 28, 
        "已启用: " + (string)enabled_count, C'0,255,100', 9);
    
    // 分隔线（调整长度和位置）
    CreateLabel("YDA_SymbolSelector_Sep", panel_x + 485, panel_y + 46, 
        "____________________________________________________________", C'50,50,80', 8);
    
    // 显示品种网格（优化布局）
    int total_symbols = ArraySize(g_available_symbols);
    int start_idx = 0;  // 显示所有品种，不分页
    int end_idx = total_symbols;
    
    int btn_width = 75;   // 稍微减小按钮宽度
    int btn_height = 22;  // 稍微减小按钮高度
    int btn_spacing_x = 5; // 增加水平间距
    int btn_spacing_y = 4; // 增加垂直间距
    int start_x = panel_x + 485; // 稍微右移起始位置
    int start_y = panel_y + 60;  // 稍微下移起始位置
    
    int display_count = 0;
    int cols_per_row = 9; // 每行9列布局，避免过于拥挤
    
    for(int i = start_idx; i < end_idx; i++)
    {
        string symbol = g_available_symbols[i];
        string btn_name = "YDA_Btn_Symbol_" + (string)i;
        
        // 计算网格位置（9列布局）
        int row = display_count / cols_per_row;
        int col = display_count % cols_per_row;
        int x_pos = start_x + col * (btn_width + btn_spacing_x);
        int y_pos = start_y + row * (btn_height + btn_spacing_y);
        
        // 根据启用状态设置颜色（优化配色）
        bool is_enabled = g_symbol_enabled[i];
        bool is_current = (symbol == Symbol());
        
        color bg_color;
        color txt_color;
        color border_color;
        
        if(is_current && is_enabled)
        {
            // 当前品种且启用：鲜明蓝色+亮金色
            bg_color = C'70,110,180';      // 钴蓝色
            txt_color = C'255,223,0';       // 亮金色
            border_color = C'135,206,250';  // 天蓝色边框
        }
        else if(is_enabled)
        {
            // 已启用：专业绿色+白色文字
            bg_color = C'34,139,34';        // 森林绿
            txt_color = C'255,255,255';     // 纯白色
            border_color = C'50,205,50';    // 亮绿边框
        }
        else
        {
            // 未启用：中性灰+淡文字
            bg_color = C'47,79,79';         // 深石板灰
            txt_color = C'169,169,169';     // 暗灰色
            border_color = C'105,105,105';  // 暗灰边框
        }
        
        if(ObjectFind(0, btn_name) < 0)
        {
            ObjectCreate(0, btn_name, OBJ_BUTTON, 0, 0, 0);
            ObjectSetInteger(0, btn_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        }
        
        ObjectSetInteger(0, btn_name, OBJPROP_XDISTANCE, x_pos);
        ObjectSetInteger(0, btn_name, OBJPROP_YDISTANCE, y_pos);
        ObjectSetInteger(0, btn_name, OBJPROP_XSIZE, btn_width);
        ObjectSetInteger(0, btn_name, OBJPROP_YSIZE, btn_height);
        ObjectSetInteger(0, btn_name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, btn_name, OBJPROP_COLOR, txt_color);
        ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, bg_color);
        ObjectSetInteger(0, btn_name, OBJPROP_BORDER_COLOR, border_color);
        ObjectSetString(0, btn_name, OBJPROP_TEXT, symbol);
        ObjectSetInteger(0, btn_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, btn_name, OBJPROP_STATE, false);
        
        display_count++;
    }
}

//+------------------------------------------------------------------+
//| 切换品种启用/禁用状态并立即开单                                   |
//+------------------------------------------------------------------+
void ToggleSymbol(int symbol_index)
{
    if(symbol_index < 0 || symbol_index >= ArraySize(g_available_symbols))
        return;
    
    string symbol = g_available_symbols[symbol_index];
    bool was_enabled = g_symbol_enabled[symbol_index];
    
    // 切换状态
    g_symbol_enabled[symbol_index] = !was_enabled;
    
    if(g_symbol_enabled[symbol_index])
    {
        Print("[MULTI-SYMBOL] Enabled: ", symbol);
        
        // 只有未开过首单才开单
        if(!g_symbol_first_order_opened[symbol_index])
        {
            OpenOrderForSymbol(symbol, symbol_index);
        }
    }
    else
    {
        Print("[MULTI-SYMBOL] Disabled: ", symbol);
        // 关闭该品种的所有持仓
        CloseSymbolPositions(symbol);
        // 重置首单标记，下次启用时可以重新开单
        g_symbol_first_order_opened[symbol_index] = false;
    }
}

//+------------------------------------------------------------------+
//| 为指定品种开单                                                    |
//+------------------------------------------------------------------+
void OpenOrderForSymbol(string symbol, int symbol_index)
{
    // 获取品种的价格信息
    double ask = MarketInfo(symbol, MODE_ASK);
    double bid = MarketInfo(symbol, MODE_BID);
    double point = MarketInfo(symbol, MODE_POINT);
    int digits = (int)MarketInfo(symbol, MODE_DIGITS);
    
    if(ask == 0 || bid == 0)
    {
        Print("[ERROR] Cannot get price for ", symbol);
        return;
    }
    
    // 根据交易模式确定方向
    int direction;
    if(g_trade_mode == 1) // 只开多
        direction = OP_BUY;
    else if(g_trade_mode == 2) // 只开空
        direction = OP_SELL;
    else // 双向模式，随机选择
        direction = (MathRand() % 2 == 0) ? OP_BUY : OP_SELL;
    
    double current_price = (ask + bid) / 2.0;
    
    // 生成订单备注
    string comment = GenerateOrderComment("Multi", symbol, 1);
    
    // 使用统一的开单函数
    if(OpenOrderForSymbol_Grid(symbol, direction, current_price, comment))
    {
        g_today_orders++;
        g_symbol_first_order_opened[symbol_index] = true; // 标记已开首单
        Print("[MULTI-SYMBOL] Order Opened | Symbol: ", symbol, 
              " | Direction: ", (direction == OP_BUY ? "BUY" : "SELL"), 
              " | Price: ", DoubleToString(current_price, digits));
    }
}

//+------------------------------------------------------------------+
//| 关闭指定品种的所有持仓                                            |
//+------------------------------------------------------------------+
void CloseSymbolPositions(string symbol)
{
    int magic_number = InpMagicNo;
    int closed_count = 0;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == symbol && OrderMagicNumber() == magic_number)
            {
                double close_price = (OrderType() == OP_BUY) ? 
                    MarketInfo(symbol, MODE_BID) : 
                    MarketInfo(symbol, MODE_ASK);
                    
                if(OrderClose(OrderTicket(), OrderLots(), close_price, 3, clrNONE))
                {
                    closed_count++;
                }
            }
        }
    }
    
    if(closed_count > 0)
        Print("[CLOSE] Closed ", closed_count, " positions for ", symbol);
}

//+------------------------------------------------------------------+
//| 保存品种启用状态到全局变量                                        |
//+------------------------------------------------------------------+
void SaveSymbolStates()
{
    // 清除旧的全局变量
    GlobalVariablesDeleteAll("PiGrid_Symbol_");
    
    // 保存每个品种的启用状态
    for(int i = 0; i < ArraySize(g_available_symbols); i++)
    {
        if(g_symbol_enabled[i])
        {
            string var_name = "PiGrid_Symbol_" + g_available_symbols[i];
            GlobalVariableSet(var_name, 1.0);
        }
    }
    
    Print("[SAVE] Saved ", ArraySize(g_available_symbols), " symbol states");
}

//+------------------------------------------------------------------+
//| 恢复品种启用状态                                                  |
//+------------------------------------------------------------------+
void RestoreSymbolStates()
{
    int restored_count = 0;
    
    // 遍历所有品种，检查是否有保存的状态
    for(int i = 0; i < ArraySize(g_available_symbols); i++)
    {
        string var_name = "PiGrid_Symbol_" + g_available_symbols[i];
        
        // 如果存在全局变量，说明之前启用过
        if(GlobalVariableCheck(var_name))
        {
            g_symbol_enabled[i] = true;
            restored_count++;
        }
    }
    
    if(restored_count > 0)
        Print("[RESTORE] Restored ", restored_count, " enabled symbols");
}

// 平亏损/平盈利功能已移除，简化为只保留一键平仓

//+------------------------------------------------------------------+
//| 检查日最大亏损限制                                                |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
    if(!InpEnableDailyLossLimit)
        return true;
        
    // 计算今日亏损
    if(g_today_profit <= -InpMaxDailyLoss)
    {
        Print("⛔ 日亏损限制触发 | 今日亏损: $", DoubleToString(g_today_profit, 2), " | 限制: $-", DoubleToString(InpMaxDailyLoss, 2));
        return false;
    }
    
    return true;
}

// Telegram通知功能已简化移除

//+------------------------------------------------------------------+
//| 更新品种按钮颜色（即时反馈）                                      |
//+------------------------------------------------------------------+
void UpdateSymbolButtonColor(int symbol_index, bool will_enable)
{
    if(symbol_index < 0 || symbol_index >= ArraySize(g_available_symbols))
        return;
    
    string symbol = g_available_symbols[symbol_index];
    string btn_name = "YDA_Btn_Symbol_" + (string)symbol_index;
    
    if(ObjectFind(0, btn_name) < 0)
        return;
    
    bool is_current = (symbol == Symbol());
    color bg_color;
    color txt_color;
    color border_color;
    
    if(is_current && will_enable)
    {
        // 当前品种且启用：鲜明蓝色+亮金色
        bg_color = C'70,110,180';      // 钴蓝色
        txt_color = C'255,223,0';       // 亮金色
        border_color = C'135,206,250';  // 天蓝色边框
    }
    else if(will_enable)
    {
        // 已启用：专业绿色+白色文字
        bg_color = C'34,139,34';        // 森林绿
        txt_color = C'255,255,255';     // 纯白色
        border_color = C'50,205,50';    // 亮绿边框
    }
    else
    {
        // 未启用：中性灰+淡文字
        bg_color = C'47,79,79';         // 深石板灰
        txt_color = C'169,169,169';     // 暗灰色
        border_color = C'105,105,105';  // 暗灰边框
    }
    
    // 立即更新按钮颜色
    ObjectSetInteger(0, btn_name, OBJPROP_COLOR, txt_color);
    ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, bg_color);
    ObjectSetInteger(0, btn_name, OBJPROP_BORDER_COLOR, border_color);
}
//+------------------------------------------------------------------+
