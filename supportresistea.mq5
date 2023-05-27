//+------------------------------------------------------------------+
//|                                              supportresistea.mq5 |
//|                                       Copyright 2021, Adexmedia. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Adexmedia."
#property link      "https://www.mql5.com"
#property version   "1.00"

static input string StrategyProperties__ = "------------"; // ------ Expert Properties ------
static input double Entry_Amount = 0.01; // Entry lots
input int Stop_Loss   = 0; // Stop Loss 
input bool useTrailingStop= false;  // use trailing stoploss?
input int Take_Profit = 300; // Take Profit 
input bool stopTrading = false;   //Stop trading
input bool tradeLong = true; // should I take long trades?
input bool tradeShort = true; // should I take short trades?
input bool counterTrading = true;  // take counter trades?
input bool trendTrading = true;  // take trend trades?

static input string ExpertSettings__ = "------------"; // ------ Expert Settings ------
static input int Magic_Number = 06091503; // Magic Number

#define TRADE_RETRY_COUNT 4
#define TRADE_RETRY_WAIT  100
#define OP_FLAT           -1
#define OP_BUY            ORDER_TYPE_BUY
#define OP_SELL           ORDER_TYPE_SELL

// Session time is set in seconds from 00:00
int sessionSundayOpen           = 0;     // 00:00
int sessionSundayClose          = 86400; // 24:00
int sessionMondayThursdayOpen   = 0;     // 00:00
int sessionMondayThursdayClose  = 86400; // 24:00
int sessionFridayOpen           = 0;     // 00:00
int sessionFridayClose          = 86400; // 24:00
bool sessionIgnoreSunday        = false;
bool sessionCloseAtSessionClose = false;
bool sessionCloseAtFridayClose  = false;

const double sigma=0.000001;

double posType       = OP_FLAT;
ulong  posTicket     = 0;
double posLots       = 0;
double posStopLoss   = 0;
double posTakeProfit = 0;

datetime barTime;
int      digits;
double   pip;
double   stopLevel;
bool     isTrailingStop=true;

ENUM_ORDER_TYPE_FILLING orderFillingType;

int ind0handler;
int ind1handler;
int ind2handler;

int    handle_iStochastic, handle_iStochastich1, handle_iStochastic15, handle_iStochastic30, handle_iStochasticM1; 
int    handle_iMACD;                         // variable for storing the handle of the iMACD indicator 
int maFastHandle, maSlowHandle;
int macdhandle;
int stochHandler;
int cchandler, myCCi,myTDI; 
//int STP,TKP;     // 


// 0 - undefined, 1 - bullish cross (fast MA above slow MA), -1 - bearish cross (fast MA below slow MA).
int PrevCross = 0;
int SlowMA;
int FastMA;
int my_supres, my_macd;

