#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


#include <Trade/trade.mqh>


//Inputs Variable
input group "------ Initial Setting ------";
input int Magic = 112233; //Magic Number
input ENUM_TIMEFRAMES Timeframe = PERIOD_M10;
input double LotSize = 0.01; //Lot Size

input group "------ ATR - 1 Setting ------";
input int AtrPeriod_1 = 14; //Enter ATR Period
input ENUM_TIMEFRAMES AtrTimeframe_1 = PERIOD_M10; //Enter ATR Timeframe

input group "------ ATR - 2 Setting ------";
input int AtrPeriod_2 = 14; //Enter ATR Period
input ENUM_TIMEFRAMES AtrTimeframe_2 = PERIOD_M10; //Enter ATR Timeframe

input group "------ MA - 1 Setting ------";
input int MaPeriod_1 = 14; //Enter MA  Period
input ENUM_TIMEFRAMES MaTimeframe_1 = PERIOD_M10; //Enter MA Timeframe
input ENUM_MA_METHOD MaMethod_1 = MODE_SMA; //Enter MA Method

input group "------ MA - 2 Setting ------";
input int MaPeriod_2 = 14; //Enter MA  Period
input ENUM_TIMEFRAMES MaTimeframe_2 = PERIOD_M10; //Enter MA Timeframe
input ENUM_MA_METHOD MaMethod_2 = MODE_EMA; //Enter MA Method

input group "------ Last Swing of Last N candle Setting ------";
input int LastNCandleCount = 14; // Enter Number of Candle 

 //Global Variables
int barsTotal = iBars(_Symbol, Timeframe);
CTrade trade;
int handlerAtr;
int handleMa;

double lowSwingLength[];
double highSwingLength[];



//--------------------------------------------------------------

int OnInit(){
   
   trade.SetExpertMagicNumber(Magic);
   return(INIT_SUCCEEDED);
}

//--------------------------------------------------------------

void OnDeinit(const int reason){
   IndicatorRelease(handlerAtr);
   IndicatorRelease(handleMa);
}

//--------------------------------------------------------------

void OnTick(){
   
   
   if(!hasOpenPosition(Magic)){
      
   }
   

   int bars= iBars(_Symbol, Timeframe);
   if(bars != barsTotal){
      barsTotal = bars;
      
      double currCandleHigh = iHigh(_Symbol, Timeframe, 0);
		double currCandleLow = iLow(_Symbol, Timeframe, 0);
		
		double prevCandleOpen = iOpen(_Symbol,Timeframe,1);
		double prevCandleClose = iClose(_Symbol,Timeframe,1);
		
		double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
		double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
		
		double atrValue_1 = getAtrValue(AtrTimeframe_1,AtrPeriod_1);
		double atrValue_2 = getAtrValue(AtrTimeframe_2,AtrPeriod_2);
		
		double ma_1 = getMAValue(MaMethod_1,MaPeriod_1,MaTimeframe_1,1,1);
		double ma_2 = getMAValue(MaMethod_2,MaPeriod_2,MaTimeframe_2,1,1);
		
		bool isLastCandleGreen = prevCandleOpen > prevCandleClose ? true : false;
		double lastCandleSize = prevCandleOpen - prevCandleClose;
		lastCandleSize = lastCandleSize > 0 ? lastCandleSize : lastCandleSize * -1;
		
		
		double lastHighSwing = highOfLastNCandle(LastNCandleCount,Timeframe);
		double lastHighSwingLength = lastHighSwing - askPrice;   
		double lastLowSwing = lowOfLastNCandle(LastNCandleCount,Timeframe);
		double lastLowSwingLength = bidPrice - lastLowSwing;
		   
		double halfCorrectionUptrend = askPrice + (lastLowSwingLength/2);
      double halfCorrectionDowntrend = bidPrice + (lastHighSwingLength/2);
      
      PushToArray(highSwingLength,halfCorrectionUptrend);
      PushToArray(lowSwingLength,halfCorrectionDowntrend);
      
      double sl = halfCorrectionUptrend - atrValue_1 * 5;
		double tp = halfCorrectionUptrend + atrValue_1*5;
      
      trade.BuyLimit(LotSize,sl,_Symbol,sl - atrValue_1,tp,ORDER_TIME_DAY,0,"Buy Limit Placed");
      trade.SellLimit(LotSize,tp,_Symbol,tp + atrValue_1,sl,ORDER_TIME_DAY,0,"Sell Limit Placed");
		
		
	}
}




