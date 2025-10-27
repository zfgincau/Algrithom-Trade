//+------------------------------------------------------------------+
//|                  AdvancedMartingale_EA_v6.141_fixsleepbug.mq5   |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "6.141"
#property description "高级自适应马丁策略 v6.141fix3 (短时间每日休眠版本)"
#property description "优化动态加仓间隔 + 三级优先级系统 + 修正盈利率递减 + 短时间每日休眠避免过夜费"

//--- 策略模式枚举
enum ENUM_STRATEGY_MODE
{
   MODE_SINGLE_TREND,        // 单边趋势马丁
   MODE_HEDGE_COUNTER,       // 双边逆势对冲
   MODE_HEDGE_TREND          // 双边顺势对冲
};

//--- 输入参数
input group "=== 基础参数 ==="
input double   InitialLot         = 0.01;     // 初始手数
input double   MartingaleMultiplier = 2.0;    // 马丁倍数
input int      DefaultStepPoints  = 100;      // 默认加仓间距（点数）
input int      MaxOrders          = 9;        // 最大订单数
input int      MagicNumber        = 666666;   // 魔术数字

input group "=== 保证金盈利率参数 ==="
input double   Leverage           = 500.0;    // 杠杆倍数
input double   FirstOrderMaxMarginRate = 100.0; // 第一单最大保证金盈利率（%）
input double   SecondOrderMaxMarginRate = 60.0; // 第二单最大保证金盈利率（%）
input double   ThirdOrderMaxMarginRate = 30.0;  // 第三单最大保证金盈利率（%）
input double   FourthOrderMaxMarginRate = 15.0; // 第四单最大保证金盈利率（%）
input double   MarginRateDecay   = 0.6;       // 保证金盈利率递减系数

input group "=== 动态间隔参数 ==="
input bool     UseDynamicStep     = true;     // 启用动态间隔
input double   StepMultiplier     = 1.0;      // 间隔乘数
input int      MinStepPoints      = 100;      // 最小间隔（点数）
input int      MaxStepPoints      = 1200;     // 最大间隔（点数）

input group "=== 波动权重系数(优先级1) ==="
input double   Weight_250pts      = 0.7;      // 波动超250点权重系数
input double   Weight_300pts      = 0.9;      // 波动超300点权重系数
input double   Weight_350pts      = 1.2;      // 波动超350点权重系数
input double   Weight_400pts      = 2.0;      // 波动超400点权重系数
input double   Minute1_WeakenFactor = 0.85;   // 1分钟波动弱化系数

input group "=== 波动率比较系数(优先级2) ==="
input bool     EnableVolatilityRatio = true;  // 启用5m/30m波动率比较
input double   MinVolatilityRatio = 1.2;      // 最小波动率比值

input group "=== 快速加仓扩大系数(优先级3) ==="
input bool     EnableFastMartingale = true;   // 启用快速加仓检测
input int      FastMartingaleMinutes = 3;     // 快速加仓时间阈值(分钟)
input int      FastMartingaleOrders = 4;      // 快速加仓订单数阈值
input double   FastMartingaleMultiplier = 1.2; // 快速加仓扩大系数

input group "=== 波动预测权重 ==="
input double   Weight30s          = 0.45;     // 30秒权重
input double   Weight30s_1_5m     = 0.25;     // 30秒-1.5分钟权重
input double   Weight1_5m_5m      = 0.15;     // 1.5-5分钟权重
input double   Weight5m_15m       = 0.10;     // 5-15分钟权重
input double   Weight15m_30m      = 0.05;     // 15-30分钟权重

input group "=== 方向预测权重 ==="
input double   DirWeight1m        = 0.10;    // 1分钟方向权重
input double   DirWeight5m        = 0.30;    // 5分钟方向权重
input double   DirWeight15m       = 0.40;    // 15分钟方向权重
input double   DirWeight1h        = 0.20;    // 1小时方向权重

input group "=== 多维度趋势判断权重 ==="
input double   TrendMethodWeight  = 0.25;    // 趋势法权重(25%)
input double   MLFeatureWeight    = 0.30;    // ML特征权重(30%)
input double   OrderFlowWeight    = 0.20;    // 订单流权重(20%)
input double   SRLevelWeight      = 0.25;    // 支撑阻力权重(25%)

input group "=== 四因子盈利目标权重 ==="
input double   MultiFactorWeight  = 0.35;    // 多因子权重(35%)
input double   VolatilityPredWeight = 0.25;  // 波动预测权重(25%)
input double   ProbExpectWeight   = 0.25;    // 概率期望权重(25%)
input double   RiskRewardWeight   = 0.15;    // 风险收益权重(15%)

input group "=== 极端预防 ==="
input bool     EnableExtremePrevention = true; // 启用极端预防
input double   ExtremeThreshold  = 2.5;       // 极端行情阈值
input int      RestMinutes       = 5;         // 休息时间（分钟）

input group "=== 风险控制 ==="
input int      RiskSwitchOrders   = 6;        // 超过此单数切换顺势
input int      DangerOrders       = 9;        // 危险订单数阈值
input double   ExtremeATRMultiplier = 3.0;    // 极端ATR倍数

input group "=== 市场识别 ==="
input int      ATRPeriod          = 14;       // ATR周期
input int      TrendStrengthPeriod = 20;      // 趋势强度周期
input double   StrongTrendThreshold = 60;     // 强趋势阈值（0-100）
input double   WeakTrendThreshold = 30;       // 弱趋势阈值（0-100）

input group "=== 交易控制 ==="
input bool     AutoOpenFirstOrder = true;     // 自动开第一单
input bool     StopOnExtreme      = true;     // 极端行情停止
input bool     AutoSwitchStrategy = true;     // 自动切换策略
input bool     EnableConfidenceCheck = false; // 启用信心度检查（默认关闭）
input double   ConfidenceThreshold = 0.6;     // 信心度阈值（0-1）

input group "=== 时间风险控制 ==="
input bool     EnableTimeControl  = true;     // 启用时间风险控制
input bool     NoWeekendPositions = true;     // 禁止周末持仓
input int      FridayCloseHour    = 22;       // 周五平仓时间(小时)
input int      FridayCloseMin     = 0;        // 周五平仓时间(分钟)
input double   ExtremeVolThreshold = 3.0;     // 极端波动阈值(倍数)

input group "=== 黄金市场时间节点控制 ==="
input bool     EnableMarketTimeControl = true;    // 启用市场时间节点控制
input int      BeforeKeyTimeMinutes = 15;         // 关键时间前禁止开单(分钟)
input int      AfterKeyTimeMinutes = 10;          // 关键时间后禁止开单(分钟)
input int      DailyCloseHour = 5;                // 每日收盘时间(小时)
input int      DailyCloseMin = 0;                 // 每日收盘时间(分钟)
input int      DailyOpenHour = 6;                 // 每日开盘时间(小时)
input int      DailyOpenMin = 0;                  // 每日开盘时间(分钟)
input int      BeforeCloseMinutes = 20;           // 收盘前禁止开单(分钟)
input int      AfterOpenMinutes = 10;             // 开盘后禁止开单(分钟)

input group "=== 市场盘切换时间(北京时间) ==="
input int      AsiaOpenHour = 8;                  // 亚洲盘开盘(小时)
input int      AsiaOpenMin = 0;                   // 亚洲盘开盘(分钟)
input int      EuropeOpenHour = 15;               // 欧洲盘开盘(小时,夏令时16:00)
input int      EuropeOpenMin = 0;                 // 欧洲盘开盘(分钟)
input int      USOpenHour = 20;                   // 美国盘开盘(小时,夏令时21:00)
input int      USOpenMin = 30;                    // 美国盘开盘(分钟)

input group "=== 重要数据公布时间(北京时间) ==="
input bool     AvoidNonFarmPayroll = true;        // 避开非农数据
input string   NonFarmDayOfWeek = "5";            // 非农日期(每月第一个周五)
input int      NonFarmHour = 20;                  // 非农公布时间(小时)
input int      NonFarmMin = 30;                   // 非农公布时间(分钟)
input bool     AvoidCPIData = true;               // 避开CPI数据
input int      CPIHour = 20;                      // CPI公布时间(小时)
input int      CPIMin = 30;                       // CPI公布时间(分钟)
input bool     AvoidFOMC = true;                  // 避开FOMC会议
input int      FOMCHour = 2;                      // FOMC公布时间(小时)
input int      FOMCMin = 0;                       // FOMC公布时间(分钟)
input bool     AvoidInitialClaims = true;         // 避开初请失业金
input int      InitialClaimsHour = 20;            // 初请公布时间(小时)
input int      InitialClaimsMin = 30;             // 初请公布时间(分钟)

input group "=== 日志设置 ==="
input bool     EnableFileLog      = true;     // 启用文件日志
input string   LogFileName        = "EA_v6.141_Log.txt"; // 日志文件名

//--- 全局变量
double lastBuyPrice = 0;
double lastSellPrice = 0;
int totalBuyOrders = 0;
int totalSellOrders = 0;
int totalOrders = 0;
ENUM_POSITION_TYPE firstDirection = -1;

//--- 策略状态
ENUM_STRATEGY_MODE currentMode = MODE_HEDGE_COUNTER;
bool tradingPaused = false;
bool martingaleEnabled = true;
bool autoOpenEnabled = true;
bool firstOrderOpened = false;

//--- 统计变量
int totalRounds = 0;
double totalProfitSum = 0;
int winRounds = 0;

//--- 指标句柄
int atrHandle = INVALID_HANDLE;

//--- 按钮名称
string btnClose = "BtnClose";
string btnOpen = "BtnOpen";
string btnMartin = "BtnMartin";
string btnAuto = "BtnAuto";
string btnMode = "BtnMode";
string btnWakeUp = "BtnWakeUp";

//--- 按钮布局
int buttonStartX = 320;
int buttonStartY = 390;
int buttonWidth = 140;
int buttonHeight = 30;
int buttonSpacing = 6;

//--- 动态参数
double currentStepPoints = 100;
double currentMarginProfitRate = 0;

//--- 预测状态
string predictionStatus = "评估中...";
int predictionDirection = 0;
double predictionConfidenceValue = 0;
double predictionStrength = 0;
string predictionAdvice = "观望";
bool canOpenOrder = true;
string noTradeReason = "";

//--- 多维度评分
double trendMethodScore = 0;
double mlFeatureScore = 0;
double orderFlowScore = 0;
double srLevelScore = 0;

//--- 四因子盈利目标
double multiFactorTarget = 0;
double volatilityPredTarget = 0;
double probExpectTarget = 0;
double riskRewardTarget = 0;

//--- 极端预防
datetime lastExtremeTime = 0;
bool extremeDetected = false;

//--- 加仓时间记录
datetime firstOrderTime = 0;
datetime lastOrderTime = 0;
datetime orderTimes[9];  // 记录每个订单的开仓时间

//--- 休眠状态
bool isSleeping = false;
string sleepReason = "";
datetime sleepStartTime = 0;
datetime sleepEndTime = 0;
datetime nextSleepTime = 0;      // 下次休眠时间
string nextSleepReason = "";     // 下次休眠原因

//--- 24小时交易事件显示
string next24hEvents = "";       // 未来24小时交易事件

