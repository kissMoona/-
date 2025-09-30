//+------------------------------------------------------------------+
//|                            Pi_Grid_Engine.mq4                    |
//|                           Copyright 2024, Rex                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Rex"
#property link      "https://github.com/yourname/Pi_Grid_Engine"
#property version   "1.20"
#property description "Π Grid Engine - Dual Mode Trading System"
#property strict

//--- 输入参数
//--- 面板设置
input bool   InpShowPanel = true;          // 是否显示信息面板
input int    InpPanelX = 100;               // 面板X轴位置
input int    InpPanelY = 100;               // 面板Y轴位置
input int    InpPanelFontSize = 15;        // 面板字体大小

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
input bool   InpEnableAlerts = true;       // 启用警报
input int    InpMaxOrdersAlert = 40;       // 持仓数警报阈值
input double InpMarginAlert = 80.0;        // 保证金使用率警报(%)
input double InpDrawdownAlert = 15.0;      // 浮亏百分比警报(%)

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

    Print("[INIT] Π Grid Engine v1.20 Started");
    if(InpTradingMode == 0)
        Print("[INIT] Mode: Grid Trading | Grid Step: $", InpGridStep);
    else
        Print("[INIT] Mode: Random Trading | Interval: ", InpRandomInterval, "s");
    
    //--- 创建按钮（调整位置以适应新面板）
    if(InpShowPanel)
    {
        CreateButton("YDA_Btn_CloseAll", InpPanelX + 10, InpPanelY + 370, 140, 35, "一键平仓", clrWhite, clrRed);
        CreateButton("YDA_Btn_BuyOnly", InpPanelX + 160, InpPanelY + 370, 140, 35, "只开多", clrWhite, clrGreen);
        CreateButton("YDA_Btn_SellOnly", InpPanelX + 310, InpPanelY + 370, 140, 35, "只开空", clrWhite, clrOrangeRed);
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("[DEINIT] Π Grid Engine Stopped | Reason Code: ", reason);
    //--- 清理面板对象
    if(InpShowPanel)
    {
        ObjectsDeleteAll(0, "YDA_Panel_");
        ObjectsDeleteAll(0, "YDA_Btn_");
        ObjectDelete(0, "YDA_Panel_BG");
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
        UpdateDashboard();
    
    //--- 检查警报
    if(InpEnableAlerts)
        CheckAlerts();

    //--- 管理保本损 (Breakeven)
    ManageTrailingStop();

    //--- 检查是否在交易时间内 (只对开仓有效)
    if(!IsTradeTime())
        return;

    //--- 执行交易逻辑
    if(InpTradingMode == 0)
        ManageLogic_Grid();  // 网格交易
    else
        ManageLogic_Random(); // 随机交易
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    //--- 处理按钮点击事件
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == "YDA_Btn_CloseAll")
        {
            CloseAllPositions();
            ObjectSetInteger(0, "YDA_Btn_CloseAll", OBJPROP_STATE, false);
        }
        else if(sparam == "YDA_Btn_BuyOnly")
        {
            ToggleBuyOnlyMode();
        }
        else if(sparam == "YDA_Btn_SellOnly")
        {
            ToggleSellOnlyMode();
        }
    }
}


//+------------------------------------------------------------------+
//| 管理单个交易逻辑                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 生成有趣的订单备注 (去月球/下地狱)                             |
//+------------------------------------------------------------------+
string GetDirectionalComment(int direction)
{
    string to_the_moon[] = {
        "To the Moon", "Rocket Launch", "Bull Charge", "Ignition Start", "Sky High",
        "Lift Off", "Apollo Mission", "Galaxy Quest", "Starlight", "Supernova",
        "Orion Spur", "Zenith", "Apogee", "Celestial", "Light Speed"
    };
    string to_hell[] = {
        "To Hell", "Bearish Dive", "Shorting Abyss", "Gravity Pull", "Underground",
        "Free Fall", "Hades Bound", "Into the Void", "Black Hole", "Earth Core",
        "Tartarus", "Nadir", "Perigee", "Chthonic", "Event Horizon"
    };
    
    int random_index = MathRand() % 15;
    
    if(direction == OP_BUY)
    {
        return to_the_moon[random_index];
    }
    else // OP_SELL
    {
        return to_hell[random_index];
    }
}

