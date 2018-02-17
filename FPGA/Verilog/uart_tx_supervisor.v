/******************************************************************************************
Wrapper around the basic UART module to allow a string to be written in 1 go

Dan McGraw, dpm39, University of Cambridge
*******************************************************************************************/

module uart_tx_supervisor
(
	input			i_clock,
	input 			i_txBegin,
	input[111:0]	i_txData,
	input[7:0]		i_txDataLength,
	output reg		o_txBusy,
	output			o_txSerial,
	output reg		o_txDone
);

uart_tx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) UART_TX_INSTANCE
(
	.i_clock(i_clock),
	.i_txBegin(r_txBegin),
	.i_txData(r_uartTxData),
	.o_txBusy(w_txBusy),
	.o_txSerial(o_txSerial),
	.o_txDone(w_txDone)
);

parameter 		CLOCKS_PER_BIT = 10;


reg[111:0]			r_txData = 0;
reg					r_txBegin = 0;
reg[7:0]			r_byteCounter = 0;
reg[7:0]			r_uartTxData = 0;

wire				w_txBusy;
wire				w_txDone;

//State machine stuff
parameter			s_IDLE = 0;
parameter			s_SENDING = 1;
parameter			s_DONE = 2;
reg[1:0]			r_state = 0;

always @ (posedge i_clock)
begin
	case (r_state)
	
	s_IDLE:
	begin
		r_txBegin <= 0;
		o_txBusy <= 0;
		o_txDone <= 0;
		if(i_txBegin == 1)
		begin
			r_txData <= i_txData; //Store local copy of the data
			r_byteCounter <= i_txDataLength; 
			o_txBusy <= 1;
			r_state <= s_SENDING;
		end	
		else
			r_state <= s_IDLE;
	end //case s_IDLE
	
	s_SENDING:
	begin
		r_txBegin <= 0;
		if(w_txBusy == 1 || r_txBegin == 1) 
		//^This weirdness needed as w_txBusy is low for 2 cycles, 1 in s_IDLE, 1 in s_SENDING so was sending every other byte
			r_state <= s_SENDING;
		else
		begin
			if(r_byteCounter == 0)
				r_state <= s_DONE;
			else
			begin
				//Send next byte
				r_uartTxData <= r_txData[(r_byteCounter << 3) - 1 -: 8];
				r_txBegin <= 1;
				r_byteCounter <= r_byteCounter - 1;
			end
		end
	end// case s_SENDING
	
	s_DONE:
	begin
		r_txBegin <= 0;
		o_txDone <= 1;
		r_state <= s_IDLE;
	end //case s_DONE
	endcase
end
endmodule