//--- 日志文件句柄
int logFileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("高级马丁策略 v6.141fix3 已启动 (短时间每日休眠版本)");
   Print("品种: ", _Symbol);
   Print("特性: 优化动态间隔 + 三级优先级系统 + 修正盈利率递减");
   Print("新特性: 休眠时当前轮继续交易，达到目标后不再开新单");
   Print("新特性: 显示休眠预警和下次交易盘信息");
   Print("重要修改: 短时间每日休眠避免过夜费（收盘前20分钟，开盘后10分钟）");
   Print("新功能: 图表右边显示未来24小时交易事件");
   Print("========================================");
   
   // 初始化日志文件
   if(EnableFileLog)
   {
      InitializeLogFile();
   }
   
   // 初始化时间记录数组
   ArrayInitialize(orderTimes, 0);
   
   WriteLog("========================================");
   WriteLog("EA v6.141fix 启动 (修复休眠Bug版本)");
   WriteLog("品种: " + _Symbol);
   WriteLog("账户: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
   WriteLog("杠杆: " + DoubleToString(Leverage, 0) + "倍");
   WriteLog("--- 动态间隔系统 ---");
   WriteLog("间隔范围: " + IntegerToString(MinStepPoints) + "-" + IntegerToString(MaxStepPoints) + "点");
   WriteLog("波动权重系数(优先级1): 启用");
   WriteLog("5m/30m比值系统(优先级2): " + (EnableVolatilityRatio ? "启用" : "禁用"));
   WriteLog("快速加仓检测(优先级3): " + (EnableFastMartingale ? "启用" : "禁用"));
   WriteLog("--- 盈利率目标递减 ---");
   WriteLog("第1单: 最高100%, 第2单: 60%, 第3单: 30%, 第4单: 15%, 之后按0.6递减");
   WriteLog("--- 基础时间控制 ---");
   WriteLog("时间控制: " + (EnableTimeControl ? "启用" : "禁用"));
   WriteLog("不留周末: " + (NoWeekendPositions ? "是" : "否"));
   WriteLog("--- 黄金市场时间节点控制 ---");
   WriteLog("市场时间控制: " + (EnableMarketTimeControl ? "启用" : "禁用"));
   if(EnableMarketTimeControl)
   {
      WriteLog(StringFormat("关键时间窗口: 前%d分钟 / 后%d分钟", BeforeKeyTimeMinutes, AfterKeyTimeMinutes));
      WriteLog(StringFormat("每日收盘: %02d:%02d (前%d分钟禁止)", DailyCloseHour, DailyCloseMin, BeforeCloseMinutes));
      WriteLog(StringFormat("每日开盘: %02d:%02d (后%d分钟禁止)", DailyOpenHour, DailyOpenMin, AfterOpenMinutes));
      WriteLog(StringFormat("亚洲盘开盘: %02d:%02d", AsiaOpenHour, AsiaOpenMin));
      WriteLog(StringFormat("欧洲盘开盘: %02d:%02d", EuropeOpenHour, EuropeOpenMin));
      WriteLog(StringFormat("美国盘开盘: %02d:%02d", USOpenHour, USOpenMin));
      WriteLog("避开非农: " + (AvoidNonFarmPayroll ? "是" : "否"));
      WriteLog("避开CPI: " + (AvoidCPIData ? "是" : "否"));
      WriteLog("避开FOMC: " + (AvoidFOMC ? "是" : "否"));
      WriteLog("避开初请: " + (AvoidInitialClaims ? "是" : "否"));
   }
   WriteLog("========================================");
   
   // 初始化ATR指标
   atrHandle = iATR(_Symbol, PERIOD_M5, ATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("错误：无法创建ATR指标");
      WriteLog("错误：无法创建ATR指标");
      return(INIT_FAILED);
   }
   
   CreateControlButtons();
   CreateInfoLabels();
   CountOrders();
   
   if(totalOrders > 0)
   {
      firstOrderOpened = true;
      UpdateLastPrices();
      DetermineFirstDirection();
      WriteLog("检测到现有持仓: 多" + IntegerToString(totalBuyOrders) + "个, 空" + IntegerToString(totalSellOrders) + "个");
   }
   else
   {
      if(AutoOpenFirstOrder && autoOpenEnabled)
      {
         WriteLog("自动模式：立即尝试开仓...");
         if(OpenFirstOrder())
         {
            WriteLog("首单开仓成功");
         }
         else
         {
            WriteLog("首单开仓失败：" + noTradeReason);
         }
      }
   }
   
   // 初始化时计算24小时交易事件
   CalculateNext24hEvents();
   Print("未来24小时交易事件: ", next24hEvents);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 释放指标句柄
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   
   // 删除界面元素
   ObjectDelete(0, btnClose);
   ObjectDelete(0, btnOpen);
   ObjectDelete(0, btnMartin);
   ObjectDelete(0, btnAuto);
   ObjectDelete(0, btnMode);
   ObjectDelete(0, btnWakeUp);
   DeleteInfoLabels();
   Comment("");
   
   WriteLog("========================================");
   WriteLog("EA v6.141fix 停止");
   WriteLog("总轮数: " + IntegerToString(totalRounds) + " | 盈利轮数: " + IntegerToString(winRounds));
   if(totalRounds > 0)
      WriteLog("胜率: " + DoubleToString((double)winRounds/totalRounds*100, 2) + "%");
   WriteLog("========================================");
   
   // 关闭日志文件
   if(logFileHandle != INVALID_HANDLE)
   {
      FileClose(logFileHandle);
      logFileHandle = INVALID_HANDLE;
   }
   
   Print("========================================");
   Print("高级马丁策略 v6.141fix 已停止");
   Print("总轮数: ", totalRounds, " | 盈利轮数: ", winRounds);
   if(totalRounds > 0)
      Print("胜率: ", DoubleToString((double)winRounds/totalRounds*100, 2), "%");
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 核心修改: 优先级1: 手动休眠检查（最高优先级）
   if(isSleeping)
   {
      // 检查休眠时间是否结束（仅对自动休眠有效）
      if(sleepEndTime > 0 && TimeCurrent() >= sleepEndTime)
      {
         WriteLog("休眠结束,自动恢复交易: " + sleepReason);
         isSleeping = false;
         sleepReason = "";
         sleepStartTime = 0;
         sleepEndTime = 0;
         
         // 更新按钮文本
         ObjectSetString(0, btnWakeUp, OBJPROP_TEXT, "休眠");
      }
      else if(sleepEndTime == 0 && totalOrders == 0)
      {
         // 手动休眠且无持仓，需要手动唤醒，不执行任何逻辑
         return;
      }
      // 关键修改: 如果处于休眠状态但有持仓，继续执行后续逻辑，让当前轮正常交易
      // 只是阻止开新的第一单
   }
   
   // 优先级2: 时间风险控制检查
   if(EnableTimeControl && !CheckTimeRisk())
   {
      if(!isSleeping)
      {
         isSleeping = true;
         sleepReason = noTradeReason;
         sleepStartTime = TimeCurrent();
         sleepEndTime = CalculateSleepEndTime(noTradeReason);
         WriteLog("进入休眠状态: " + sleepReason);
         WriteLog("重要当前轮交易将继续正常执行（计算加仓间隔、盈利率目标、执行加仓）");
         WriteLog("重要当前轮达到盈利目标平仓后，将不再开始新一轮交易");
         
         // 更新按钮文本
         ObjectSetString(0, btnWakeUp, OBJPROP_TEXT, "唤醒");
      }
      
      // 关键修改不再直接return，让后续逻辑继续执行
      // 休眠状态只阻止开新的第一单，不阻止当前轮的加仓和平仓
   }
   
   // 修改检查极端预防
   if(EnableExtremePrevention && CheckExtremeMarket())
   {
      if(!tradingPaused)
      {
         WriteLog("检测到极端行情！暂停交易 " + IntegerToString(RestMinutes) + " 分钟");
         tradingPaused = true;
         extremeDetected = true;
         lastExtremeTime = TimeCurrent();
         
         // 设置休眠状态
         isSleeping = true;
         sleepReason = "极端行情保护";
         sleepStartTime = TimeCurrent();
         sleepEndTime = TimeCurrent() + RestMinutes * 60;
         
         WriteLog("重要当前轮交易将继续正常执行（计算加仓间隔、盈利率目标、执行加仓）");
         WriteLog("重要当前轮达到盈利目标平仓后，将不再开始新一轮交易");
         
         noTradeReason = "极端行情休息" + IntegerToString(RestMinutes) + "分钟";
         ObjectSetString(0, btnMode, OBJPROP_TEXT, "休眠" + IntegerToString(RestMinutes) + "m");
         ObjectSetInteger(0, btnMode, OBJPROP_BGCOLOR, clrRed);
         
         // 显示唤醒按钮
         if(ObjectFind(0, btnWakeUp) < 0)
         {
            CreateButton(btnWakeUp, "唤醒", buttonStartX, buttonStartY + (buttonHeight+buttonSpacing)*5, clrWhite, clrOrange);
         }
      }
      // 关键修改不再直接return，继续执行后续逻辑
      // 让当前轮交易正常完成
   }
   else if(tradingPaused && extremeDetected)
   {
      // 检查休息时间是否结束
      int remainingSeconds = RestMinutes * 60 - (int)(TimeCurrent() - lastExtremeTime);
      if(remainingSeconds <= 0)
      {
         WriteLog("极端行情休息时间结束,恢复交易");
         tradingPaused = false;
         extremeDetected = false;
         isSleeping = false;
         sleepReason = "";
         noTradeReason = "";
         UpdateModeButton();
         
         // 隐藏唤醒按钮
         ObjectDelete(0, btnWakeUp);
      }
      else
      {
         // 更新休眠倒计时显示
         int remainingMinutes = remainingSeconds / 60;
         int remainingSecs = remainingSeconds % 60;
         noTradeReason = "极端行情休息" + IntegerToString(remainingMinutes) + "分" + IntegerToString(remainingSecs) + "秒";
         ObjectSetString(0, btnMode, OBJPROP_TEXT, "休眠" + IntegerToString(remainingMinutes) + "m" + IntegerToString(remainingSecs) + "s");
         return;
      }
   }
   else if(tradingPaused && !extremeDetected)
   {
      WriteLog("市场恢复正常,继续交易");
      tradingPaused = false;
      isSleeping = false;
      sleepReason = "";
      noTradeReason = "";
      UpdateModeButton();
      
      // 隐藏唤醒按钮
      ObjectDelete(0, btnWakeUp);
   }
   
   CountOrders();
   
   // 新增计算下次休眠时间（预警功能）
   if(!isSleeping)
   {
      CalculateNextSleepTime();
   }
   
   // 计算未来24小时交易事件
   CalculateNext24hEvents();
   
   // 风险控制：超过6单考虑切换顺势对冲
   if(totalOrders > RiskSwitchOrders && currentMode != MODE_HEDGE_TREND)
   {
      WriteLog("仓位风险：" + IntegerToString(totalOrders) + "单，切换为顺势对冲");
      currentMode = MODE_HEDGE_TREND;
      UpdateModeButton();
   }
   
   // 实时预测评估
   EvaluateFutureTrend();
   
   // 自动开单逻辑：如果没有持仓，自动开单（休眠状态下不开新单）
   if(totalOrders == 0 && !firstOrderOpened && autoOpenEnabled && !tradingPaused && !isSleeping)
   {
      static datetime lastAttemptTime = 0;
      datetime currentTime = TimeCurrent();
      
      // 每60秒尝试一次开单
      if(currentTime - lastAttemptTime >= 60)
      {
         WriteLog("自动开单：尝试开单...");
         if(OpenFirstOrder())
         {
            WriteLog("自动开单成功");
         }
         else
         {
            WriteLog("自动开单失败：" + noTradeReason);
         }
         lastAttemptTime = currentTime;
      }
   }
   
   double totalProfit = CalculateTotalProfit();
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double marginProfitRate = CalculateMarginProfitRate();
   double targetMarginRate = CalculateDynamicMarginProfitRate();
   
   // 计算动态间隔
   if(UseDynamicStep)
      currentStepPoints = CalculateDynamicStepPoints();
   else
      currentStepPoints = DefaultStepPoints;
   
   static int tickCount = 0;
   tickCount++;
   if(tickCount >= 30)
   {
      UpdateDisplay(totalProfit, marginProfitRate, targetMarginRate);
      UpdateInfoLabels();
      tickCount = 0;
   }
   
   // 检查止盈
   if(marginProfitRate >= targetMarginRate && totalOrders > 0)
   {
      string logMsg = "========================================\n";
      logMsg += ">>> 达到目标保证金盈利率！\n";
      logMsg += "当前保证金盈利率: " + DoubleToString(marginProfitRate, 3) + "%\n";
      logMsg += "目标保证金盈利率: " + DoubleToString(targetMarginRate, 3) + "%\n";
      logMsg += "本轮盈利: $" + DoubleToString(totalProfit, 2) + "\n";
      logMsg += "账户余额: $" + DoubleToString(accountBalance, 2) + "\n";
      
      WriteLog(logMsg);
      Print(logMsg);
      
      // 统计
      totalRounds++;
      if(totalProfit > 0) winRounds++;
      totalProfitSum += totalProfit;
      
      string statsMsg = "--- 本轮统计 ---\n";
      statsMsg += "轮数: 第" + IntegerToString(totalRounds) + "轮\n";
      statsMsg += "盈利金额: $" + DoubleToString(totalProfit, 2) + "\n";
      statsMsg += "保证金盈利率: " + DoubleToString(marginProfitRate, 3) + "%\n";
      statsMsg += "策略模式: " + GetModeName(currentMode) + "\n";
      statsMsg += "订单总数: " + IntegerToString(totalOrders) + "\n";
      statsMsg += "--- 累计统计 ---\n";
      statsMsg += "总轮数: " + IntegerToString(totalRounds) + "\n";
      statsMsg += "盈利轮数: " + IntegerToString(winRounds) + "\n";
      if(totalRounds > 0)
         statsMsg += "胜率: " + DoubleToString((double)winRounds/totalRounds*100, 2) + "%\n";
      statsMsg += "累计盈利: $" + DoubleToString(totalProfitSum, 2) + "\n";
      
      WriteLog(statsMsg);
      Print(statsMsg);
      
      CloseAllOrders();
      Sleep(2000);
      
      // 核心修改如果处于休眠状态，达到盈利目标后不再开新单
      // 保持休眠状态，直到休眠时间结束或手动唤醒
      if(isSleeping)
      {
         WriteLog("休眠状态下达到盈利目标，已平仓");
         WriteLog("重要保持休眠状态，不再开始新一轮交易");
         WriteLog("休眠原因: " + sleepReason);
         if(sleepEndTime > 0)
         {
            int remainingMinutes = (int)(sleepEndTime - TimeCurrent()) / 60;
            WriteLog("预计休眠结束时间: " + TimeToString(sleepEndTime) + " (剩余约" + IntegerToString(remainingMinutes) + "分钟)");
         }
         else
         {
            WriteLog("手动休眠，需要手动唤醒才能继续交易");
         }
         
         // 重置标志，但保持休眠状态
         firstOrderOpened = false;
      }
      else
      {
         // 非休眠状态，正常自动开单
         if(autoOpenEnabled && !tradingPaused)
         {
            WriteLog("自动开单已启用，重新评估...");
            if(EvaluateAndOpen())
            {
               WriteLog("新轮次开始");
            }
         }
         else
         {
            firstOrderOpened = false;
         }
      }
      WriteLog("========================================");
   }
   
   // 核心修改马丁和对冲逻辑
   // 休眠状态下，如果有持仓，继续执行策略（加仓逻辑）
   // 只有在没有持仓时才真正停止
   if(martingaleEnabled && firstOrderOpened && totalOrders > 0)
   {
      // 休眠状态下也执行策略，让当前轮正常完成
      ExecuteStrategy();
   }
}

