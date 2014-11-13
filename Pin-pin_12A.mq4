//+------------------------------------------------------------------+
//             Copyright © 2012, 2013, 2014 chew-z                   |
// v 1.2 - zarządzanie według ideii z materiału o Pin Bars           |
// to jest refaktoryzacja "starego" Pin-pin do nowych                |
// korzysta z TradeTols5 i nowych procedur                           |
// ale logika nie powinna ulec zmianie                               |
// dopiero później nadejdzie czas na zmiany logiki                   |
//+------------------------------------------------------------------+
#property copyright "Pin-pin Pullback © 2012-2014 chew-z"
#include <TradeContext.mq4>
#include <TradeTools\TradeTools5.mqh>
#include <stdlib.mqh>

int magic_number_1 = 10303276;
string orderComment = "Pin-pin 1.2";
int contracts = 0;

int StopLevel;
static int t;
int ticketArr[];
double TakeProfit1;

//--------------------------
int OnInit()     {
   BarTime = 0;
   ArrayResize(ticketArr, maxContracts, maxContracts);
   for(int i=0; i < maxContracts; i++) //re-initialize table with order tickets
        ticketArr[i] = 0;
   AlertEmailSubject = Symbol() + " " + orderComment + " alert";
   if (Digits == 5 || Digits == 3){    // Adjust for five (5) digit brokers.
      pips2dbl    = Point*10; pips2points = 10;   Digits_pips = 1;
   } else {    pips2dbl    = Point;    pips2points =  1;   Digits_pips = 0; }
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)   {
   Print(__FUNCTION__,"_Deinitalization reason code = ", getDeinitReasonText(reason));
}
//-------------------------
void OnTick()    {
bool isNewBar = NewBar();
bool isNewDay = NewDay2();
double StopLoss, TakeProfit;
bool  LongBuy = false, ShortBuy = false;
int cnt, check;
double Lots;

if ( isNewDay ) {
     lookBackDays = f_lookBackDays(); //
     GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0); // zerowanie o północy
}

// DISCOVER SIGNALS
if (isNewBar && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) < 1) {
      int iDay = iBarShift(NULL, PERIOD_D1, Time[0], false);
      H = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,lookBackDays,iDay+1));
      L = iLow (NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW,lookBackDays,iDay+1));
      if (isRecentHigh_L() && isPullback_L1()   ) {
            LongBuy = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 2); // Zajmuje dwie pozycje(loty)
      }
      if (isRecentLow_S() && isPullback_S1()   )  {
            ShortBuy = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 2); // Zajmuje dwie pozycje(loty)
      }
}

if( isNewBar ) {
// MONEY MANAGEMENT
      Lots =  maxLots;
      cnt = f_OrdersTotal(magic_number_1, ticketArr) + 1;   //how many open lots?
      contracts = f_Money_Management() - cnt;               //how many possible?
// ENTER MARKET CONDITIONS
      if( cnt < contracts )   { //if we are able to open new lots...
      // check for long position (BUY) possibility
         if(LongBuy == true )      {
            StopLoss = NormalizeDouble(Ask - f_initialStop_5(), Digits);
            TakeProfit1 = NormalizeDouble(H , Digits);
            TakeProfit = NormalizeDouble(Ask+TP*pips2dbl , Digits);
      //--------Transaction
            check = f_SendOrders(OP_BUY, 1, Lots, StopLoss, TakeProfit1, magic_number_1, orderComment);
            check = f_SendOrders(OP_BUY, contracts-1, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);
      //--------
            if(check==0)         {
                 AlertText = "BUY order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
                  + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Ask, 5) + ", L = " + DoubleToStr(L, 5);
            }  else { AlertText = "Error opening BUY order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", L = " + DoubleToStr(L, 5); }
            f_SendAlerts(AlertText);
         }
      // check for short position (SELL) possibility
         if(ShortBuy == true )      {
            StopLoss = NormalizeDouble(Bid + f_initialStop_5(), Digits);
            TakeProfit1 = NormalizeDouble(L , Digits);
            TakeProfit = NormalizeDouble(Bid-TP*pips2dbl , Digits);
      //--------Transaction
            check = f_SendOrders(OP_SELL, 1, Lots, StopLoss, TakeProfit1, magic_number_1, orderComment);
            check = f_SendOrders(OP_SELL, contracts-1, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);
      //--------
            if(check==0)         {
                  AlertText = "SELL order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
                  + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Bid, 5) + ", H = " + DoubleToStr(H, 5);
            }  else { AlertText = "Error opening SELL order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Bid, 5) + ", H = " + DoubleToStr(H, 5); }
            f_SendAlerts(AlertText);
         }
      }
}//isNewBar

if ( isNewDay ) {
   for(int i=0; i < maxContracts; i++) //re-initialize an array with order tickets
      ticketArr[i] = 0;
// MODIFY ORDERS [move SL to breakeven]
   cnt = f_OrdersTotal(magic_number_1, ticketArr); //-1 = no active orders
   while (cnt > -1) {                              //
      if(OrderSelect(ticketArr[cnt], SELECT_BY_TICKET, MODE_TRADES) )   {
         if(OrderType()== OP_BUY && (Ask - OrderOpenPrice()) > TP * pips2dbl ) {
            RefreshRates();
            StopLoss = OrderOpenPrice();
            TakeProfit = NormalizeDouble(H , Digits);
            if ( TakeProfit != OrderTakeProfit() || StopLoss > OrderStopLoss() + 5*pips2dbl ) {
                  if(TradeIsBusy() < 0) // Trade Busy semaphore
                     break;
                  check = OrderModify(OrderTicket(),OrderOpenPrice(), StopLoss, TakeProfit, 0, Gold);
                  TradeIsNotBusy();
                  AlertText = orderComment + " " + Symbol() + " BUY order modification attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5);
                  f_SendAlerts(AlertText);
            }
         }
         if(OrderType()==OP_SELL && (OrderOpenPrice()- Bid) > TP * pips2dbl ) {
            RefreshRates();
            StopLoss = OrderOpenPrice();
            TakeProfit = NormalizeDouble(L , Digits);
            if ( TakeProfit != OrderTakeProfit() || StopLoss < OrderStopLoss() + 5*pips2dbl )  {
                  if(TradeIsBusy() < 0) // Trade Busy semaphore
                     break;
                  check = OrderModify(OrderTicket(),OrderOpenPrice(), StopLoss, TakeProfit, 0, Gold);
                  TradeIsNotBusy();
                  AlertText = orderComment + " " + Symbol() + " SELL order modification attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5);
                  f_SendAlerts(AlertText);
            }
         }
      }//if OrderSelect
      cnt--;
   } //while cnt > -1
}// isNewDay
//END MODIFY ORDERS


}// exit OnTick