//+------------------------------------------------------------------+
//| 网格交易逻辑                                                      |
//+------------------------------------------------------------------+
void ManageLogic_Grid()
{
    int magic_number = InpMagicNo;
    double current_price = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) + SymbolInfoDouble(Symbol(), SYMBOL_BID)) / 2.0;
    
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
    
    //--- 如果没有持仓，开第一个订单
    if(total_orders == 0)
    {
        int direction;
        if(g_trade_mode == 1) // 只开多
            direction = OP_BUY;
        else if(g_trade_mode == 2) // 只开空
            direction = OP_SELL;
        else // 双向模式
            direction = (MathRand() % 2 == 0) ? OP_BUY : OP_SELL;
            
        if(OpenOrder(direction, current_price, "First Order"))
        {
            g_first_order_price = current_price;
            g_first_order_type = direction;
            g_today_orders++;
            Print("[GRID] First Order Opened | Price: ", DoubleToString(current_price, _Digits), " | Direction: ", (direction == OP_BUY ? "BUY" : "SELL"));
        }
        return;
    }
    
    //--- 检查是否需要在网格位置开新单
    CheckAndOpenGridOrders(current_price);
}

//+------------------------------------------------------------------+
//| 随机交易逻辑                                                      |
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
    string comment = "Random - " + GetDirectionalComment(direction);
    
    //--- 开单
    if(OpenOrder(direction, current_price, comment))
    {
        g_today_orders++;
        Print("[RANDOM] Order Opened | Price: ", DoubleToString(current_price, _Digits), " | Direction: ", (direction == OP_BUY ? "BUY" : "SELL"));
    }
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
                if(OpenOrder(OP_BUY, next_buy_level, "Grid Buy"))
                {
                    g_today_orders++;
                    Print("[GRID] BUY Order Opened | Level: ", DoubleToString(next_buy_level, _Digits));
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
                if(OpenOrder(OP_SELL, next_sell_level, "Grid Sell"))
                {
                    g_today_orders++;
                    Print("[GRID] SELL Order Opened | Level: ", DoubleToString(next_sell_level, _Digits));
                }
            }
        }
    }
    
    //--- 检查已有订单价格位置，价格回到该位置时开反向单
    for(int i = 0; i < order_count; i++)
    {
        double order_price = order_prices[i];
        int order_type = order_types[i];
        
        //--- 特殊规则：第一个订单位置如果是空单，价格回到该位置不开单
        if(MathAbs(order_price - g_first_order_price) < grid_step / 2.0 && g_first_order_type == OP_SELL)
        {
            continue;
        }
        
        //--- 如果当前价格接近某个已开订单的价格
        if(MathAbs(current_price - order_price) < grid_step / 10.0)
        {
            //--- 检查该价格是否已有反向订单
            bool has_opposite = false;
            int opposite_type = (order_type == OP_BUY) ? OP_SELL : OP_BUY;
            
            for(int j = 0; j < order_count; j++)
            {
                if(MathAbs(order_prices[j] - order_price) < grid_step / 10.0 && order_types[j] == opposite_type)
                {
                    has_opposite = true;
                    break;
                }
            }
            
            //--- 如果没有反向订单，则开反向单（考虑交易模式限制）
            if(!has_opposite)
            {
                bool can_open = true;
                if(g_trade_mode == 1 && opposite_type == OP_SELL) can_open = false; // 只开多模式，不开空单
                if(g_trade_mode == 2 && opposite_type == OP_BUY) can_open = false; // 只开空模式，不开多单
                
                if(can_open)
                {
                    if(OpenOrder(opposite_type, order_price, "Grid Reverse"))
                    {
                        g_today_orders++;
                        Print("[GRID] Reverse Order | Price: ", DoubleToString(order_price, _Digits), " | Direction: ", (opposite_type == OP_BUY ? "BUY" : "SELL"));
                    }
                }
            }
        }
    }
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
    
    //--- 生成订单备注
    string comment = comment_prefix + " - " + GetDirectionalComment(direction);
    
    //--- 计算SL和TP
    double sl_price, tp_price;
    int sl_points = InpBaseSL;
    int tp_points = (InpBaseTP <= 0) ? 0 : InpBaseTP;
    
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
        Print("[ERROR] Order Failed | Error: ", last_error, " | Direction: ", (direction == OP_BUY ? "BUY" : "SELL"), " | Price: ", DoubleToString(open_price, _Digits));
        return false;
    }
    else
    {
        Print("[SUCCESS] Order Opened | Ticket: ", ticket, " | Price: ", DoubleToString(open_price, _Digits), " | Direction: ", (direction == OP_BUY ? "BUY" : "SELL"), " | Lot: ", lot_size);
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
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    }
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void UpdateDashboard()
{
    //--- 统计持仓和盈亏
    int long_positions = 0;
    int short_positions = 0;
    int locked_pairs = 0;
    double total_profit = 0.0;
    double floating_pl = 0.0;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
             if(OrderSymbol() == Symbol())
             {
                int magic = OrderMagicNumber();
                if(magic == InpMagicNo)
                {
                    if(OrderType() == OP_BUY)
                        long_positions++;
                    else
                        short_positions++;
                    
                    double order_profit = OrderProfit() + OrderSwap() + OrderCommission();
                    total_profit += order_profit;
                    floating_pl += order_profit;
                }
             }
        }
    }
    
    int total_positions = long_positions + short_positions;
    locked_pairs = MathMin(long_positions, short_positions);
    
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

    //--- 创建面板背景（加大尺寸）
    string bg_name = "YDA_Panel_BG";
    if(ObjectFind(0, bg_name) < 0)
    {
        ObjectCreate(0, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, bg_name, OBJPROP_CORNER, 0);
        ObjectSetInteger(0, bg_name, OBJPROP_XDISTANCE, InpPanelX);
        ObjectSetInteger(0, bg_name, OBJPROP_YDISTANCE, InpPanelY);
        ObjectSetInteger(0, bg_name, OBJPROP_XSIZE, 460);
        ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, 420);
        ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR, C'20,20,20');
        ObjectSetInteger(0, bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, bg_name, OBJPROP_BORDER_COLOR, clrGold);
        ObjectSetInteger(0, bg_name, OBJPROP_BACK, false);
    }

    //--- 显示信息（优化排版）
    int y_pos = InpPanelY + 10;
    int x_pos = InpPanelX + 10;
    int x_pos2 = InpPanelX + 240; // 第二列
    int line_height = 18;

    // 标题
    string title_text = "═══ Π Grid Engine ═══";
    if(InpTradingMode == 1) title_text = "═══ Π Random Mode ═══";
    CreateLabel("YDA_Panel_Title", x_pos, y_pos, title_text, clrGold, 12);
    y_pos += 25;
    
    // 分隔线
    CreateLabel("YDA_Panel_Sep1", x_pos, y_pos, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", C'100,100,100', 8);
    y_pos += 15;
    
    // 第一部分：持仓统计
    CreateLabel("YDA_Panel_Section1", x_pos, y_pos, "【 持仓统计 】", clrAqua, 11);
    y_pos += line_height + 3;
    
    CreateLabel("YDA_Panel_Long", x_pos, y_pos, "多单: " + (string)long_positions, clrLimeGreen, 10);
    CreateLabel("YDA_Panel_Short", x_pos2, y_pos, "空单: " + (string)short_positions, clrOrangeRed, 10);
    y_pos += line_height;
    
    CreateLabel("YDA_Panel_Total", x_pos, y_pos, "总持仓: " + (string)total_positions, clrWhite, 10);
    CreateLabel("YDA_Panel_Locked", x_pos2, y_pos, "锁仓对: " + (string)locked_pairs, clrYellow, 10);
    y_pos += line_height;
    
    CreateLabel("YDA_Panel_MaxPos", x_pos, y_pos, "最大持仓: " + (string)g_max_positions, C'150,150,150', 10);
    
    // 交易模式
    string mode_text = "模式: ";
    color mode_color = clrWhite;
    if(g_trade_mode == 0) { mode_text += "双向"; mode_color = clrWhite; }
    else if(g_trade_mode == 1) { mode_text += "只开多"; mode_color = clrLimeGreen; }
    else if(g_trade_mode == 2) { mode_text += "只开空"; mode_color = clrOrangeRed; }
    CreateLabel("YDA_Panel_TradeMode", x_pos2, y_pos, mode_text, mode_color, 10);
    y_pos += line_height + 8;
    
    // 分隔线
    CreateLabel("YDA_Panel_Sep2", x_pos, y_pos, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", C'100,100,100', 8);
    y_pos += 15;
    
    // 第二部分：账户信息
    CreateLabel("YDA_Panel_Section2", x_pos, y_pos, "【 账户信息 】", clrAqua, 11);
    y_pos += line_height + 3;
    
    CreateLabel("YDA_Panel_Balance", x_pos, y_pos, "余额: $" + DoubleToString(account_balance, 2), clrWhite, 10);
    CreateLabel("YDA_Panel_Equity", x_pos2, y_pos, "净值: $" + DoubleToString(account_equity, 2), clrWhite, 10);
    y_pos += line_height;
    
    color pl_color = (floating_pl >= 0) ? clrLimeGreen : clrRed;
    string pl_sign = (floating_pl >= 0) ? "+" : "";
    CreateLabel("YDA_Panel_FloatPL", x_pos, y_pos, "浮动: " + pl_sign + "$" + DoubleToString(floating_pl, 2), pl_color, 10);
    
    double margin_percent = (margin_free > 0) ? (margin_used / (margin_used + margin_free) * 100.0) : 0;
    color margin_color = (margin_percent > 80) ? clrRed : (margin_percent > 60) ? clrYellow : clrLimeGreen;
    CreateLabel("YDA_Panel_Margin", x_pos2, y_pos, "保证金: " + DoubleToString(margin_percent, 1) + "%", margin_color, 10);
    y_pos += line_height + 8;
    
    // 分隔线
    CreateLabel("YDA_Panel_Sep3", x_pos, y_pos, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", C'100,100,100', 8);
    y_pos += 15;
    
    // 第三部分：今日统计
    CreateLabel("YDA_Panel_Section3", x_pos, y_pos, "【 今日统计 】", clrAqua, 11);
    y_pos += line_height + 3;
    
    CreateLabel("YDA_Panel_TodayOrders", x_pos, y_pos, "开单数: " + (string)g_today_orders, clrWhite, 10);
    
    color today_pl_color = (g_today_profit >= 0) ? clrLimeGreen : clrRed;
    string today_pl_sign = (g_today_profit >= 0) ? "+" : "";
    CreateLabel("YDA_Panel_TodayPL", x_pos2, y_pos, "盈亏: " + today_pl_sign + "$" + DoubleToString(g_today_profit, 2), today_pl_color, 10);
    y_pos += line_height;
    
    string server_time = TimeToString(TimeCurrent(), TIME_SECONDS);
    CreateLabel("YDA_Panel_Time", x_pos, y_pos, "时间: " + server_time, C'150,150,150', 9);
    y_pos += line_height + 8;
    
    // 分隔线
    CreateLabel("YDA_Panel_Sep4", x_pos, y_pos, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", C'100,100,100', 8);
    y_pos += 15;
    
    // 状态栏
    color status_color = clrLimeGreen;
    string status_text = "● 运行中";
    if(!IsTradeTime())
    {
        status_color = clrYellow;
        status_text = "● 非交易时段";
    }
    CreateLabel("YDA_Panel_Status", x_pos, y_pos, status_text, status_color, 10);
    
    // 警报指示
    string alert_text = "";
    color alert_color = clrWhite;
    if(total_positions >= InpMaxOrdersAlert)
    {
        alert_text = "⚠ 持仓数警报";
        alert_color = clrRed;
    }
    else if(margin_percent >= InpMarginAlert)
    {
        alert_text = "⚠ 保证金警报";
        alert_color = clrOrange;
    }
    else if(drawdown_percent >= InpDrawdownAlert)
    {
        alert_text = "⚠ 回撤警报";
        alert_color = clrOrange;
    }
    
    if(alert_text != "")
        CreateLabel("YDA_Panel_Alert", x_pos2, y_pos, alert_text, alert_color, 10);
    else
        CreateLabel("YDA_Panel_Alert", x_pos2, y_pos, "", clrWhite, 10);
    
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
                    double new_sl_price, new_tp_price;
                    int sl_points = InpBaseSL;
                    // 当基础TP为0时，表示不设置止盈
                    bool no_takeprofit = (InpBaseTP <= 0);
                    int tp_points = no_takeprofit ? 0 : InpBaseTP;
                    double point = _Point;

                    if(OrderType() == OP_BUY)
                    {
                        new_sl_price = OrderOpenPrice() - sl_points * point;
                        new_tp_price = no_takeprofit ? 0 : (OrderOpenPrice() + tp_points * point);
                    }
                    else // OP_SELL
                    {
                        new_sl_price = OrderOpenPrice() + sl_points * point;
                        new_tp_price = no_takeprofit ? 0 : (OrderOpenPrice() - tp_points * point);
                    }

                    // 标准化价格
                    new_sl_price = NormalizeDouble(new_sl_price, _Digits);
                    if(new_tp_price != 0) new_tp_price = NormalizeDouble(new_tp_price, _Digits);

                    // 检查SL/TP是否需要更新
                    // 重要: 如果保本损已触发，则不再调整止损
                    bool isBreakevenTriggered = false;
                    if (InpTPA > 0) 
                    {
                        if (OrderType() == OP_BUY && OrderStopLoss() >= OrderOpenPrice()) isBreakevenTriggered = true;
                        if (OrderType() == OP_SELL && OrderStopLoss() <= OrderOpenPrice() && OrderStopLoss() != 0) isBreakevenTriggered = true;
                    }

                    double target_sl = isBreakevenTriggered ? OrderStopLoss() : new_sl_price;
                    double target_tp = new_tp_price; // 允许为0，表示不设TP

                    if(MathAbs(OrderStopLoss() - target_sl) > point / 2.0 || MathAbs(OrderTakeProfit() - target_tp) > point / 2.0)
                    {
                        if(!OrderModify(OrderTicket(), OrderOpenPrice(), target_sl, target_tp, 0, clrNONE))
                        {
                            // 忽略"no changes"错误
                            if(GetLastError() != 1) 
                                Print("[ERROR] Parameter Update Failed | Ticket: ", OrderTicket(), " | Error: ", GetLastError());
                        }
                        else
                        {
                            Print("[UPDATE] Parameter Updated | Ticket: ", OrderTicket(), " | New SL: ", DoubleToString(target_sl, _Digits), " | New TP: ", DoubleToString(target_tp, _Digits));
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
    if(ObjectFind(0, name) < 0)
    {
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
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
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
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_BGCOLOR, clrDarkGreen);
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_STATE, true);
        }
        else
        {
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_BGCOLOR, clrGreen);
            ObjectSetInteger(0, "YDA_Btn_BuyOnly", OBJPROP_STATE, false);
        }
    }
    
    // 更新"只开空"按钮状态
    if(ObjectFind(0, "YDA_Btn_SellOnly") >= 0)
    {
        if(g_trade_mode == 2)
        {
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_BGCOLOR, clrDarkRed);
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_STATE, true);
        }
        else
        {
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_BGCOLOR, clrOrangeRed);
            ObjectSetInteger(0, "YDA_Btn_SellOnly", OBJPROP_STATE, false);
        }
    }
}

//+------------------------------------------------------------------+
//| 一键平仓                                                          |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    int magic_number = InpMagicNo;
    int closed_count = 0;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            {
                double close_price = (OrderType() == OP_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_BID) : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
                if(OrderClose(OrderTicket(), OrderLots(), close_price, 3, clrNONE))
                {
                    closed_count++;
                }
                else
                {
                    Print("[ERROR] Close Failed | Ticket: ", OrderTicket(), " | Error: ", GetLastError());
                }
            }
        }
    }
    
    Print("[CLOSE] All Positions Closed | Count: ", closed_count);
    
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
    
    int magic_number = InpMagicNo;
    int total_positions = 0;
    double total_profit = 0.0;
    
    // 统计持仓
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            {
                total_positions++;
                total_profit += OrderProfit() + OrderSwap() + OrderCommission();
            }
        }
    }
    
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