//+------------------------------------------------------------------+
//| 计算保证金盈利率                                                  |
//+------------------------------------------------------------------+
double CalculateMarginProfitRate()
{
   double totalProfit = CalculateTotalProfit();
   double totalMargin = CalculateTotalMargin();
   
   if(totalMargin <= 0) return 0;
   
   return (totalProfit / totalMargin) * 100;
}

//+------------------------------------------------------------------+
//| 计算总保证金                                                      |
//+------------------------------------------------------------------+
double CalculateTotalMargin()
{
   double totalMargin = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            double margin = CalculateMarginForOrder(volume, price);
            totalMargin += margin;
         }
      }
   }
   
   return totalMargin;
}

//+------------------------------------------------------------------+
//| 计算单笔订单保证金                                                |
//+------------------------------------------------------------------+
double CalculateMarginForOrder(double volume, double price)
{
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double margin = (price * contractSize * volume) / Leverage;
   return margin;
}

//+------------------------------------------------------------------+
//| 计算动态保证金盈利率目标                                          |
//+------------------------------------------------------------------+
double CalculateDynamicMarginProfitRate()
{
   // 使用四因子盈利目标系统计算基础目标
   double baseRate = CalculateUltimateMarginTarget();
   
   // 应用明确的单数分级限制
   if(totalOrders == 0) 
   {
      // 第一单：计算值*1.2，最高100%
      baseRate = baseRate * 1.2;
      if(baseRate > FirstOrderMaxMarginRate)
         baseRate = FirstOrderMaxMarginRate;
      if(baseRate < 5.0)
         baseRate = 5.0;
   }
   else if(totalOrders == 1)
   {
      // 第二单：计算值*1.2，最高60%
      baseRate = baseRate * 1.2;
      if(baseRate > SecondOrderMaxMarginRate)
         baseRate = SecondOrderMaxMarginRate;
      if(baseRate < 5.0)
         baseRate = 5.0;
   }
   else if(totalOrders == 2)
   {
      // 第三单：最高30%
      if(baseRate > ThirdOrderMaxMarginRate)
         baseRate = ThirdOrderMaxMarginRate;
      if(baseRate < 3.0)
         baseRate = 3.0;
   }
   else if(totalOrders == 3)
   {
      // 第四单：最高15%
      if(baseRate > FourthOrderMaxMarginRate)
         baseRate = FourthOrderMaxMarginRate;
      if(baseRate < 2.0)
         baseRate = 2.0;
   }
   else
   {
      // 第五单及以后：从15%开始按0.6递减
      baseRate = FourthOrderMaxMarginRate;
      
      for(int i = 4; i < totalOrders; i++)
      {
         baseRate *= MarginRateDecay;
      }
      
      // 最低保证2%
      if(baseRate < 2.0)
         baseRate = 2.0;
   }
   
   currentMarginProfitRate = baseRate;
   
   string logMsg = StringFormat("盈利目标: 四因子综合=%.3f%% | 单数限制后=%.3f%% | 当前单数=%d", 
                                CalculateUltimateMarginTarget(), baseRate, totalOrders);
   WriteLog(logMsg);
   
   return baseRate;
}

//+------------------------------------------------------------------+
//| 计算第一单保证金盈利率目标                                        |
//+------------------------------------------------------------------+
double CalculateFirstOrderMarginRate()
{
   // 基于趋势权重判断计算目标盈利率
   double trendScore = CalculateTrendWeightScore();
   double baseRate = trendScore * FirstOrderMaxMarginRate; // 基于趋势得分
   
   // 限制在合理范围内
   if(baseRate > FirstOrderMaxMarginRate)
      baseRate = FirstOrderMaxMarginRate;
   if(baseRate < 5.0) // 最小5%
      baseRate = 5.0;
   
   currentMarginProfitRate = baseRate;
   
   string logMsg = StringFormat("趋势权重得分: %.3f | 基础盈利率: %.3f%% | 当前单数: %d", 
                                trendScore, baseRate, totalOrders);
   WriteLog(logMsg);
   
   return baseRate;
}

//+------------------------------------------------------------------+
//| 计算多时间框架趋势                                                |
//+------------------------------------------------------------------+
double CalculateMultiTimeframeTrend(ENUM_TIMEFRAMES timeframe, int periods)
{
   double trend = 0;
   int upCount = 0;
   int downCount = 0;
   
   for(int i = 0; i < periods; i++)
   {
      double close1 = iClose(_Symbol, timeframe, i);
      double close2 = iClose(_Symbol, timeframe, i+1);
      
      if(close1 > close2) upCount++;
      else if(close1 < close2) downCount++;
   }
   
   int totalBars = periods;
   if(totalBars > 0)
   {
      trend = (double)(upCount - downCount) / totalBars;
   }
   
   return trend;
}

//+------------------------------------------------------------------+
//| 计算趋势权重得分                                                  |
//+------------------------------------------------------------------+
double CalculateTrendWeightScore()
{
   // 计算各时间框架的趋势强度
   double trend1m = CalculateMultiTimeframeTrend(PERIOD_M1, 5);      // 1分钟趋势（过去5根K线）
   double trend5m = CalculateMultiTimeframeTrend(PERIOD_M5, 5);      // 5分钟趋势（过去5根K线）
   double trend15m = CalculateMultiTimeframeTrend(PERIOD_M15, 5);     // 15分钟趋势（过去5根K线）
   double trend1h = CalculateMultiTimeframeTrend(PERIOD_H1, 5);      // 1小时趋势（过去5根K线）
   
   // 加权计算趋势得分
   double trendScore = trend1m * DirWeight1m + 
                      trend5m * DirWeight5m + 
                      trend15m * DirWeight15m + 
                      trend1h * DirWeight1h;
   
   // 转换为0-1的得分（取绝对值）
   double normalizedScore = MathAbs(trendScore);
   
   // 确保得分在0-1范围内
   if(normalizedScore > 1.0) normalizedScore = 1.0;
   
   string logMsg = StringFormat("趋势权重: 1m=%.3f, 5m=%.3f, 15m=%.3f, 1h=%.3f, 得分=%.3f",
                                trend1m, trend5m, trend15m, trend1h, normalizedScore);
   WriteLog(logMsg);
   
   return normalizedScore;
}

//+------------------------------------------------------------------+
//| 计算预测波动幅度                                                  |
//+------------------------------------------------------------------+
double CalculatePredictedVolatility()
{
   // 计算各时间段的波动幅度
   double range30s = CalculateVolatilityRange(PERIOD_M1, 0, 1);      // 30秒
   double range30s_1_5m = CalculateVolatilityRange(PERIOD_M1, 1, 3);  // 30秒-1.5分钟
   double range1_5m_5m = CalculateVolatilityRange(PERIOD_M1, 2, 5);   // 1.5-5分钟
   double range5m_15m = CalculateVolatilityRange(PERIOD_M1, 5, 15);   // 5-15分钟
   double range15m_30m = CalculateVolatilityRange(PERIOD_M1, 15, 30); // 15-30分钟
   
   // 加权计算预测波动
   double predictedVol = range30s * Weight30s + 
                        range30s_1_5m * Weight30s_1_5m + 
                        range1_5m_5m * Weight1_5m_5m + 
                        range5m_15m * Weight5m_15m + 
                        range15m_30m * Weight15m_30m;
   
   // 转换为百分比
   double currentPrice = iClose(_Symbol, PERIOD_M1, 0);
   if(currentPrice > 0)
   {
      predictedVol = (predictedVol / currentPrice) * 100;
   }
   
   string logMsg = StringFormat("波动预测: 30s=%.2f, 30s-1.5m=%.2f, 1.5-5m=%.2f, 5-15m=%.2f, 15-30m=%.2f, 预测=%.2f%%",
                                range30s, range30s_1_5m, range1_5m_5m, range5m_15m, range15m_30m, predictedVol);
   WriteLog(logMsg);
   
   return predictedVol;
}

//+------------------------------------------------------------------+
//| 计算指定时间段的波动幅度                                          |
//+------------------------------------------------------------------+
double CalculateVolatilityRange(ENUM_TIMEFRAMES timeframe, int startBar, int endBar)
{
   double maxRange = 0;
   
   for(int i = startBar; i < endBar; i++)
   {
      double high = iHigh(_Symbol, timeframe, i);
      double low = iLow(_Symbol, timeframe, i);
      double range = high - low;
      if(range > maxRange)
         maxRange = range;
   }
   
   return maxRange;
}

//+------------------------------------------------------------------+
//| 计算动态加仓间隔                                                  |
//+------------------------------------------------------------------+
double CalculateDynamicStepPoints()
{
   if(!UseDynamicStep)
      return DefaultStepPoints;
   
   // 计算各时间段的波动幅度
   double range30s = CalculateVolatilityRange(PERIOD_M1, 0, 1);      // 30秒
   double range30s_1_5m = CalculateVolatilityRange(PERIOD_M1, 1, 3);  // 30秒-1.5分钟
   double range1_5m_5m = CalculateVolatilityRange(PERIOD_M1, 2, 5);   // 1.5-5分钟
   double range5m_15m = CalculateVolatilityRange(PERIOD_M1, 5, 15);   // 5-15分钟
   double range15m_30m = CalculateVolatilityRange(PERIOD_M1, 15, 30); // 15-30分钟
   
   // 加权计算预测波动
   double predictedVol = range30s * Weight30s + 
                        range30s_1_5m * Weight30s_1_5m + 
                        range1_5m_5m * Weight1_5m_5m + 
                        range5m_15m * Weight5m_15m + 
                        range15m_30m * Weight15m_30m;
   
   // 转换为点数
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point == 0) return DefaultStepPoints;
   
   double baseStepPoints = (predictedVol / point) * StepMultiplier;
   double stepPoints = baseStepPoints;
   
   // 三级优先级系统
   string appliedMethod = "基础";
   double appliedMultiplier = 1.0;
   
   // 优先级1: 波动权重系数
   double volWeight = CalculateVolatilityWeight();
   if(volWeight != 1.0)
   {
      stepPoints = baseStepPoints * volWeight;
      appliedMethod = "波动权重";
      appliedMultiplier = volWeight;
   }
   // 优先级2: 5m/30m波动率比较（只有优先级1未触发时才使用）
   else if(EnableVolatilityRatio)
   {
      double volRatio = Calculate5m30mVolatilityRatio();
      if(volRatio >= MinVolatilityRatio)
      {
         stepPoints = baseStepPoints * volRatio;
         appliedMethod = "波动率比值";
         appliedMultiplier = volRatio;
      }
   }
   
   // 优先级3: 快速加仓扩大系数（只有前两者都未触发时才使用）
   if(appliedMethod == "基础" && EnableFastMartingale && CheckFastMartingale())
   {
      stepPoints = baseStepPoints * FastMartingaleMultiplier;
      appliedMethod = "快速加仓";
      appliedMultiplier = FastMartingaleMultiplier;
   }
   
   // 限制范围
   if(stepPoints < MinStepPoints) stepPoints = MinStepPoints;
   if(stepPoints > MaxStepPoints) stepPoints = MaxStepPoints;
   
   string logMsg = StringFormat("动态间隔: %.0f点 (基础=%.0f, 方法=%s, 系数=%.2f, 最终=%.0f)",
                                stepPoints, baseStepPoints, appliedMethod, appliedMultiplier, stepPoints);
   WriteLog(logMsg);
   
   return stepPoints;
}

