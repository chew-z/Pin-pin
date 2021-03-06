//+------------------------------------------------------------------+
//             Copyright Â© 2012, 2013 chew-z                        |
// v 2.0B - ten sam Pin-pin ale lepszy                               |
// 1) Limit order ustwiany o północy na cały dzień                   |
// 2) trailing SL zamiast exit przy zyskownej pozycji                |
// 3) time exit z nierokującej pozycji                               |
// 4)                                                                |
//+------------------------------------------------------------------+
#property copyright "Pin-pin Pullback © 2012, 2013, 2014 chew-z"
#include <TradeContext.mq4>
#include <TradeTools\TradeTools5.mqh>

#include <stdlib.mqh>
int magic_number_1 = 20341236;
string orderComment = "Pin-pin Pullback 2.0";
string AlertText = "";
string  AlertEmailSubject  = "";
static int BarTime;
static int ticketArr[2];
//--------------------------
int OnInit()     {
   BarTime = 0;
   for(int i=0; i < maxContracts; i++) //re-initialize table with order tickets
        ticketArr[i] = 0;
   AlertEmailSubject = Symbol() + " Pin-pin 2.0 alert";
   if (Digits == 5 || Digits == 3){    // Adjust for five (5) digit brokers.
      pips2dbl    = Point*10; pips2points = 10;   Digits_pips = 1;
   } else {    pips2dbl    = Point;    pips2points =  1;   Digits_pips = 0; }
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)   {
   GlobalVariableDel(StringConcatenate(Symbol(), magic_number_1));
   Print(__FUNCTION__,"_Deinitalization reason code = ", getDeinitReasonText(reason));
}
//-------------------------
void OnTick()    {
bool isNewBar = NewBar();
bool isNewDay = NewDay();
double StopLoss, TakeProfit, price;
bool  ShortBuy = false, LongBuy = false;
int cnt, check;
int contracts = 0;
double Lots;
double Hi, Lo;

if ( isNewDay ) {
     lookBackDays = f_lookBackDays(); // 
}

if ( isNewBar ) {
   for(int i=0; i < maxContracts; i++) //re-initialize an array with order tickets
      ticketArr[i] = 0;
// DISCOVER SIGNALS
   if ( f_OrdersTotal(magic_number_1, ticketArr) < 1 )   {
      Lo = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW, K, 1));
      Hi = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH, K, 1));
        if (isRecentHigh_L() && isPullback_L1() )  {  
        LongBuy = true;   } // Zajmuje dwie pozycje(loty)

      if (isRecentLow_S()  && isPullback_S1() )   {  
        ShortBuy = true;  } // Zajmuje dwie pozycje(loty)
   }
} // if isNewDay

if( isNewBar ) {
   cnt = f_OrdersTotal(magic_number_1, ticketArr); //-1 = no active orders
   while (cnt >= 0) {                              //Print ("Ticket #", ticketArr[k]);
      if(OrderSelect(ticketArr[cnt], SELECT_BY_TICKET, MODE_TRADES) )   {
// EXIT MARKET [time exit if position is in loss]
         if(OrderType() == OP_BUY && f_hours_diff(OrderOpenTime(), Time[0]) > TE  && (Ask + SL*pips2dbl) < OrderOpenPrice()  )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore
                     break;
                  check = OrderClose(OrderTicket(),OrderLots(), Bid, 5, Violet); // close 1/2 position
                  TradeIsNotBusy();
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Ask, 5));
         }
         if(OrderType() == OP_SELL && f_hours_diff(OrderOpenTime(), Time[0]) > TE && (Bid + SL*pips2dbl) > OrderOpenPrice() )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore
                     break;
                  check = OrderClose(OrderTicket(),OrderLots(), Ask, 5, Violet); // close 1/2 position
                  TradeIsNotBusy();
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Bid, 5));
         }
// MODIFY ORDERS [if position in profit zone don't close, just trail SL agresivly]
         if(OrderType()== OP_BUY && (Ask - OrderOpenPrice()) > TP * pips2dbl ) {
            RefreshRates();
            if (cnt)
                StopLoss = NormalizeDouble(Ask - 10*pips2dbl, Digits);
            else
                StopLoss = NormalizeDouble(Ask - SL*pips2dbl, Digits);
            TakeProfit = OrderTakeProfit();
            if ( StopLoss > OrderStopLoss() + 5*pips2dbl ) {
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
            if (cnt)
                StopLoss = NormalizeDouble(Bid + 10*pips2dbl, Digits);
            else
                 StopLoss = NormalizeDouble(Bid + SL*pips2dbl, Digits);
            TakeProfit = OrderTakeProfit();
            if ( StopLoss < OrderStopLoss() + 5*pips2dbl )  {
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
      } //end while
    }//if NewDay
// MONEY MANAGEMENT
         Lots =  maxLots;
         cnt = f_OrdersTotal(magic_number_1, ticketArr) + 1;   //how many open lots?
         contracts = f_Money_Management() - cnt;               //how many possible?
// ENTER MARKET CONDITIONS
if( cnt < contracts )   { //if we are able to open new lots...
datetime expiration = StrToTime( "23:55" );
// check for long position (BUY) possibility
      if(LongBuy == true )      { // pozycja z sygnalu
         StopLoss = NormalizeDouble(Ask - f_initialStop_5(), Digits);
         TakeProfit = H;
   //--------Transaction        //Print (StopLoss," - ", price, " - ", TakeProfit);
         check = f_SendOrders(OP_BUY, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment); 
   //--------
         if(check == 0)         {
              AlertText = "BUY stop order placed : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
               + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Ask, 5) + ", L = " + DoubleToStr(L, 5);
         }  else { AlertText = "Error placing BUY stop order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", L = " + DoubleToStr(L, 5); }
         f_SendAlerts(AlertText);
      }
// check for short position (SELL) possibility
      if(ShortBuy == true )      { // pozycja z sygnalu
         StopLoss = NormalizeDouble(Bid + f_initialStop_5(), Digits);
         TakeProfit = L;
   //--------Transaction        //Print (TakeProfit, " - ", price, " - ", StopLoss);
         check = f_SendOrders(OP_SELL, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment); 
   //--------
         if(check == 0)         {
               AlertText = "SELL stop order placed : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
               + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Bid, 5) + ", H = " + DoubleToStr(H, 5);
         }  else { AlertText = "Error placing SELL stop order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Bid, 5) + ", H = " + DoubleToStr(H, 5); }
         f_SendAlerts(AlertText);
      }
    }
}// exit OnTick()
