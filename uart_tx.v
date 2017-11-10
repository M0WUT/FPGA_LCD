module uart_tx
(
	input				i_clock,
	input 			i_txDV,
	input[7:0]		i_txData,
	output reg		o_txBusy,
	output reg		o_txSerial,
	output reg		o_txDone
);


parameter CLOCKS_PER_BIT = 104; //i_clock frequency / baudrate. Currently for 8MHz clock and 9600 buad

//states for the state machine
parameter 	s_IDLE = 0;
parameter	s_STARTBIT = 1;
parameter 	s_DATABITS = 2;
parameter 	s_STOPBIT 	= 3;
parameter 	s_CLEANUP	= 4;

reg[3:0]		r_bitCounter = 0; //which bit we're currently sending
reg[7:0]		r_txData = 0; //copy txData to this in case i_txData gets altered during sending
reg[2:0]		r_state = s_IDLE; 
reg [15:0] 	r_clockCounter = 0;


always @ (posedge i_clock)
begin
	case (r_state)
		s_IDLE:
		begin
			r_bitCounter <= 0;
			r_clockCounter <= 0;
			o_txDone <= 0;
			o_txSerial <= 1;
			if(i_txDV == 1) //we have valid data to start sending
			begin
				o_txBusy <= 1;
				r_state <= s_STARTBIT;
				r_txData <= i_txData; //copy input data to local copy in case it's edited externally
			end
			else
				r_state <= s_IDLE;
		end //case s_IDLE
		
		s_STARTBIT:
		begin
			o_txSerial <= 0;
			if(r_clockCounter == CLOCKS_PER_BIT)
			begin
				r_state <= s_DATABITS;
				r_clockCounter <= 0;
			end
			else
			begin
				r_state <= s_STARTBIT;
				r_clockCounter <= r_clockCounter + 1;
			end
		end //case s_STARTBIT
		
		s_DATABITS:
		begin
			o_txSerial <= r_txData[r_bitCounter];
			if(r_clockCounter < CLOCKS_PER_BIT)
			begin
				//Wait until time for next bit
				r_state <= s_DATABITS;
				r_clockCounter <= r_clockCounter + 1;
			end
			else
			begin
				//we are done sending current bit
				if(r_bitCounter < 7)
				begin
					//send next bit
					r_bitCounter <= r_bitCounter + 1;
					r_clockCounter <= 0;
				end
				else
				begin
					//we have sent all our data
					r_state <= s_STOPBIT;
					r_clockCounter <= 0;
				end
			end			
		end //case s_DATABITS
		
		s_STOPBIT:
		begin
			o_txSerial <= 1; //Stop bit for UART is a 1
			if(r_clockCounter < CLOCKS_PER_BIT)
			begin
				r_state <= s_STOPBIT;
				r_clockCounter <= r_clockCounter + 1;
			end
			else
			begin
				r_state <= s_CLEANUP;
				r_clockCounter <= 0;
			end
		end //case s_STOPBIT
		
		s_CLEANUP:
		begin
			o_txDone <= 1; //set txDone high for 1 clock cycle
			r_state <= s_IDLE;
		end //case s_CLEANUP
		
	endcase
end 	

endmodule