//+------------------------------------------------------------------+
//| 检查极端行情                                                      |
//+------------------------------------------------------------------+
bool CheckExtremeMarket()
{
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   
   if(CopyBuffer(atrHandle, 0, 0, 50, atr_buffer) <= 0)
   {
      WriteLog("错误：无法获取ATR数据");
      return false;
   }
   
   double atr = atr_buffer[0];
   double avgATR = 0;
   for(int i = 0; i < 50; i++)
   {
      avgATR += atr_buffer[i];
   }
   avgATR /= 50;
   
   if(atr > avgATR * ExtremeThreshold)
   {
      string msg = StringFormat("极端ATR检测: 当前=%.5f | 平均=%.5f | 倍数=%.2f", atr, avgATR, atr/avgATR);
      WriteLog(msg);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 计算趋势强度                                                      |
//+------------------------------------------------------------------+
double CalculateTrendStrength()
{
   double strength = 0;
   int upCount = 0;
   int downCount = 0;
   
   for(int i = 0; i < TrendStrengthPeriod; i++)
   {
      double close1 = iClose(_Symbol, PERIOD_M5, i);
      double close2 = iClose(_Symbol, PERIOD_M5, i+1);
      
      if(close1 > close2) upCount++;
      else if(close1 < close2) downCount++;
   }
   
   int maxCount = MathMax(upCount, downCount);
   strength = (double)maxCount / TrendStrengthPeriod * 100;
   
   return strength;
}

//+------------------------------------------------------------------+
//| 确定最优策略                                                      |
//+------------------------------------------------------------------+
ENUM_STRATEGY_MODE DetermineOptimalStrategy()
{
   double trendStrength = CalculateTrendStrength();
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   
   if(CopyBuffer(atrHandle, 0, 0, 1, atr_buffer) <= 0)
      return MODE_HEDGE_COUNTER;
   
   double atr = atr_buffer[0];
   double price = iClose(_Symbol, PERIOD_M5, 0);
   double volatility = (price > 0) ? ((atr / price) * 100) : 0;
   
   string msg = StringFormat("市场分析: 趋势强度=%.2f | 波动率=%.2f%%", trendStrength, volatility);
   WriteLog(msg);
   
   // 强趋势：顺势对冲
   if(trendStrength > StrongTrendThreshold)
   {
      WriteLog("判断: 强趋势 → 双边顺势对冲");
      return MODE_HEDGE_TREND;
   }
   // 弱趋势且低波动：单边趋势
   else if(trendStrength < WeakTrendThreshold && volatility < 0.5)
   {
      WriteLog("判断: 弱趋势+低波动 → 单边趋势马丁");
      return MODE_SINGLE_TREND;
   }
   // 震荡：逆势对冲
   else
   {
      WriteLog("判断: 震荡市场 → 双边逆势对冲");
      return MODE_HEDGE_COUNTER;
   }
}

//+------------------------------------------------------------------+
//| 实时评估未来趋势                                                  |
//+------------------------------------------------------------------+
void EvaluateFutureTrend()
{
   // 使用多维度趋势判断系统
   CalculateMultiDimensionTrendScore();
   
   // 检查是否可以开单
   if(EnableConfidenceCheck && predictionConfidenceValue < ConfidenceThreshold)
   {
      canOpenOrder = false;
      noTradeReason = StringFormat("信心不足 (%.0f%% < %.0f%%)", predictionConfidenceValue*100, ConfidenceThreshold*100);
   }
   else
   {
      canOpenOrder = true;
      noTradeReason = "";
   }
}

//+------------------------------------------------------------------+
//| 计算方向趋势                                                      |
//+------------------------------------------------------------------+
double CalculateDirectionTrend(ENUM_TIMEFRAMES timeframe, int startBar, int endBar)
{
   double trend = 0;
   int upCount = 0;
   int downCount = 0;
   
   for(int i = startBar; i < endBar; i++)
   {
      double close1 = iClose(_Symbol, timeframe, i);
      double close2 = iClose(_Symbol, timeframe, i+1);
      
      if(close1 > close2) upCount++;
      else if(close1 < close2) downCount++;
   }
   
   int totalBars = endBar - startBar;
   if(totalBars > 0)
   {
      trend = (double)(upCount - downCount) / totalBars;
   }
   
   return trend;
}

//+------------------------------------------------------------------+
//| 智能第一单方向判断                                                |
//+------------------------------------------------------------------+
int AnalyzeFirstOrderDirection()
{
   // 基于多时间框架趋势分析
   double trend1m = CalculateMultiTimeframeTrend(PERIOD_M1, 5);      // 1分钟趋势（过去5根K线）
   double trend5m = CalculateMultiTimeframeTrend(PERIOD_M5, 5);      // 5分钟趋势（过去5根K线）
   double trend15m = CalculateMultiTimeframeTrend(PERIOD_M15, 5);     // 15分钟趋势（过去5根K线）
   double trend1h = CalculateMultiTimeframeTrend(PERIOD_H1, 5);       // 1小时趋势（过去5根K线）
   
   // 加权计算方向得分
   double directionScore = trend1m * DirWeight1m + 
                          trend5m * DirWeight5m + 
                          trend15m * DirWeight15m + 
                          trend1h * DirWeight1h;
   
   string msg = StringFormat("第一单方向: 1m=%.3f | 5m=%.3f | 15m=%.3f | 1h=%.3f | 得分=%.3f",
                             trend1m, trend5m, trend15m, trend1h, directionScore);
   WriteLog(msg);
   
   if(directionScore > 0.1) return 1;
   if(directionScore < -0.1) return -1;
   return 1; // 默认看涨
}

//+------------------------------------------------------------------+
//| 直接开第一单                                                      |
//+------------------------------------------------------------------+
bool OpenFirstOrder()
{
   // 确定策略模式
   if(AutoSwitchStrategy)
      currentMode = DetermineOptimalStrategy();
   
   UpdateModeButton();
   
   // 智能判断第一单方向
   int direction = AnalyzeFirstOrderDirection();
   
   // 开单（单向）
   ENUM_ORDER_TYPE orderType = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   firstDirection = (direction > 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   
   string msg = "开单模式: " + GetModeName(currentMode) + " | 方向: " + ((direction > 0) ? "看涨" : "看跌");
   WriteLog(msg);
   
   if(OpenOrder(orderType, InitialLot, "首单"))
   {
      if(orderType == ORDER_TYPE_BUY)
         lastBuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else
         lastSellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      firstOrderOpened = true;
      CountOrders();
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 评估并开仓                                                        |
//+------------------------------------------------------------------+
bool EvaluateAndOpen()
{
   // 评估未来趋势
   EvaluateFutureTrend();
   
   // 检查是否可以开单
   if(!canOpenOrder)
   {
      WriteLog("开单评估：不适合 - " + noTradeReason);
      return false;
   }
   
   WriteLog("开单评估：适合 - " + predictionStatus);
   
   // 确定策略模式
   if(AutoSwitchStrategy)
      currentMode = DetermineOptimalStrategy();
   
   UpdateModeButton();
   
   // 智能判断第一单方向
   int direction = AnalyzeFirstOrderDirection();
   
   // 开单（单向）
   ENUM_ORDER_TYPE orderType = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   firstDirection = (direction > 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   
   string msg = "开单模式: " + GetModeName(currentMode) + " | 方向: " + ((direction > 0) ? "看涨" : "看跌");
   WriteLog(msg);
   
   if(OpenOrder(orderType, InitialLot, "首单"))
   {
      if(orderType == ORDER_TYPE_BUY)
         lastBuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else
         lastSellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      firstOrderOpened = true;
      CountOrders();
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 执行策略逻辑                                                      |
//+------------------------------------------------------------------+
void ExecuteStrategy()
{
   // 计算当前动态间隔
   if(UseDynamicStep)
      currentStepPoints = CalculateDynamicStepPoints();
   else
      currentStepPoints = DefaultStepPoints;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // 根据策略执行
   switch(currentMode)
   {
      case MODE_SINGLE_TREND:
         ExecuteSingleTrendStrategy(ask, bid, point);
         break;
         
      case MODE_HEDGE_COUNTER:
      case MODE_HEDGE_TREND:
         ExecuteHedgeStrategy(ask, bid, point);
         break;
   }
}

//+------------------------------------------------------------------+
//| 执行单边趋势策略                                                  |
//+------------------------------------------------------------------+
void ExecuteSingleTrendStrategy(double ask, double bid, double point)
{
   if(firstDirection == POSITION_TYPE_BUY && totalBuyOrders < MaxOrders && lastBuyPrice > 0)
   {
      double distance = (lastBuyPrice - ask) / point;
      if(distance >= currentStepPoints)
      {
         double maxVol = GetMaxVolume(POSITION_TYPE_BUY);
         double newVol = NormalizeDouble(maxVol * MartingaleMultiplier, 2);
         
         string comment = StringFormat("马丁多%d", totalBuyOrders+1);
         if(OpenOrder(ORDER_TYPE_BUY, newVol, comment))
         {
            lastBuyPrice = ask;
            CountOrders();
         }
      }
   }
   else if(firstDirection == POSITION_TYPE_SELL && totalSellOrders < MaxOrders && lastSellPrice > 0)
   {
      double distance = (bid - lastSellPrice) / point;
      if(distance >= currentStepPoints)
      {
         double maxVol = GetMaxVolume(POSITION_TYPE_SELL);
         double newVol = NormalizeDouble(maxVol * MartingaleMultiplier, 2);
         
         string comment = StringFormat("马丁空%d", totalSellOrders+1);
         if(OpenOrder(ORDER_TYPE_SELL, newVol, comment))
         {
            lastSellPrice = bid;
            CountOrders();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 执行对冲策略                                                      |
//+------------------------------------------------------------------+
void ExecuteHedgeStrategy(double ask, double bid, double point)
{
   // 多单马丁
   if(totalBuyOrders < MaxOrders && lastBuyPrice > 0)
   {
      double distance = (lastBuyPrice - ask) / point;
      if(distance >= currentStepPoints)
      {
         double maxVol = GetMaxVolume(POSITION_TYPE_BUY);
         double newVol = NormalizeDouble(maxVol * MartingaleMultiplier, 2);
         
         string comment = StringFormat("多单%d", totalBuyOrders+1);
         if(OpenOrder(ORDER_TYPE_BUY, newVol, comment))
         {
            lastBuyPrice = ask;
            CountOrders();
         }
      }
   }
   
   // 空单马丁
   if(totalSellOrders < MaxOrders && lastSellPrice > 0)
   {
      double distance = (bid - lastSellPrice) / point;
      if(distance >= currentStepPoints)
      {
         double maxVol = GetMaxVolume(POSITION_TYPE_SELL);
         double newVol = NormalizeDouble(maxVol * MartingaleMultiplier, 2);
         
         string comment = StringFormat("空单%d", totalSellOrders+1);
         if(OpenOrder(ORDER_TYPE_SELL, newVol, comment))
         {
            lastSellPrice = bid;
            CountOrders();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 发送订单                                                          |
//+------------------------------------------------------------------+
bool OpenOrder(ENUM_ORDER_TYPE orderType, double volume, string comment)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = orderType;
   request.price = price;
   request.deviation = 20;
   request.magic = MagicNumber;
   request.comment = comment;
   request.type_filling = ORDER_FILLING_IOC;
   
   if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)
   {
      string msg = "订单失败: " + IntegerToString(result.retcode) + " - " + comment;
      WriteLog(msg);
      return false;
   }
   
   // 记录订单开仓时间（用于快速加仓检测）
   datetime currentTime = TimeCurrent();
   if(totalOrders == 0)
   {
      firstOrderTime = currentTime;
   }
   lastOrderTime = currentTime;
   
   // 记录到数组（如果不超过限制）
   if(totalOrders < 9)
   {
      orderTimes[totalOrders] = currentTime;
   }
   
   string msg = StringFormat("订单成功: %s - 价格: %.5f, 手数: %.2f", comment, price, volume);
   WriteLog(msg);
   return true;
}

//+------------------------------------------------------------------+
//| 平掉所有持仓                                                      |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   WriteLog("开始平仓所有订单");
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            ClosePosition(PositionGetInteger(POSITION_TICKET));
            Sleep(500);
         }
      }
   }
   
   lastBuyPrice = 0;
   lastSellPrice = 0;
   firstDirection = -1;
   
   // 重置时间记录
   firstOrderTime = 0;
   lastOrderTime = 0;
   ArrayInitialize(orderTimes, 0);
   
   WriteLog("所有订单已平仓");
}

//+------------------------------------------------------------------+
//| 平仓指定订单                                                      |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   if(!PositionSelectByTicket(ticket)) return false;
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.deviation = 20;
   request.magic = MagicNumber;
   request.comment = "平仓";
   request.type_filling = ORDER_FILLING_IOC;
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else
   {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
   
   bool success = (OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE);
   
   if(success)
   {
      WriteLog("平仓成功: Ticket#" + IntegerToString(ticket));
   }
   else
   {
      WriteLog("平仓失败: Ticket#" + IntegerToString(ticket) + " - " + IntegerToString(result.retcode));
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| 获取最大手数                                                      |
//+------------------------------------------------------------------+
double GetMaxVolume(ENUM_POSITION_TYPE posType)
{
   double maxVol = InitialLot;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetInteger(POSITION_TYPE) == posType)
         {
            double vol = PositionGetDouble(POSITION_VOLUME);
            if(vol > maxVol) maxVol = vol;
         }
      }
   }
   return maxVol;
}

//+------------------------------------------------------------------+
//| 更新最后价格                                                      |
//+------------------------------------------------------------------+
void UpdateLastPrices()
{
   lastBuyPrice = 0;
   lastSellPrice = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               if(lastBuyPrice == 0 || openPrice < lastBuyPrice)
                  lastBuyPrice = openPrice;
            }
            else
            {
               if(lastSellPrice == 0 || openPrice > lastSellPrice)
                  lastSellPrice = openPrice;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 判断第一单方向                                                    |
//+------------------------------------------------------------------+
void DetermineFirstDirection()
{
   if(totalBuyOrders > 0 && totalSellOrders == 0)
      firstDirection = POSITION_TYPE_BUY;
   else if(totalSellOrders > 0 && totalBuyOrders == 0)
      firstDirection = POSITION_TYPE_SELL;
   else if(totalBuyOrders > 0 && totalSellOrders > 0)
      firstDirection = (totalBuyOrders >= totalSellOrders) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| 获取模式名称                                                      |
//+------------------------------------------------------------------+
string GetModeName(ENUM_STRATEGY_MODE mode)
{
   switch(mode)
   {
      case MODE_SINGLE_TREND: return "单边趋势";
      case MODE_HEDGE_COUNTER: return "逆势对冲";
      case MODE_HEDGE_TREND: return "顺势对冲";
      default: return "未知";
   }
}

//+------------------------------------------------------------------+
//| 更新显示                                                          |
//+------------------------------------------------------------------+
void UpdateDisplay(double profit, double marginProfitRate, double targetMarginRate)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string status = tradingPaused ? "暂停" : (isSleeping ? "休眠" : "运行");
   
   // 获取当前时间和市场盘信息
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string currentTime = StringFormat("%02d:%02d", dt.hour, dt.min);
   string marketSession = GetCurrentMarketSession();
   string nextSession = GetNextTradingSession();
   
   string displayText = StringFormat(
      "=== 高级马丁 v6.141fix3 ===\n" +
      "价格: %.5f | 状态: %s\n" +
      "模式: %s | 建议: %s\n" +
      "多: %d | 空: %d | 共: %d\n" +
      "盈利: $%.2f (%.3f%%)\n" +
      "目标: %.3f%% | 间隔: %.0f点\n" +
      "--- 多维度评分 ---\n" +
      "趋势: %.2f | ML: %.2f | 流: %.2f | SR: %.2f\n" +
      "--- 统计 ---\n" +
      "轮数: %d | 盈利轮: %d\n" +
      "胜率: %.1f%% | 累计: $%.2f",
      bid, status,
      GetModeName(currentMode), predictionAdvice,
      totalBuyOrders, totalSellOrders, totalOrders,
      profit, marginProfitRate, targetMarginRate, currentStepPoints,
      trendMethodScore, mlFeatureScore, orderFlowScore, srLevelScore,
      totalRounds, winRounds,
      (totalRounds > 0) ? (double)winRounds/totalRounds*100 : 0,
      totalProfitSum
   );
   
   // 核心修改显示休眠状态和预警信息
   if(isSleeping)
   {
      // 休眠状态显示
      displayText += "\n--- 休眠状态 ---\n";
      displayText += StringFormat("原因: %s\n", sleepReason);
      
      if(totalOrders > 0)
      {
         displayText += "【当前轮继续交易中】\n";
         displayText += "正常计算加仓间隔和盈利率\n";
         displayText += "达到目标后平仓不再开新单\n";
      }
      else
      {
         displayText += "无持仓，等待休眠结束\n";
      }
      
      if(sleepEndTime > 0)
      {
         int remainingSeconds = (int)(sleepEndTime - TimeCurrent());
         if(remainingSeconds > 0)
         {
            int remainingMinutes = remainingSeconds / 60;
            int remainingSecs = remainingSeconds % 60;
            displayText += StringFormat("剩余: %d分%d秒\n", remainingMinutes, remainingSecs);
            displayText += StringFormat("结束: %s\n", TimeToString(sleepEndTime, TIME_DATE|TIME_MINUTES));
         }
      }
      else
      {
         displayText += "手动休眠，需手动唤醒\n";
      }
      
      displayText += StringFormat("当前: %s (%s)\n", currentTime, marketSession);
      displayText += StringFormat("盘次: %s", nextSession);
   }
   else
   {
      // 正常交易状态显示
      displayText += "\n--- ✓ 交易状态 ---\n";
      displayText += "正常交易中\n";
      displayText += StringFormat("当前: %s (%s)\n", currentTime, marketSession);
      displayText += StringFormat("盘次: %s\n", nextSession);
      
      // 新增显示休眠预警
      if(nextSleepTime > 0)
      {
         int minutesUntilSleep = (int)(nextSleepTime - TimeCurrent()) / 60;
         if(minutesUntilSleep > 0 && minutesUntilSleep <= 60)
         {
            displayText += "\n⚠ 休眠预警 ⚠\n";
            displayText += StringFormat("%d分钟后将因\n", minutesUntilSleep);
            displayText += StringFormat("%s\n", nextSleepReason);
            displayText += "进入休眠状态";
         }
      }
   }
   
   // 创建显示内容（靠左对齐）
   string combinedDisplay = displayText;
   
   // 在底部显示24小时交易事件
   if(next24hEvents != "")
   {
      combinedDisplay += "\n===================\n";
      combinedDisplay += "=== 未来24小时交易事件 ===\n";
      combinedDisplay += "===================\n";
      combinedDisplay += next24hEvents;
   }
   
   Comment(combinedDisplay);
}

//+------------------------------------------------------------------+
//| 获取当前市场盘信息                                                |
//+------------------------------------------------------------------+
string GetCurrentMarketSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   
   // 亚洲盘：06:00-15:00
   if(hour >= 6 && hour < 15)
      return "亚洲盘";
   // 欧洲盘：15:00-24:00
   else if(hour >= 15 && hour < 24)
      return "欧洲盘";
   // 美洲盘：00:00-06:00
   else
      return "美洲盘";
}

//+------------------------------------------------------------------+
//| 创建信息标签                                                      |
//+------------------------------------------------------------------+
void CreateInfoLabels()
{
   int startX = 300;
   int startY = 30;
   int lineHeight = 22;
   
   // 预测状态标签
   CreateLabel("LblPrediction", "预测: 评估中...", startX, startY, clrYellow, 9);
   
   // 建议标签
   CreateLabel("LblAdvice", "建议: 观望", startX, startY + lineHeight, clrWhite, 9);
   
   // 动态间隔标签
   CreateLabel("LblStep", "间隔: 100点", startX, startY + lineHeight*2, clrLime, 9);
   
   // 保证金盈利率标签
   CreateLabel("LblMarginRate", "保证金盈利率: 0.00%", startX, startY + lineHeight*3, clrAqua, 9);
   
   // 目标保证金盈利率标签
   CreateLabel("LblTargetMargin", "目标: 0.00%", startX, startY + lineHeight*4, clrOrange, 9);
   
   // 时间控制标签
   CreateLabel("LblTimeControl", "时间控制: 启用", startX, startY + lineHeight*5, clrLightBlue, 9);
   
   // 休眠状态标签（合并休眠状态和不开单原因）
   CreateLabel("LblStatus", "", startX, startY + lineHeight*6, clrYellow, 10);
}

//+------------------------------------------------------------------+
//| 创建标签                                                          |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| 更新信息标签                                                      |
//+------------------------------------------------------------------+
void UpdateInfoLabels()
{
   // 更新预测状态
   string predText = "预测: " + predictionStatus;
   if(EnableConfidenceCheck)
   {
      predText += " [信心检查:开]";
   }
   else
   {
      predText += " [信心检查:关]";
   }
   ObjectSetString(0, "LblPrediction", OBJPROP_TEXT, predText);
   
   color predColor = clrYellow;
   if(predictionDirection > 0) predColor = clrLime;
   else if(predictionDirection < 0) predColor = clrOrange;
   ObjectSetInteger(0, "LblPrediction", OBJPROP_COLOR, predColor);
   
   // 更新建议
   string adviceText = "建议: " + predictionAdvice;
   color adviceColor = clrWhite;
   if(predictionAdvice == "强烈建议") adviceColor = clrLime;
   else if(predictionAdvice == "建议") adviceColor = clrYellow;
   else if(predictionAdvice == "谨慎") adviceColor = clrOrange;
   else adviceColor = clrGray;
   ObjectSetString(0, "LblAdvice", OBJPROP_TEXT, adviceText);
   ObjectSetInteger(0, "LblAdvice", OBJPROP_COLOR, adviceColor);
   
   // 更新动态间隔
   string stepText = StringFormat("间隔: %.0f点", currentStepPoints);
   ObjectSetString(0, "LblStep", OBJPROP_TEXT, stepText);
   
   // 更新保证金盈利率
   double currentMarginRate = CalculateMarginProfitRate();
   string marginText = StringFormat("保证金盈利率: %.3f%%", currentMarginRate);
   ObjectSetString(0, "LblMarginRate", OBJPROP_TEXT, marginText);
   
   // 更新目标保证金盈利率
   double targetMarginRate = CalculateDynamicMarginProfitRate();
   string targetText = StringFormat("目标: %.3f%%", targetMarginRate);
   ObjectSetString(0, "LblTargetMargin", OBJPROP_TEXT, targetText);
   
   // 更新时间控制状态
   string timeControlText = "时间控制: ";
   if(EnableTimeControl || EnableMarketTimeControl)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      string status = "";
      if(EnableTimeControl) status += "基础";
      if(EnableMarketTimeControl)
      {
         if(status != "") status += "+";
         status += "市场";
      }
      
      timeControlText += StringFormat("%s (周%d %02d:%02d)", status, dt.day_of_week, dt.hour, dt.min);
   }
   else
   {
      timeControlText += "禁用";
   }
   ObjectSetString(0, "LblTimeControl", OBJPROP_TEXT, timeControlText);
   ObjectSetInteger(0, "LblTimeControl", OBJPROP_COLOR, 
                    (EnableTimeControl || EnableMarketTimeControl) ? clrLightBlue : clrGray);
   
   // 更新状态（合并休眠状态和不开单原因）
   if(isSleeping)
   {
      int remainingSeconds = (int)(sleepEndTime - TimeCurrent());
      if(remainingSeconds > 0)
      {
         int remainingMinutes = remainingSeconds / 60;
         int remainingSecs = remainingSeconds % 60;
         
         string sleepText = "💤 休眠中: " + sleepReason + StringFormat(" (剩余%d分%d秒)", remainingMinutes, remainingSecs);
         ObjectSetString(0, "LblStatus", OBJPROP_TEXT, sleepText);
         ObjectSetInteger(0, "LblStatus", OBJPROP_COLOR, clrYellow);
      }
      else
      {
         ObjectSetString(0, "LblStatus", OBJPROP_TEXT, "💤 休眠中: " + sleepReason);
         ObjectSetInteger(0, "LblStatus", OBJPROP_COLOR, clrYellow);
      }
   }
   else if(noTradeReason != "")
   {
      string noTradeText = "⚠ 暂停开单: " + noTradeReason;
      ObjectSetString(0, "LblStatus", OBJPROP_TEXT, noTradeText);
      ObjectSetInteger(0, "LblStatus", OBJPROP_COLOR, clrRed);
   }
   else
   {
      ObjectSetString(0, "LblStatus", OBJPROP_TEXT, "");
   }
}

//+------------------------------------------------------------------+
//| 删除信息标签                                                      |
//+------------------------------------------------------------------+
void DeleteInfoLabels()
{
   ObjectDelete(0, "LblPrediction");
   ObjectDelete(0, "LblAdvice");
   ObjectDelete(0, "LblStep");
   ObjectDelete(0, "LblMarginRate");
   ObjectDelete(0, "LblTargetMargin");
   ObjectDelete(0, "LblTimeControl");
   ObjectDelete(0, "LblStatus");
}

//+------------------------------------------------------------------+
//| 创建控制按钮                                                      |
//+------------------------------------------------------------------+
void CreateControlButtons()
{
   ObjectDelete(0, btnClose);
   ObjectDelete(0, btnOpen);
   ObjectDelete(0, btnMartin);
   ObjectDelete(0, btnAuto);
   ObjectDelete(0, btnMode);
   ObjectDelete(0, btnWakeUp);
   
   CreateButton(btnClose, "平仓", buttonStartX, buttonStartY, clrWhite, clrCrimson);
   CreateButton(btnOpen, "开单", buttonStartX, buttonStartY + (buttonHeight+buttonSpacing), clrWhite, clrForestGreen);
   CreateButton(btnMartin, "马丁", buttonStartX, buttonStartY + (buttonHeight+buttonSpacing)*2, clrBlack, clrGold);
   CreateButton(btnAuto, "自动", buttonStartX, buttonStartY + (buttonHeight+buttonSpacing)*3, clrWhite, clrDodgerBlue);
   CreateButton(btnMode, GetModeName(currentMode), buttonStartX, buttonStartY + (buttonHeight+buttonSpacing)*4, clrBlack, clrYellow);
   CreateButton(btnWakeUp, isSleeping ? "唤醒" : "休眠", buttonStartX, buttonStartY + (buttonHeight+buttonSpacing)*5, clrWhite, clrOrange);
}

//+------------------------------------------------------------------+
//| 创建按钮                                                          |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, color textColor, color bgColor)
{
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return;
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, buttonWidth);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, buttonHeight);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| 更新模式按钮                                                      |
//+------------------------------------------------------------------+
void UpdateModeButton()
{
   ObjectSetString(0, btnMode, OBJPROP_TEXT, GetModeName(currentMode));
   
   color bgColor;
   switch(currentMode)
   {
      case MODE_SINGLE_TREND: bgColor = clrLime; break;
      case MODE_HEDGE_COUNTER: bgColor = clrYellow; break;
      case MODE_HEDGE_TREND: bgColor = clrOrange; break;
      default: bgColor = clrGray;
   }
   ObjectSetInteger(0, btnMode, OBJPROP_BGCOLOR, bgColor);
}

//+------------------------------------------------------------------+
//| 图表事件                                                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == btnClose)
      {
         WriteLog("=== 手动平仓 ===");
         if(totalOrders > 0)
         {
            WriteLog("平仓: " + IntegerToString(totalOrders) + "个订单");
            CloseAllOrders();
            firstOrderOpened = false;
         }
         ObjectSetInteger(0, btnClose, OBJPROP_STATE, false);
      }
      else if(sparam == btnOpen)
      {
         WriteLog("=== 手动开单 ===");
         if(!firstOrderOpened && !tradingPaused)
         {
            EvaluateAndOpen();
         }
         ObjectSetInteger(0, btnOpen, OBJPROP_STATE, false);
      }
      else if(sparam == btnMartin)
      {
         martingaleEnabled = !martingaleEnabled;
         WriteLog("马丁: " + (martingaleEnabled ? "启用" : "停止"));
         ObjectSetString(0, btnMartin, OBJPROP_TEXT, martingaleEnabled ? "马丁" : "马丁X");
         ObjectSetInteger(0, btnMartin, OBJPROP_BGCOLOR, martingaleEnabled ? clrGold : clrGray);
         ObjectSetInteger(0, btnMartin, OBJPROP_STATE, false);
      }
      else if(sparam == btnAuto)
      {
         autoOpenEnabled = !autoOpenEnabled;
         WriteLog("自动: " + (autoOpenEnabled ? "开启" : "关闭"));
         ObjectSetString(0, btnAuto, OBJPROP_TEXT, autoOpenEnabled ? "自动" : "自动X");
         ObjectSetInteger(0, btnAuto, OBJPROP_BGCOLOR, autoOpenEnabled ? clrDodgerBlue : clrGray);
         ObjectSetInteger(0, btnAuto, OBJPROP_STATE, false);
      }
      else if(sparam == btnMode)
      {
         // 手动切换模式
         switch(currentMode)
         {
            case MODE_SINGLE_TREND: currentMode = MODE_HEDGE_COUNTER; break;
            case MODE_HEDGE_COUNTER: currentMode = MODE_HEDGE_TREND; break;
            case MODE_HEDGE_TREND: currentMode = MODE_SINGLE_TREND; break;
         }
         WriteLog("切换模式: " + GetModeName(currentMode));
         UpdateModeButton();
         ObjectSetInteger(0, btnMode, OBJPROP_STATE, false);
      }
      else if(sparam == btnWakeUp)
      {
         if(isSleeping)
         {
            // 手动唤醒，解除休眠
            WriteLog("=== 手动唤醒 ===");
            WriteLog("解除休眠: " + sleepReason);
            
            isSleeping = false;
            sleepReason = "";
            sleepStartTime = 0;
            sleepEndTime = 0;
            tradingPaused = false;
            extremeDetected = false;
            noTradeReason = "";
            
            UpdateModeButton();
            
            WriteLog("已恢复交易，可以正常开单");
         }
         else
         {
            // 手动休眠，当前轮交易结束后停止
            WriteLog("=== 手动休眠 ===");
            WriteLog("将在当前轮交易结束后进入休眠");
            
            isSleeping = true;
            sleepReason = "手动休眠";
            sleepStartTime = TimeCurrent();
            sleepEndTime = 0; // 手动休眠，无自动恢复时间
            
            // 如果有持仓，等待当前轮结束
            if(totalOrders > 0)
            {
               WriteLog("等待当前轮交易结束...");
            }
            else
            {
               WriteLog("立即进入休眠状态");
            }
         }
         
         // 更新按钮文本
         ObjectSetString(0, btnWakeUp, OBJPROP_TEXT, isSleeping ? "唤醒" : "休眠");
         ObjectSetInteger(0, btnWakeUp, OBJPROP_STATE, false);
      }
      
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| 统计订单                                                          |
//+------------------------------------------------------------------+
void CountOrders()
{
   totalBuyOrders = 0;
   totalSellOrders = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               totalBuyOrders++;
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               totalSellOrders++;
         }
      }
   }
   
   totalOrders = totalBuyOrders + totalSellOrders;
   
   if(totalOrders == 0)
   {
      firstOrderOpened = false;
      firstDirection = -1;
   }
}

//+------------------------------------------------------------------+
//| 计算总盈利                                                        |
//+------------------------------------------------------------------+
double CalculateTotalProfit()
{
   double profit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   return profit;
}

//+------------------------------------------------------------------+
//| 初始化日志文件                                                    |
//+------------------------------------------------------------------+
void InitializeLogFile()
{
   string fileName = LogFileName;
   
   logFileHandle = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI);
   
   if(logFileHandle != INVALID_HANDLE)
   {
      FileSeek(logFileHandle, 0, SEEK_END);
      Print("日志文件已创建: ", fileName);
      Print("日志路径: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\", fileName);
   }
   else
   {
      Print("错误：无法创建日志文件");
   }
}

//+------------------------------------------------------------------+
//| 写入日志                                                          |
//+------------------------------------------------------------------+
void WriteLog(string message)
{
   Print(message);
   
   if(EnableFileLog && logFileHandle != INVALID_HANDLE)
   {
      string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      FileWriteString(logFileHandle, timestamp + " | " + message + "\n");
      FileFlush(logFileHandle);
   }
}

//+------------------------------------------------------------------+
//| 时间风险检查                                                      |
//+------------------------------------------------------------------+
bool CheckTimeRisk()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentMinutes = dt.hour * 60 + dt.min;
   
   // 基础时间控制
   if(EnableTimeControl)
   {
      // 检查是否周末
      if(NoWeekendPositions)
      {
         // 周五收盘前平仓
         if(dt.day_of_week == 5) // Friday
         {
            if(dt.hour >= FridayCloseHour && dt.min >= FridayCloseMin)
            {
               noTradeReason = "周五收盘时间,禁止持仓";
               return false;
            }
         }
         
         // 周六周日禁止交易
         if(dt.day_of_week == 6 || dt.day_of_week == 0)
         {
            noTradeReason = "周末时间,禁止交易";
            return false;
         }
      }
      
      // 检查极端波动
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      
      if(CopyBuffer(atrHandle, 0, 0, 50, atr_buffer) > 0)
      {
         double atr = atr_buffer[0];
         double avgATR = 0;
         for(int i = 0; i < 50; i++)
         {
            avgATR += atr_buffer[i];
         }
         avgATR /= 50;
         
         if(atr > avgATR * ExtremeVolThreshold)
         {
            noTradeReason = StringFormat("极端波动: ATR=%.5f (平均=%.5f, 倍数=%.2f)", atr, avgATR, atr/avgATR);
            return false;
         }
      }
   }
   
   // 黄金市场时间节点控制
   if(EnableMarketTimeControl)
   {
      // 1. 检查每日收盘前30分钟
      int dailyCloseMinutes = DailyCloseHour * 60 + DailyCloseMin;
      int beforeCloseStart = dailyCloseMinutes - BeforeCloseMinutes;
      
      if(IsTimeInRange(currentMinutes, beforeCloseStart, dailyCloseMinutes))
      {
         noTradeReason = StringFormat("每日收盘前%d分钟,禁止开单", BeforeCloseMinutes);
         return false;
      }
      
      // 2. 检查每日开盘后30分钟
      int dailyOpenMinutes = DailyOpenHour * 60 + DailyOpenMin;
      int afterOpenEnd = dailyOpenMinutes + AfterOpenMinutes;
      
      if(IsTimeInRange(currentMinutes, dailyOpenMinutes, afterOpenEnd))
      {
         noTradeReason = StringFormat("每日开盘后%d分钟,禁止开单", AfterOpenMinutes);
         return false;
      }
      
      // 3. 检查市场盘切换时间窗口
      if(CheckMarketSessionSwitch(currentMinutes))
      {
         return false; // noTradeReason已在函数内设置
      }
      
      // 4. 检查重要数据公布时间窗口
      if(CheckImportantDataRelease(dt, currentMinutes))
      {
         return false; // noTradeReason已在函数内设置
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| 检查时间是否在范围内                                              |
//+------------------------------------------------------------------+
bool IsTimeInRange(int currentMin, int startMin, int endMin)
{
   // 处理跨天情况
   if(startMin < 0) startMin += 24 * 60;
   if(endMin > 24 * 60) endMin -= 24 * 60;
   
   if(startMin < endMin)
   {
      return (currentMin >= startMin && currentMin <= endMin);
   }
   else // 跨天
   {
      return (currentMin >= startMin || currentMin <= endMin);
   }
}

//+------------------------------------------------------------------+
//| 检查是否在关键时间窗口内                                          |
//+------------------------------------------------------------------+
bool IsInKeyTimeWindow(int currentMin, int keyTimeMin)
{
   int beforeStart = keyTimeMin - BeforeKeyTimeMinutes;
   int afterEnd = keyTimeMin + AfterKeyTimeMinutes;
   
   return IsTimeInRange(currentMin, beforeStart, afterEnd);
}

//+------------------------------------------------------------------+
//| 检查市场盘切换时间                                                |
//+------------------------------------------------------------------+
bool CheckMarketSessionSwitch(int currentMinutes)
{
   // 亚洲盘开盘
   int asiaOpenMin = AsiaOpenHour * 60 + AsiaOpenMin;
   if(IsInKeyTimeWindow(currentMinutes, asiaOpenMin))
   {
      noTradeReason = StringFormat("亚洲盘开盘时间窗口(前%dm后%dm),禁止开单", 
                                   BeforeKeyTimeMinutes, AfterKeyTimeMinutes);
      return true;
   }
   
   // 欧洲盘开盘
   int europeOpenMin = EuropeOpenHour * 60 + EuropeOpenMin;
   if(IsInKeyTimeWindow(currentMinutes, europeOpenMin))
   {
      noTradeReason = StringFormat("欧洲盘开盘时间窗口(前%dm后%dm),禁止开单", 
                                   BeforeKeyTimeMinutes, AfterKeyTimeMinutes);
      return true;
   }
   
   // 美国盘开盘
   int usOpenMin = USOpenHour * 60 + USOpenMin;
   if(IsInKeyTimeWindow(currentMinutes, usOpenMin))
   {
      noTradeReason = StringFormat("美国盘开盘时间窗口(前%dm后%dm),禁止开单", 
                                   BeforeKeyTimeMinutes, AfterKeyTimeMinutes);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 检查重要数据公布时间                                              |
//+------------------------------------------------------------------+
bool CheckImportantDataRelease(MqlDateTime &dt, int currentMinutes)
{
   // 非农数据（每月第一个周五）
   if(AvoidNonFarmPayroll && dt.day_of_week == 5)
   {
      // 检查是否是每月第一周
      if(dt.day <= 7)
      {
         int nonFarmMin = NonFarmHour * 60 + NonFarmMin;
         if(IsInKeyTimeWindow(currentMinutes, nonFarmMin))
         {
            noTradeReason = StringFormat("非农数据公布时间窗口(前%dm后%dm),禁止开单", 
                                       BeforeKeyTimeMinutes, AfterKeyTimeMinutes);
            return true;
         }
      }
   }
   
   // CPI数据（通常每月中旬，这里简化为每周三检查）
   if(AvoidCPIData && dt.day_of_week == 3)
   {
      int cpiMin = CPIHour * 60 + CPIMin;
      if(IsInKeyTimeWindow(currentMinutes, cpiMin))
      {
         noTradeReason = StringFormat("CPI数据公布时间窗口(前%dm后%dm),禁止开单", 
                                    BeforeKeyTimeMinutes, AfterKeyTimeMinutes);
         return true;
      }
   }
   
   // FOMC会议（通常每月某天凌晨2点，这里每天都检查）
   if(AvoidFOMC)
   {
      int fomcMin = FOMCHour * 60 + FOMCMin;
      if(IsInKeyTimeWindow(currentMinutes, fomcMin))
      {
         noTradeReason = StringFormat("FOMC会议时间窗口(前%dm后%dm),禁止开单", 
                                    BeforeKeyTimeMinutes, AfterKeyTimeMinutes);
         return true;
      }
   }
   
   // 初请失业金（每周四）
   if(AvoidInitialClaims && dt.day_of_week == 4)
   {
      int claimsMin = InitialClaimsHour * 60 + InitialClaimsMin;
      if(IsInKeyTimeWindow(currentMinutes, claimsMin))
      {
         noTradeReason = StringFormat("初请失业金数据公布时间窗口(前%dm后%dm),禁止开单", 
                                    BeforeKeyTimeMinutes, AfterKeyTimeMinutes);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 计算休眠结束时间                                                  |
//+------------------------------------------------------------------+
datetime CalculateSleepEndTime(string reason)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime currentTime = TimeCurrent();
   
   // 周五收盘或周末 - 休眠到下周一开盘后30分钟
   if(StringFind(reason, "周五收盘") >= 0)
   {
      // 计算到下周一开盘后30分钟
      int daysToMonday = (8 - dt.day_of_week) % 7;
      if(daysToMonday == 0) daysToMonday = 1;
      
      datetime mondayMorning = currentTime + daysToMonday * 24 * 3600;
      MqlDateTime mondayDt;
      TimeToStruct(mondayMorning, mondayDt);
      mondayDt.hour = DailyOpenHour;
      mondayDt.min = DailyOpenMin + AfterOpenMinutes;
      mondayDt.sec = 0;
      
      return StructToTime(mondayDt);
   }
   
   if(StringFind(reason, "周末") >= 0)
   {
      // 周六或周日，休眠到周一开盘后30分钟
      int daysToMonday = (8 - dt.day_of_week) % 7;
      if(daysToMonday == 0) daysToMonday = 1;
      
      datetime mondayMorning = currentTime + daysToMonday * 24 * 3600;
      MqlDateTime mondayDt;
      TimeToStruct(mondayMorning, mondayDt);
      mondayDt.hour = DailyOpenHour;
      mondayDt.min = DailyOpenMin + AfterOpenMinutes;
      mondayDt.sec = 0;
      
      return StructToTime(mondayDt);
   }
   
   // 每日收盘前 - 休眠到收盘时间（短时间休眠避免过夜费）
   if(StringFind(reason, "每日收盘") >= 0)
   {
      // 计算收盘时间
      MqlDateTime closeDt = dt;
      closeDt.hour = DailyCloseHour;
      closeDt.min = DailyCloseMin;
      closeDt.sec = 0;
      
      datetime closeTime = StructToTime(closeDt);
      if(closeTime <= currentTime)
         closeTime += 24 * 3600;  // 如果已过收盘时间，计算明天收盘时间
      
      return closeTime;
   }
   
   // 每日开盘后 - 休眠到开盘后10分钟结束（短时间休眠）
   if(StringFind(reason, "每日开盘后") >= 0)
   {
      // 直接返回当前时间 + 10分钟
      return currentTime + AfterOpenMinutes * 60;
   }
   
   // 市场盘切换窗口 - 休眠关键时间后10分钟
   if(StringFind(reason, "盘开盘时间窗口") >= 0)
   {
      return currentTime + AfterKeyTimeMinutes * 60;
   }
   
   // 重要数据公布窗口 - 休眠关键时间后10分钟
   if(StringFind(reason, "数据公布") >= 0 || StringFind(reason, "会议") >= 0)
   {
      return currentTime + AfterKeyTimeMinutes * 60;
   }
   
   // 极端波动 - 休眠RestMinutes分钟
   if(StringFind(reason, "极端波动") >= 0 || StringFind(reason, "极端行情") >= 0)
   {
      return currentTime + RestMinutes * 60;
   }
   
   // 避开时间段 - 预计10分钟后
   if(StringFind(reason, "避开时间段") >= 0)
   {
      return currentTime + 10 * 60;
   }
   
   // 默认10分钟
   return currentTime + 10 * 60;
}

//+------------------------------------------------------------------+
//| 计算波动权重系数（优先级1）                                        |
//+------------------------------------------------------------------+
double CalculateVolatilityWeight()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point == 0) return 1.0;
   
   // 计算30秒波动(最近1根M1 K线)
   double high30s = iHigh(_Symbol, PERIOD_M1, 0);
   double low30s = iLow(_Symbol, PERIOD_M1, 0);
   double open30s = iOpen(_Symbol, PERIOD_M1, 0);
   double close30s = iClose(_Symbol, PERIOD_M1, 0);
   
   double range30s_hl = (high30s - low30s) / point;  // 最高最低价差
   double range30s_oc = MathAbs(open30s - close30s) / point;  // 开收盘价差
   double range30s = MathMax(range30s_hl, range30s_oc);
   
   // 计算1分钟波动(最近2根M1 K线)
   double high1m = MathMax(iHigh(_Symbol, PERIOD_M1, 0), iHigh(_Symbol, PERIOD_M1, 1));
   double low1m = MathMin(iLow(_Symbol, PERIOD_M1, 0), iLow(_Symbol, PERIOD_M1, 1));
   double open1m = iOpen(_Symbol, PERIOD_M1, 1);
   double close1m = iClose(_Symbol, PERIOD_M1, 0);
   
   double range1m_hl = (high1m - low1m) / point;
   double range1m_oc = MathAbs(open1m - close1m) / point;
   double range1m = MathMax(range1m_hl, range1m_oc);
   
   // 根据30秒波动计算权重
   double weight30s = 1.0;
   if(range30s >= 400)
      weight30s = Weight_400pts;       // 2.0
   else if(range30s >= 350)
      weight30s = Weight_350pts;       // 1.2
   else if(range30s >= 300)
      weight30s = Weight_300pts;       // 0.9
   else if(range30s >= 250)
      weight30s = Weight_250pts;       // 0.7
   
   // 根据1分钟波动调整权重（弱化系数0.85）
   double weight1m = 1.0;
   if(range1m >= 400)
      weight1m = Weight_400pts * Minute1_WeakenFactor;
   else if(range1m >= 350)
      weight1m = Weight_350pts * Minute1_WeakenFactor;
   else if(range1m >= 300)
      weight1m = Weight_300pts * Minute1_WeakenFactor;
   else if(range1m >= 250)
      weight1m = Weight_250pts * Minute1_WeakenFactor;
   
   // 取两者较大值
   double finalWeight = MathMax(weight30s, weight1m);
   
   string msg = StringFormat("【优先级1-波动权重】30s=%.0f点(系数%.2f), 1m=%.0f点(系数%.2f), 最终=%.2f",
                            range30s, weight30s, range1m, weight1m, finalWeight);
   WriteLog(msg);
   
   return finalWeight;
}

//+------------------------------------------------------------------+
//| 计算5m/30m波动率比值（优先级2）                                   |
//+------------------------------------------------------------------+
double Calculate5m30mVolatilityRatio()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point == 0) return 1.0;
   
   // 计算过去5分钟的平均波动率
   double total5m = 0;
   for(int i = 0; i < 5; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M1, i);
      double low = iLow(_Symbol, PERIOD_M1, i);
      total5m += (high - low);
   }
   double avg5m = total5m / 5.0;
   
   // 计算过去30分钟的平均波动率
   double total30m = 0;
   for(int i = 0; i < 30; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M1, i);
      double low = iLow(_Symbol, PERIOD_M1, i);
      total30m += (high - low);
   }
   double avg30m = total30m / 30.0;
   
   if(avg30m == 0) return 1.0;
   
   // 计算比值
   double ratio = avg5m / avg30m;
   
   // 如果5m波动率更大
   if(ratio > 1.0)
   {
      // 比值最低按1.2计算
      if(ratio < MinVolatilityRatio)
         ratio = MinVolatilityRatio;
      
      string msg = StringFormat("【优先级2-波动率比值】5m平均=%.2f, 30m平均=%.2f, 比值=%.2f",
                               avg5m, avg30m, ratio);
      WriteLog(msg);
      
      return ratio;
   }
   
   return 1.0;
}

//+------------------------------------------------------------------+
//| 检查是否快速加仓（优先级3）                                       |
//+------------------------------------------------------------------+
bool CheckFastMartingale()
{
   if(totalOrders < FastMartingaleOrders)
      return false;
   
   // 检查是否在指定时间内达到了指定订单数
   if(firstOrderTime == 0)
      return false;
   
   datetime currentTime = TimeCurrent();
   int elapsedSeconds = (int)(currentTime - firstOrderTime);
   int thresholdSeconds = FastMartingaleMinutes * 60;
   
   if(elapsedSeconds <= thresholdSeconds)
   {
      string msg = StringFormat("【优先级3-快速加仓】%d分钟内已加到第%d单, 触发扩大系数%.2f",
                               elapsedSeconds/60, totalOrders, FastMartingaleMultiplier);
      WriteLog(msg);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 计算多维度趋势得分                                                |
//+------------------------------------------------------------------+
void CalculateMultiDimensionTrendScore()
{
   // 1. 趋势法得分(25%)
   trendMethodScore = CalculateTrendMethodScore();
   
   // 2. ML特征得分(30%)
   mlFeatureScore = CalculateMLFeatureScore();
   
   // 3. 订单流得分(20%)
   orderFlowScore = CalculateOrderFlowScore();
   
   // 4. 支撑阻力得分(25%)
   srLevelScore = CalculateSRLevelScore();
   
   // 计算最终得分
   double finalScore = trendMethodScore * TrendMethodWeight + 
                      mlFeatureScore * MLFeatureWeight + 
                      orderFlowScore * OrderFlowWeight + 
                      srLevelScore * SRLevelWeight;
   
   // 判断方向
   if(finalScore > 0.3)
   {
      predictionDirection = 1;  // 看涨
      predictionConfidenceValue = finalScore;
      predictionStrength = MathAbs(finalScore);
      
      if(finalScore > 0.7)
         predictionAdvice = "强烈建议";
      else if(finalScore > 0.5)
         predictionAdvice = "建议";
      else
         predictionAdvice = "谨慎";
         
      predictionStatus = StringFormat("看涨(信心%.0f%%)", predictionConfidenceValue*100);
   }
   else if(finalScore < -0.3)
   {
      predictionDirection = -1;  // 看跌
      predictionConfidenceValue = MathAbs(finalScore);
      predictionStrength = MathAbs(finalScore);
      
      if(finalScore < -0.7)
         predictionAdvice = "强烈建议";
      else if(finalScore < -0.5)
         predictionAdvice = "建议";
      else
         predictionAdvice = "谨慎";
         
      predictionStatus = StringFormat("看跌(信心%.0f%%)", predictionConfidenceValue*100);
   }
   else
   {
      predictionDirection = 0;  // 震荡
      predictionConfidenceValue = 1.0 - MathAbs(finalScore);
      predictionStrength = MathAbs(finalScore);
      predictionAdvice = "观望";
      predictionStatus = "震荡";
   }
   
   string msg = StringFormat("多维度得分: 趋势%.3f, ML%.3f, 订单流%.3f, SR%.3f, 最终%.3f, 方向%d, %s",
                            trendMethodScore, mlFeatureScore, orderFlowScore, srLevelScore,
                            finalScore, predictionDirection, predictionAdvice);
   WriteLog(msg);
}

//+------------------------------------------------------------------+
//| 计算趋势法得分                                                    |
//+------------------------------------------------------------------+
double CalculateTrendMethodScore()
{
   // 多时间框架趋势分析
   double trend1m = CalculateMultiTimeframeTrend(PERIOD_M1, 5);
   double trend5m = CalculateMultiTimeframeTrend(PERIOD_M5, 5);
   double trend15m = CalculateMultiTimeframeTrend(PERIOD_M15, 5);
   double trend1h = CalculateMultiTimeframeTrend(PERIOD_H1, 5);
   
   // 加权计算
   double score = trend1m * DirWeight1m + 
                 trend5m * DirWeight5m + 
                 trend15m * DirWeight15m + 
                 trend1h * DirWeight1h;
   
   return score;
}

//+------------------------------------------------------------------+
//| 计算ML特征得分                                                    |
//+------------------------------------------------------------------+
double CalculateMLFeatureScore()
{
   // 特征1: 动量指标
   double close0 = iClose(_Symbol, PERIOD_M5, 0);
   double close5 = iClose(_Symbol, PERIOD_M5, 5);
   double momentum = (close0 - close5) / close5;
   
   // 特征2: 波动率
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   double volatility = 0;
   if(CopyBuffer(atrHandle, 0, 0, 1, atr_buffer) > 0)
   {
      volatility = atr_buffer[0] / close0;
   }
   
   // 特征3: 趋势一致性
   int upBars = 0;
   int downBars = 0;
   for(int i = 0; i < 10; i++)
   {
      double c1 = iClose(_Symbol, PERIOD_M5, i);
      double c2 = iClose(_Symbol, PERIOD_M5, i+1);
      if(c1 > c2) upBars++;
      else downBars++;
   }
   double consistency = (double)(upBars - downBars) / 10.0;
   
   // 组合得分
   double score = momentum * 50 + consistency * 0.5;
   
   // 归一化到[-1, 1]
   if(score > 1.0) score = 1.0;
   if(score < -1.0) score = -1.0;
   
   return score;
}

//+------------------------------------------------------------------+
//| 计算订单流得分                                                    |
//+------------------------------------------------------------------+
double CalculateOrderFlowScore()
{
   // 分析最近K线的实体大小和影线
   double totalBullish = 0;
   double totalBearish = 0;
   
   for(int i = 0; i < 10; i++)
   {
      double open = iOpen(_Symbol, PERIOD_M5, i);
      double close = iClose(_Symbol, PERIOD_M5, i);
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      
      double body = MathAbs(close - open);
      double upperShadow = high - MathMax(open, close);
      double lowerShadow = MathMin(open, close) - low;
      
      if(close > open)  // 阳线
      {
         totalBullish += body - upperShadow * 0.5 + lowerShadow * 0.5;
      }
      else  // 阴线
      {
         totalBearish += body - lowerShadow * 0.5 + upperShadow * 0.5;
      }
   }
   
   double total = totalBullish + totalBearish;
   if(total == 0) return 0;
   
   double score = (totalBullish - totalBearish) / total;
   
   return score;
}

//+------------------------------------------------------------------+
//| 计算支撑阻力得分                                                  |
//+------------------------------------------------------------------+
double CalculateSRLevelScore()
{
   double currentPrice = iClose(_Symbol, PERIOD_M5, 0);
   
   // 查找最近20根K线的最高点和最低点
   double highest = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 20, 0));
   double lowest = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 20, 0));
   
   double range = highest - lowest;
   if(range == 0) return 0;
   
   // 计算当前价格在区间中的位置
   double position = (currentPrice - lowest) / range;
   
   // 如果接近支撑位(0-0.3),看涨得分高
   // 如果接近阻力位(0.7-1.0),看跌得分高
   double score = 0;
   if(position < 0.3)
      score = 0.5 + (0.3 - position) * 2;  // 0.5 to 1.1
   else if(position > 0.7)
      score = -0.5 - (position - 0.7) * 2;  // -0.5 to -1.1
   else
      score = (0.5 - position) * 0.5;  // 接近中间为0
   
   // 限制在[-1, 1]
   if(score > 1.0) score = 1.0;
   if(score < -1.0) score = -1.0;
   
   return score;
}

//+------------------------------------------------------------------+
//| 计算四因子盈利目标                                                |
//+------------------------------------------------------------------+
double CalculateUltimateMarginTarget()
{
   // 方法1: 多因子计算(35%)
   multiFactorTarget = CalculateMultiFactorTarget();
   
   // 方法2: 波动预测(25%)
   volatilityPredTarget = CalculateVolatilityPredTarget();
   
   // 方法3: 概率期望(25%)
   probExpectTarget = CalculateProbExpectTarget();
   
   // 方法4: 风险收益(15%)
   riskRewardTarget = CalculateRiskRewardTarget();
   
   // 加权综合
   double target = multiFactorTarget * MultiFactorWeight + 
                  volatilityPredTarget * VolatilityPredWeight + 
                  probExpectTarget * ProbExpectWeight + 
                  riskRewardTarget * RiskRewardWeight;
   
   string msg = StringFormat("四因子目标: 多因子%.2f%%, 波动%.2f%%, 概率%.2f%%, 风险%.2f%%, 综合%.2f%%",
                            multiFactorTarget, volatilityPredTarget, probExpectTarget, 
                            riskRewardTarget, target);
   WriteLog(msg);
   
   return target;
}

//+------------------------------------------------------------------+
//| 计算多因子目标                                                    |
//+------------------------------------------------------------------+
double CalculateMultiFactorTarget()
{
   // 基于趋势强度
   double trendScore = CalculateTrendWeightScore();
   double baseTarget = trendScore * FirstOrderMaxMarginRate;
   
   // 调整系数
   double adjustFactor = 1.0;
   
   // 根据当前订单数调整
   if(totalOrders == 0)
      adjustFactor = 1.0;
   else if(totalOrders == 1)
      adjustFactor = 0.6;
   else if(totalOrders == 2)
      adjustFactor = 0.3;
   else
      adjustFactor = 0.2 * MathPow(MarginRateDecay, totalOrders - 3);
   
   return baseTarget * adjustFactor;
}

//+------------------------------------------------------------------+
//| 计算波动预测目标                                                  |
//+------------------------------------------------------------------+
double CalculateVolatilityPredTarget()
{
   // 计算预测波动
   double predictedVol = CalculatePredictedVolatility();
   
   // 波动越大,目标可以设置越高
   double target = predictedVol * 20.0;  // 转换系数
   
   // 限制范围
   if(target > 50.0) target = 50.0;
   if(target < 5.0) target = 5.0;
   
   return target;
}

//+------------------------------------------------------------------+
//| 计算概率期望目标                                                  |
//+------------------------------------------------------------------+
double CalculateProbExpectTarget()
{
   // 基于信心度和趋势强度
   double confidence = predictionConfidenceValue;
   double strength = predictionStrength;
   
   // 信心度和强度越高,目标越高
   double target = (confidence + strength) * 25.0;
   
   // 限制范围
   if(target > 40.0) target = 40.0;
   if(target < 5.0) target = 5.0;
   
   return target;
}

//+------------------------------------------------------------------+
//| 计算风险收益目标                                                  |
//+------------------------------------------------------------------+
double CalculateRiskRewardTarget()
{
   // 基于当前订单数和总保证金
   double totalMargin = CalculateTotalMargin();
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(accountBalance == 0) return 10.0;
   
   // 保证金占比越高,目标应该越低(风险控制)
   double marginRatio = totalMargin / accountBalance;
   
   double target = 30.0 * (1.0 - marginRatio * 2.0);
   
   // 限制范围
   if(target > 30.0) target = 30.0;
   if(target < 5.0) target = 5.0;
   
   return target;
}

//+------------------------------------------------------------------+
//| 计算下次休眠时间和原因（预警功能）                                  |
//+------------------------------------------------------------------+
void CalculateNextSleepTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime currentTime = TimeCurrent();
   int currentMinutes = dt.hour * 60 + dt.min;
   
   datetime nearestSleepTime = 0;
   string nearestReason = "";
   
   // 基础时间控制检查
   if(EnableTimeControl)
   {
      // 检查周五收盘
      if(NoWeekendPositions && dt.day_of_week == 5)
      {
         int fridayCloseMinutes = FridayCloseHour * 60 + FridayCloseMin;
         if(currentMinutes < fridayCloseMinutes)
         {
            MqlDateTime fridayDt = dt;
            fridayDt.hour = FridayCloseHour;
            fridayDt.min = FridayCloseMin;
            fridayDt.sec = 0;
            datetime fridayTime = StructToTime(fridayDt);
            
            if(nearestSleepTime == 0 || fridayTime < nearestSleepTime)
            {
               nearestSleepTime = fridayTime;
               nearestReason = "周五收盘";
            }
         }
      }
   }
   
   // 市场时间节点控制检查
   if(EnableMarketTimeControl)
   {
      // 每日收盘前
      int dailyCloseMinutes = DailyCloseHour * 60 + DailyCloseMin;
      int beforeCloseStart = dailyCloseMinutes - BeforeCloseMinutes;
      
      if(currentMinutes < beforeCloseStart)
      {
         MqlDateTime closeDt = dt;
         closeDt.hour = beforeCloseStart / 60;
         closeDt.min = beforeCloseStart % 60;
         closeDt.sec = 0;
         datetime closeTime = StructToTime(closeDt);
         
         if(nearestSleepTime == 0 || closeTime < nearestSleepTime)
         {
            nearestSleepTime = closeTime;
            nearestReason = "每日收盘前" + IntegerToString(BeforeCloseMinutes) + "分钟";
         }
      }
      
      // 亚洲盘开盘前
      int asiaOpenMin = AsiaOpenHour * 60 + AsiaOpenMin;
      int beforeAsiaStart = asiaOpenMin - BeforeKeyTimeMinutes;
      
      if(currentMinutes < beforeAsiaStart)
      {
         MqlDateTime asiaDt = dt;
         asiaDt.hour = beforeAsiaStart / 60;
         asiaDt.min = beforeAsiaStart % 60;
         asiaDt.sec = 0;
         datetime asiaTime = StructToTime(asiaDt);
         
         if(nearestSleepTime == 0 || asiaTime < nearestSleepTime)
         {
            nearestSleepTime = asiaTime;
            nearestReason = "亚洲盘开盘前" + IntegerToString(BeforeKeyTimeMinutes) + "分钟";
         }
      }
      
      // 欧洲盘开盘前
      int europeOpenMin = EuropeOpenHour * 60 + EuropeOpenMin;
      int beforeEuropeStart = europeOpenMin - BeforeKeyTimeMinutes;
      
      if(currentMinutes < beforeEuropeStart)
      {
         MqlDateTime europeDt = dt;
         europeDt.hour = beforeEuropeStart / 60;
         europeDt.min = beforeEuropeStart % 60;
         europeDt.sec = 0;
         datetime europeTime = StructToTime(europeDt);
         
         if(nearestSleepTime == 0 || europeTime < nearestSleepTime)
         {
            nearestSleepTime = europeTime;
            nearestReason = "欧洲盘开盘前" + IntegerToString(BeforeKeyTimeMinutes) + "分钟";
         }
      }
      
      // 美国盘开盘前
      int usOpenMin = USOpenHour * 60 + USOpenMin;
      int beforeUSStart = usOpenMin - BeforeKeyTimeMinutes;
      
      if(currentMinutes < beforeUSStart)
      {
         MqlDateTime usDt = dt;
         usDt.hour = beforeUSStart / 60;
         usDt.min = beforeUSStart % 60;
         usDt.sec = 0;
         datetime usTime = StructToTime(usDt);
         
         if(nearestSleepTime == 0 || usTime < nearestSleepTime)
         {
            nearestSleepTime = usTime;
            nearestReason = "美国盘开盘前" + IntegerToString(BeforeKeyTimeMinutes) + "分钟";
         }
      }
   }
   
   nextSleepTime = nearestSleepTime;
   nextSleepReason = nearestReason;
}

//+------------------------------------------------------------------+
//| 获取下次交易盘信息                                                 |
//+------------------------------------------------------------------+
string GetNextTradingSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentHour = dt.hour;
   
   // 判断当前在哪个盘
   string currentSession = "";
   string nextSession = "";
   datetime nextSessionTime = 0;
   
   if(currentHour >= 6 && currentHour < 15)
   {
      currentSession = "亚洲盘";
      nextSession = "欧洲盘";
      MqlDateTime nextDt = dt;
      nextDt.hour = EuropeOpenHour;
      nextDt.min = EuropeOpenMin;
      nextDt.sec = 0;
      nextSessionTime = StructToTime(nextDt);
   }
   else if(currentHour >= 15 && currentHour < 20)
   {
      currentSession = "欧洲盘";
      nextSession = "美国盘";
      MqlDateTime nextDt = dt;
      nextDt.hour = USOpenHour;
      nextDt.min = USOpenMin;
      nextDt.sec = 0;
      nextSessionTime = StructToTime(nextDt);
   }
   else if(currentHour >= 20 || currentHour < 6)
   {
      currentSession = "美国盘";
      nextSession = "亚洲盘";
      MqlDateTime nextDt = dt;
      if(currentHour >= 20)
      {
         nextDt.day += 1;
      }
      nextDt.hour = AsiaOpenHour;
      nextDt.min = AsiaOpenMin;
      nextDt.sec = 0;
      nextSessionTime = StructToTime(nextDt);
   }
   
   int minutesUntilNext = (int)(nextSessionTime - TimeCurrent()) / 60;
   int hoursUntilNext = minutesUntilNext / 60;
   int remainingMinutes = minutesUntilNext % 60;
   
   string result = currentSession;
   if(isSleeping)
   {
      result += " (休眠中)";
   }
   result += " → " + nextSession;
   if(hoursUntilNext > 0)
      result += StringFormat(" (%d时%d分后)", hoursUntilNext, remainingMinutes);
   else
      result += StringFormat(" (%d分后)", remainingMinutes);
   
   return result;
}

