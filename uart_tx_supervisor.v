module uart_tx_supervisor
(
	input				i_clock,
	input 			i_txBegin,
	input[87:0]		i_txData,
	input[7:0]		i_txDataLength,
	output reg		o_txBusy,
	output			o_txSerial,
	output reg		o_txDone
);

uart_tx UART_TX_INSTANCE
(
	.i_clock(i_clock),
	.i_txBegin(r_txBegin),
	.i_txData(r_uartTxData),
	.o_txBusy(w_txBusy),
	.o_txSerial(o_txSerial),
	.o_txDone(w_txDone)
);

reg[87:0]		r_txData = 0;
reg				r_txBegin = 0;
reg[7:0]			r_byteCounter = 0;
reg[7:0]			r_uartTxData = 0;

//State machine stuff
parameter		s_IDLE = 0;
parameter		s_SENDING = 1;
parameter		s_DONE = 2;
reg[1:0]			r_state = 0;

always @ (posedge i_clock)
begin
	case (r_state)
	
	s_IDLE:
	begin
		o_txBusy <= 0;
		o_txDone <= 0;
		if(i_txBegin == 1)
		begin
			r_txData <= i_txData;
			r_byteCounter <= i_txDataLength;
			r_uartTxData <= i_txData[7:0];
			o_txBusy <= 1;
			r_txBegin <= 1;
			r_state <= s_SENDING;
		end	
		else
			r_state <= s_IDLE;
	end //case s_IDLE
	
	s_SENDING:
	begin
		r_txBegin <= 0;
		if(w_txDone == 1)
		begin
			//We have sent all the data
			r_state <= s_DONE;
		end
		else
			r_state <= s_SENDING;
	end// case s_SENDING
	
	s_DONE:
	begin
		o_txDone <= 1;
		r_state <= s_IDLE;
	end //case s_DONE
	endcase
end
endmodule