int myMA1, myMA2, SpearH4, SpearD1, myBB;
double Poin;

   double buff4[];
   double buff5[];
   double buff6[];
   double buff7[]; 


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   barTime          = Time(0);
   digits           = (int) SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   pip              = GetPipValue(digits);
   stopLevel        = (int) SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   orderFillingType = GetOrderFillingType();
   isTrailingStop   = useTrailingStop && Stop_Loss > 0;
   
   my_supres = iCustom(_Symbol,_Period,"Shved-supply-and-demand-indicator.ex5");  
   //myTDI = iCustom(NULL,PERIOD_M1,"mt5\\Traders_Dynamic_Index",12,PRICE_CLOSE,34,2,MODE_SMA,7,MODE_SMA,80,20,true,false);

  

   const ENUM_INIT_RETCODE initRetcode = ValidateInit();

   return (initRetcode);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime time=Time(0);
   if(time>barTime)
     {
      barTime=time;
      OnBar();
     }
   
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnBar()
  {
   UpdatePosition();

   if(posType!=OP_FLAT && IsForceSessionClose())
     {
      ClosePosition();
      return;
     }

   if(IsOutOfSession())
      return;

   if(posType!=OP_FLAT)
     {
      ManageClose();
      UpdatePosition();
     }

   if(posType!=OP_FLAT && isTrailingStop)
     {
      double trailingStop=GetTrailingStop();
      ManageTrailingStop(trailingStop);
      UpdatePosition();
     }

   if(posType==OP_FLAT)
     {
      ManageOpen();
      UpdatePosition();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdatePosition()
  {
   posType   = OP_FLAT;
   posTicket = 0;
   posLots   = 0;
   int posTotal=PositionsTotal();
   for(int posIndex=0;posIndex<posTotal;posIndex++)
     {
      const ulong ticket=PositionGetTicket(posIndex);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==Magic_Number)
        {
         posType       = (int) PositionGetInteger(POSITION_TYPE);
         posLots       = NormalizeDouble(PositionGetDouble(POSITION_VOLUME), 2);
         posTicket     = ticket;
         posStopLoss   = NormalizeDouble(PositionGetDouble(POSITION_SL), digits);
         posTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), digits);
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOpen()
  {
    
    
   MqlRates mrate[];
   ArraySetAsSeries(mrate,true);
   if(CopyRates(_Symbol,PERIOD_M1,0,4,mrate)<0)
     {
      Alert("failed to copy price data",GetLastError(),"!!");
      return;
     }
   
   //double   A0close = mrate[0].close;          
   //double   A1close = mrate[1].close;
   //double   A2close = mrate[2].close;
   //double   A3close = mrate[3].close;
   //double   A1open = mrate[1].open;
   //double   A2open = mrate[2].open;
   //double   A3open = mrate[3].open;
   
   double   A0high = mrate[0].high;          
   double   A1high = mrate[1].high;
   double   A2high = mrate[2].high;
   double   A3high = mrate[3].high;
   double   A1low = mrate[1].low;
   double   A2low = mrate[2].low;
   double   A3low = mrate[3].low;
            
   ArraySetAsSeries(buff4,true);
   ArraySetAsSeries(buff5,true);
   ArraySetAsSeries(buff6,true);
   ArraySetAsSeries(buff7,true);
     
   CopyBuffer(my_supres,4,0,4,buff4);  
   CopyBuffer(my_supres,5,0,4,buff5);
   CopyBuffer(my_supres,6,0,4,buff6);
   CopyBuffer(my_supres,7,0,4,buff7);

  
  /* 
   buff4[1]   ------ Resistance high
   buff5[1]   ------ Resistance low
   buff6[1]   ------ Support high
   buff7[1]   ------ Support low 
   */
 
 /*
//Trading rules using open close candle
   //candle 2 closes below upper resistance line and candle 1 closes above upper resistance line
   bool buy_trend = (A2open < buff4[0]) && (A1close > buff4[0]) && (tradeLong) && (!stopTrading) && (trendTrading);    
   //candle 2 closes above below upper support line and candle 1 closes above upper support line
   bool buy_counter_trend = (A2open < buff6[0]) && (A1close > buff6[0]) && (tradeLong) && (!stopTrading) && (counterTrading);  
   //candle 2 closes above lower support line and candle 1 closes below lower support line
   bool sell_trend = (A2close > buff7[0]) && (A1close < buff7[0]) && (tradeShort) && (!stopTrading) && (trendTrading);  
   //candle 2 closes above lower resistance line and candle 1 closes below lower resistance line
   bool sell_counter = (A2close > buff5[0]) && (A1close < buff5[0]) && (tradeShort) && (!stopTrading) && (counterTrading);
*/
   
//Trading rules using high low of candle
   //candle 2 closes below upper resistance line and candle 1 closes above upper resistance line
      bool buy_trend = (A2low < buff4[0]) && (A1high > buff4[0]) && (tradeLong) && (!stopTrading) && (trendTrading);    
   //candle 2 closes above below upper support line and candle 1 closes above upper support line
      bool buy_counter_trend = (A2low < buff6[0]) && (A1high > buff6[0]) && (tradeLong) && (!stopTrading) && (counterTrading);  
   //candle 2 closes above lower support line and candle 1 closes below lower support line
      bool sell_trend = (A2high > buff7[0]) && (A1low < buff7[0]) && (tradeShort) && (!stopTrading) && (trendTrading); 
   //candle 2 closes above lower resistance line and candle 1 closes below lower resistance line
      bool sell_counter = (A2high > buff5[0]) && (A1low < buff5[0]) && (tradeShort) && (!stopTrading) && (counterTrading); 
 
   
   const bool canOpenLong  = (buy_trend); //(sell_counter_trend) ;    || buy_counter_trend
   const bool canOpenShort = (sell_trend); //(sell_trend || sell_counter);   || sell_counter

   if(canOpenLong && canOpenShort) return;

   if(canOpenLong)
      OpenPosition(OP_BUY);
   else if(canOpenShort)
      OpenPosition(OP_SELL);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageClose()
  {
  
  /* 
  //-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  //-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   buff4[1]   ------ Resistance high
   buff5[1]   ------ Resistance low
   buff6[1]   ------ Support high
   buff7[1]   ------ Support low
   
   */  
   
   MqlRates mrate[];
   ArraySetAsSeries(mrate,true);
   if(CopyRates(_Symbol,PERIOD_M1,0,4,mrate)<0)
     {
      Alert("failed to copy price data",GetLastError(),"!!");
      return;
     }
   
   double   A0close = mrate[0].close;          
   double   A1close = mrate[1].close;
   double   A2close = mrate[2].close;
   double   A3close = mrate[3].close;
   double   A1open = mrate[1].open;
   double   A2open = mrate[2].open;
   double   A3open = mrate[3].open;
  
  
   double myTDIArr[];  
   ArraySetAsSeries(myTDIArr,true); 
   CopyBuffer(myTDI,3,0,3,myTDIArr);
   
   double myCCiArr[];  
   ArraySetAsSeries(myCCiArr,true); 
   CopyBuffer(myCCi,MAIN_LINE,0,3,myCCiArr);
  
  
   bool close_buy_condition  = false; //(A1close < buff7[1]) && (A1open < buff7[1]);    //myTDIArr[1] > 80
   bool close_sell_condition = (false); //(myTDIArr[1] < 20) ||    (myCCiArr[1] < -100)

   if(posType==OP_BUY && close_buy_condition)
      ClosePosition();
   else if(posType==OP_SELL && close_sell_condition)
      ClosePosition();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenPosition(int command)
  {
   double ourLot;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(Entry_Amount < minLot){
      ourLot = minLot;
      Print("Your lot size is not valid. I am using the smallest available lot ");
   } else{
      ourLot = Entry_Amount;
   }
   const double stopLoss   = GetStopLossPrice(command);
   const double takeProfit = GetTakeProfitPrice(command);
   //ManageOrderSend(command,ourLot,stopLoss,takeProfit,0);
   ManageOrderSend(command,ourLot,stopLoss,takeProfit,0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePosition()
  {
   const int command=posType==OP_BUY ? OP_SELL : OP_BUY;
   ManageOrderSend(command,posLots,0,0,posTicket);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOrderSend(int command,double lots,double stopLoss,double takeProfit,ulong ticket)
  {
   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(IsTradeContextFree())
        {
         ResetLastError();
         MqlTick         tick;    SymbolInfoTick(_Symbol,tick);
         MqlTradeRequest request; ZeroMemory(request);
         MqlTradeResult  result;  ZeroMemory(result);

         request.action       = TRADE_ACTION_DEAL;
         request.symbol       = _Symbol;
         request.volume       = lots;
         request.type         = command==OP_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         request.price        = command==OP_BUY ? tick.ask : tick.bid;
         request.type_filling = orderFillingType;
         request.deviation    = 10;
         request.sl           = stopLoss;
         request.tp           = takeProfit;
         request.magic        = Magic_Number;
         request.position     = ticket;
         request.comment      = IntegerToString(Magic_Number);

         bool isOrderCheck = CheckOrder(request);
         bool isOrderSend  = false;

         if(isOrderCheck)
           {
            isOrderSend=OrderSend(request,result);
           }

         if(isOrderCheck && isOrderSend && result.retcode==TRADE_RETCODE_DONE)
            Print("Trade placed successfully");
            return;
        }
      Sleep(TRADE_RETRY_WAIT);
      Print("Order Send retry no: "+IntegerToString(attempt+2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyPosition(double stopLoss,double takeProfit,ulong ticket)
  {
   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(IsTradeContextFree())
        {
         ResetLastError();
         MqlTick         tick;    SymbolInfoTick(_Symbol,tick);
         MqlTradeRequest request; ZeroMemory(request);
         MqlTradeResult  result;  ZeroMemory(result);

         request.action   = TRADE_ACTION_SLTP;
         request.symbol   = _Symbol;
         request.sl       = stopLoss;
         request.tp       = takeProfit;
         request.magic    = Magic_Number;
         request.position = ticket;
         request.comment  = IntegerToString(Magic_Number);

         bool isOrderCheck = CheckOrder(request);
         bool isOrderSend  = false;

         if(isOrderCheck)
           {
            isOrderSend=OrderSend(request,result);
           }

         if(isOrderCheck && isOrderSend && result.retcode==TRADE_RETCODE_DONE)
            return;
        }
      Sleep(TRADE_RETRY_WAIT);
      Print("Order Send retry no: "+IntegerToString(attempt+2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckOrder(MqlTradeRequest &request)
  {
   MqlTradeCheckResult check; ZeroMemory(check);
   const bool isOrderCheck=OrderCheck(request,check);
   if(isOrderCheck) return (true);


   if(check.retcode==TRADE_RETCODE_INVALID_FILL)
     {
      switch(orderFillingType)
        {
         case  ORDER_FILLING_FOK:
            orderFillingType=ORDER_FILLING_IOC;
            break;
         case  ORDER_FILLING_IOC:
            orderFillingType=ORDER_FILLING_RETURN;
            break;
         case  ORDER_FILLING_RETURN:
            orderFillingType=ORDER_FILLING_FOK;
            break;
        }

      request.type_filling=orderFillingType;

      const bool isNewCheck=CheckOrder(request);

      return (isNewCheck);
     }

   Print("Error with OrderCheck: "+check.comment);
   return (false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStopLossPrice(int command)
  {
   if(Stop_Loss==0) return (0);

   MqlTick tick; SymbolInfoTick(_Symbol,tick);
   const double delta    = MathMax(pip*Stop_Loss, _Point*stopLevel);
   const double price    = command==OP_BUY ? tick.bid : tick.ask;
   const double stopLoss = command==OP_BUY ? price-delta : price+delta;
   const double normalizedStopLoss = NormalizeDouble(stopLoss, _Digits);

   return (normalizedStopLoss);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTrailingStop()
  {
   MqlTick tick; SymbolInfoTick(_Symbol,tick);
   const double stopLevelPoints = _Point*stopLevel;
   const double stopLossPoints  = pip*Stop_Loss;

   if(posType==OP_BUY)
     {
      const double stopLossPrice=High(1)-stopLossPoints;
      if(posStopLoss<stopLossPrice-pip)
        {
         if(stopLossPrice<tick.bid)
           {
            const double fixedStopLossPrice = (stopLossPrice>=tick.bid-stopLevelPoints)
                                              ? tick.bid - stopLevelPoints
                                              : stopLossPrice;

            return (fixedStopLossPrice);
           }
         else
           {
            return (tick.bid);
           }
        }
     }

   else if(posType==OP_SELL)
     {
      const double stopLossPrice=Low(1)+stopLossPoints;
      if(posStopLoss>stopLossPrice+pip)
        {
         if(stopLossPrice>tick.ask)
           {
            if(stopLossPrice<=tick.ask+stopLevelPoints)
               return (tick.ask + stopLevelPoints);
            else
               return (stopLossPrice);
           }
         else
           {
            return (tick.ask);
           }
        }
     }

   return (posStopLoss);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageTrailingStop(double trailingStop)
  {
   MqlTick tick; SymbolInfoTick(_Symbol,tick);

   if(posType==OP_BUY && MathAbs(trailingStop-tick.bid)<_Point)
     {
      ClosePosition();
     }

   else if(posType==OP_SELL && MathAbs(trailingStop-tick.ask)<_Point)
     {
      ClosePosition();
     }

   else if(MathAbs(trailingStop-posStopLoss)>_Point)
     {
      posStopLoss=NormalizeDouble(trailingStop,digits);
      ModifyPosition(posStopLoss,posTakeProfit,posTicket);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTakeProfitPrice(int command)
  {
   if(Take_Profit==0) return (0);

   MqlTick tick; SymbolInfoTick(_Symbol,tick);
   const double delta      = MathMax(pip*Take_Profit, _Point*stopLevel);
   const double price      = command==OP_BUY ? tick.bid : tick.ask;
   const double takeProfit = command==OP_BUY ? price+delta : price-delta;
   const double normalizedTakeProfit = NormalizeDouble(takeProfit, _Digits);

   return (normalizedTakeProfit);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime Time(int bar)
  {
   datetime buffer[]; ArrayResize(buffer,1);
   const int result=CopyTime(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Open(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyOpen(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double High(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyHigh(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Low(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyLow(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Close(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyClose(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetPipValue(int digit)
  {
   if(digit==4 || digit==5)
      return (0.0001);
   if(digit==2 || digit==3)
      return (0.01);
   if(digit==1)
      return (0.1);
   return (1);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeContextFree()
  {
   if(MQL5InfoInteger(MQL5_TRADE_ALLOWED)) return (true);

   uint startWait=GetTickCount();
   Print("Trade context is busy! Waiting...");

   while(true)
     {
      if(IsStopped()) return (false);

      uint diff=GetTickCount()-startWait;
      if(diff>30*1000)
        {
         Print("The waiting limit exceeded!");
         return (false);
        }

      if(MQL5InfoInteger(MQL5_TRADE_ALLOWED)) return (true);

      Sleep(TRADE_RETRY_WAIT);
     }

   return (true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOutOfSession()
  {
   MqlDateTime time0; TimeToStruct(Time(0),time0);
   const int weekDay           = time0.day_of_week;
   const long timeFromMidnight = Time(0)%86400;
   const int periodLength      = PeriodSeconds(_Period);

   if(weekDay==0)
     {
      if(sessionIgnoreSunday) return (true);

      const int lastBarFix = sessionCloseAtSessionClose ? periodLength : 0;
      const bool skipTrade = timeFromMidnight<sessionSundayOpen ||
                             timeFromMidnight+lastBarFix>sessionSundayClose;

      return (skipTrade);
     }

   if(weekDay<5)
     {
      const int lastBarFix = sessionCloseAtSessionClose ? periodLength : 0;
      const bool skipTrade = timeFromMidnight<sessionMondayThursdayOpen ||
                             timeFromMidnight+lastBarFix>sessionMondayThursdayClose;

      return (skipTrade);
     }

   const int lastBarFix=sessionCloseAtFridayClose || sessionCloseAtSessionClose ? periodLength : 0;
   const bool skipTrade=timeFromMidnight<sessionFridayOpen || timeFromMidnight+lastBarFix>sessionFridayClose;

   return (skipTrade);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsForceSessionClose()
  {
   if(!sessionCloseAtFridayClose && !sessionCloseAtSessionClose) return (false);

   MqlDateTime time0; TimeToStruct(Time(0),time0);
   const int weekDay           = time0.day_of_week;
   const long timeFromMidnight = Time(0)%86400;
   const int periodLength      = PeriodSeconds(_Period);

   bool forceExit=false;
   if(weekDay==0 && sessionCloseAtSessionClose)
     {
      forceExit=timeFromMidnight+periodLength>sessionSundayClose;
     }
   else if(weekDay<5 && sessionCloseAtSessionClose)
     {
      forceExit=timeFromMidnight+periodLength>sessionMondayThursdayClose;
     }
   else if(weekDay==5)
     {
      forceExit=timeFromMidnight+periodLength>sessionFridayClose;
     }

   return (forceExit);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetOrderFillingType()
  {
   const int oftIndex=(int) SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   const ENUM_ORDER_TYPE_FILLING fillType=(ENUM_ORDER_TYPE_FILLING)(oftIndex>0 ? oftIndex-1 : oftIndex);

   return (fillType);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_INIT_RETCODE ValidateInit()
  {
   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+




 /*  
   //candle 2 closes below upper resistance line and candle 1 closes above upper resistance line
   bool buy_trend = (A2open < buff4[2]) && (A1close > buff4[1]) && (tradeLong) && (!stopTrading) && (trendTrading);  
   
   //candle 2 closes above below upper support line and candle 1 closes above upper support line
   bool buy_counter_trend = (A2open < buff6[2]) && (A1close > buff6[1]) && (tradeLong) && (!stopTrading) && (counterTrading);
   
   //candle 2 closes above lower support line and candle 1 closes below lower support line
   bool sell_trend = (A2close > buff7[2]) && (A1close < buff7[1]) && (tradeShort) && (!stopTrading) && (trendTrading);
   
   //candle 2 closes above lower resistance line and candle 1 closes below lower resistance line
   bool sell_counter = (A2close > buff5[2]) && (A1close < buff5[1]) && (tradeShort) && (!stopTrading) && (counterTrading);
  */ 