//+------------------------------------------------------------------+
//| 计算未来24小时交易事件                                                |
//+------------------------------------------------------------------+
void CalculateNext24hEvents()
{
   if(!EnableMarketTimeControl)
   {
      next24hEvents = "";
      return;
   }
   
   datetime currentTime = TimeCurrent();
   datetime endTime = currentTime + 24 * 3600;
   
   // 存储事件的结构
   struct EventInfo
   {
      datetime time;
      string description;
   };
   
   EventInfo eventList[];
   int eventCount = 0;
   
   // 预分配数组空间
   ArrayResize(eventList, 20);
   
   // 收集未来24小时的所有事件
   for(datetime checkTime = currentTime; checkTime <= endTime; checkTime += 60)
   {
      MqlDateTime dt;
      TimeToStruct(checkTime, dt);
      int checkMinutes = dt.hour * 60 + dt.min;
      
      // 检查每日收盘前20分钟
      int dailyCloseMinutes = DailyCloseHour * 60 + DailyCloseMin;
      int beforeCloseStart = dailyCloseMinutes - BeforeCloseMinutes;
      if(checkMinutes == beforeCloseStart && checkTime > currentTime)
      {
         eventList[eventCount].time = checkTime;
         eventList[eventCount].description = StringFormat("[每日收盘] 休眠开始(前%d分钟)", BeforeCloseMinutes);
         eventCount++;
      }
      
      // 检查每日开盘后10分钟结束
      int dailyOpenMinutes = DailyOpenHour * 60 + DailyOpenMin;
      int afterOpenEnd = dailyOpenMinutes + AfterOpenMinutes;
      if(checkMinutes == afterOpenEnd && checkTime > currentTime)
      {
         eventList[eventCount].time = checkTime;
         eventList[eventCount].description = StringFormat("[每日开盘] 休眠结束(后%d分钟)", AfterOpenMinutes);
         eventCount++;
      }
      
      // 检查市场盘切换前15分钟
      // 亚洲盘开盘前
      int asiaOpenMinutes = AsiaOpenHour * 60 + AsiaOpenMin;
      int beforeAsiaStart = asiaOpenMinutes - BeforeKeyTimeMinutes;
      if(checkMinutes == beforeAsiaStart && checkTime > currentTime)
      {
         eventList[eventCount].time = checkTime;
         eventList[eventCount].description = StringFormat("[亚洲盘] 开盘前%d分钟", BeforeKeyTimeMinutes);
         eventCount++;
      }
      
      // 欧洲盘开盘前
      int europeOpenMinutes = EuropeOpenHour * 60 + EuropeOpenMin;
      int beforeEuropeStart = europeOpenMinutes - BeforeKeyTimeMinutes;
      if(checkMinutes == beforeEuropeStart && checkTime > currentTime)
      {
         eventList[eventCount].time = checkTime;
         eventList[eventCount].description = StringFormat("[欧洲盘] 开盘前%d分钟", BeforeKeyTimeMinutes);
         eventCount++;
      }
      
      // 美国盘开盘前
      int usOpenMinutes = USOpenHour * 60 + USOpenMin;
      int beforeUSStart = usOpenMinutes - BeforeKeyTimeMinutes;
      if(checkMinutes == beforeUSStart && checkTime > currentTime)
      {
         eventList[eventCount].time = checkTime;
         eventList[eventCount].description = StringFormat("[美国盘] 开盘前%d分钟", BeforeKeyTimeMinutes);
         eventCount++;
      }
      
      // 检查周五收盘
      if(NoWeekendPositions && dt.day_of_week == 5)
      {
         int fridayCloseMinutes = FridayCloseHour * 60 + FridayCloseMin;
         if(checkMinutes == fridayCloseMinutes && checkTime > currentTime)
         {
            eventList[eventCount].time = checkTime;
            eventList[eventCount].description = "[周末] 周五收盘休眠";
            eventCount++;
         }
      }
      
      // 限制最多显示10个事件
      if(eventCount >= 10) break;
   }
   
   // 格式化输出
   string result = "";
   if(eventCount > 0)
   {
      for(int i = 0; i < eventCount; i++)
      {
         MqlDateTime dt;
         TimeToStruct(eventList[i].time, dt);
         result += StringFormat("%02d:%02d %s\n", dt.hour, dt.min, eventList[i].description);
      }
   }
   else
   {
      result = "暂无交易事件\n";
   }
   
   next24hEvents = result;
}

//+------------------------------------------------------------------+
