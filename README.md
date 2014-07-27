###Pin-pin 2.0
=======

New version of Pin-pin expert advisor [MQL]

####Input variables

* SL //StopLoss (in pips)
     in EXIT section for time exit [weird formula]
     in MODIFY section for less agressive trailing SL
* TP //TakeProfit (minimum profit level in pips)
     in MODIFY section. when position reaches this level above OpenPrice ea starts StopLoss trailing instead of exiting.
* TE //Time Exit(in hours)
     in EXIT section. when few hours passed and position is still not into the profit zone we exit.
* minPeriod = 5
* maxPeriod = 20
* Shift = 1
* K = 4 //filter in trading days
     in DISCOVER SIGNALS section. we look for lowest daily low in the past K days. it determines our entry level.
     in isRecentHigh()/isRecentLow() function. if HighestHigh(f_lookback) > HighestHigh(K) we determine recent High/Low

####Implicit variables CONSTANTS
* in ENTRY we set price to Hi/Lo +/- 5 pips
* in MODIFY we trail agresivvely by 10 pips
* in MODIFY we move SL by minimum step of 5 pips
* in f_lookBackDays we filter deltaVol by 0.028
* in f_initialStop_5 we take ATR for last 10 days
* expiration is set to "23:55" in ENTER MARKET

####Heuristics
* When market is trending (establishing new daily highs/lows in horizon modified by volatility) we are waiting for significant pullbacks hoping for quick and forcefull reverse of the market returning to the main trend.
* If however market continues correction we have either entered in the wrong moment [K is the main variable here] or worse the market reversed the trend. So we try minimizing our losses jumping out.
* If market cannot decide and wallows around our entry level it usually means that the risk of keeping the position increases and we exit with time exit.
* If market reversed after pullback and the position is profitable we protect our gains through trailing Stop Loss.
* We usually open two lots in the same direction closing first lot with relatively small gain (around 50 pips as rule of thumb) and giving the second lot a bit more space hoping for further gains.
* As the market could be quite volatile when reversing on a pullback first thing we do is trying to move SL to breakeven. It cuts out some prospects but takes a lot of negative emotions and risk out of equation.
