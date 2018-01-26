/******************************************************************************************
Testbench for bitbanged UART transmitter

Send 0xCC followed by 0xDD in UART then terminates (absolute timing isn't correct)

Dan McGraw, dpm39, University of Cambridge
*******************************************************************************************/
`timescale 1ns / 1ps

module uart_tx_testbench();

reg 		r_clock=1'b0;
reg[7:0]	r_testData = 0;
reg			r_uartBegin = 0;

wire		w_txBusy;
wire		w_txDone;
wire		w_txSerial; //the actual UART pin


uart_tx UUT
(
	.i_clock(r_clock),
	.i_txBegin(r_uartBegin),
	.i_txData(r_testData[7:0]),
	.o_txBusy(w_txBusy),
	.o_txSerial(w_txSerial),
	.o_txDone(w_txDone)
	
);

always #1 r_clock <= !r_clock;

initial
//Note that a lot of things have to have stupid delays in as the testbench is clocked twice as fast as the UART module
//In the real thing, these will share a clock so most of that rubbish disappears
begin
	#2;
	r_testData[7:0] = 8'hCC;
	r_uartBegin = 1;
  	#2;
	r_uartBegin = 0;
	
  	while(w_txDone == 0)
   	begin
		#1;
    end
  
	r_testData[7:0] = 8'hDD;
	r_uartBegin = 1;
  	#4;
	r_uartBegin = 0;
  	while(w_txDone == 0)
    begin
		#1;
    end
  
  	$finish;

end
  
endmodule //uart_tx_testbench