//---------------------------------Functions------------------------------

// Function to push an element to the array
void PushToArray(double &arr[], double value)
{
    int size = ArraySize(arr);
    ArrayResize(arr, size + 1);  // Increase size by 1
    arr[size] = value;           // Assign value to the new element
}

double getAtrValue(ENUM_TIMEFRAMES atr_timeframe, int atr_prd, int shift=0, int count=1){
   handlerAtr = iATR(_Symbol, atr_timeframe,atr_prd);
   double atr[];
   CopyBuffer(handlerAtr,0,shift,count,atr);   
   return atr[0];
}

bool hasOpenPosition(int Magic_Number) {
	for(int i = 0; i < PositionsTotal(); i++) {
		if(PositionGetTicket(i)) { // Must call this to select the position
			string symbol = PositionGetString(POSITION_SYMBOL);
			long magic = PositionGetInteger(POSITION_MAGIC);
			if(symbol == _Symbol && magic == Magic_Number) return true;
		}
	}
	return false;
}

//| Convert Points to Price for Any Symbol                          
double pipsToPrice(string symbol, double pips) {
	if(symbol == NULL) symbol = Symbol();
	double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
	int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
	// Handle special cases
	// Metals typically use 0.01 as pip size (2 decimal places)
	if(StringFind(symbol, "XAU") != -1 || StringFind(symbol, "XAG") != -1) {
		if(digits == 2)
			//vPoint = 0.1;
			return NormalizeDouble(point * pips * 10, digits);
		else return NormalizeDouble(point * pips * 10 * 10, digits);
	}
	//handling 3 point jpy
	else
	if(digits == 3) {
		return NormalizeDouble(point * pips * 10, digits);
	}
	//Handling 2 pont Bitcoin
	else
	if(StringFind(symbol, "BTC") != -1) {
		return NormalizeDouble(point * pips * 10 * 100, digits);
	}
	// all other
	else {
		return NormalizeDouble(point * pips * 10, digits);
	}
	return NormalizeDouble(point * pips * 10, digits);
}

//Make a Buy order
void executeBuy(double lot, double entryPrice, double sl_Pips, double tp_Pips) {
	double slPipsPrice = pipsToPrice(_Symbol, sl_Pips);
	double tpPipsPrice = pipsToPrice(_Symbol, tp_Pips);
	double sl = entryPrice - slPipsPrice;
	double tp = entryPrice + tpPipsPrice;
	trade.Buy(lot, NULL, entryPrice, sl, tp, "Buy Order Placed");
}
//Make Sell order
void executeSell(double lot, double entryPrice, double sl_Pips, double tp_Pips) {
	double slPipsPrice = pipsToPrice(_Symbol, sl_Pips);
	double tpPipsPrice = pipsToPrice(_Symbol, tp_Pips);
	double sl = entryPrice + slPipsPrice;
	double tp = entryPrice - tpPipsPrice;
	trade.Sell(lot, NULL, entryPrice, sl, tp, "Sell Order Placed");
}



//Moving Average
double getMAValue(ENUM_MA_METHOD maType,int ma_period, ENUM_TIMEFRAMES ma_timeframe, int shift,int count){  //Calculate fast EMA value
   handleMa = iMA(_Symbol,ma_timeframe,ma_period,0,maType,PRICE_CLOSE);
   double ma[];
   CopyBuffer(handleMa,0,shift,count,ma);
   return NormalizeDouble(ma[0],_Digits);
}


//make a SL for long position, low of last n candle
double lowOfLastNCandle(int candleCount, ENUM_TIMEFRAMES timeframe)
  {
   double lowPrice[];
   CopyLow(_Symbol,timeframe,0,candleCount,lowPrice);
   int lowPriceIndex = ArrayMinimum(lowPrice);
   double low = lowPrice[lowPriceIndex];
   low = NormalizeDouble(low,_Digits);
   return low;
  }

//Make SL for Short Postion, High of last N candle
double highOfLastNCandle(int candleCount, ENUM_TIMEFRAMES timeframe)
  {
   double highPrice[];
   CopyHigh(_Symbol,timeframe,0,candleCount,highPrice);
   int highPriceIndex = ArrayMaximum(highPrice);
   double high = highPrice[highPriceIndex];
   high = NormalizeDouble(high, _Digits);
   return high;
  }