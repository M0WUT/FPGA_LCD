module spi
(
	//Clock
	input 			i_clock,
	
	//Tx
	input			i_txBegin,
	input[6:0]		i_txAddress,
	input[7:0]		i_txData,
	output			o_txBusy,
	output			o_txDone,
	
	//Rx
	input			i_rxBegin,
	input[6:0]		i_rxAddress,
	output reg[7:0]	o_rxData,
	output			o_rxBusy,
	output			o_rxDone,
	
	//IO (Named to match with HDP pin naming)
	input			i_sout, //MOSI
	output			o_sen, //CS (active low)
	output			o_sck, //SCK (data clocked on rising edge)
	output reg		o_sdat //MISO
);

reg[15:0]			r_txData;
reg[7:0]			r_rxAddress;
reg[7:0]			r_rxData;

///////////////////////
//State machine setup//
///////////////////////
parameter 	s_IDLE = 0;
parameter	s_TXSENDING = 1;
parameter 	s_TXDONE	= 2;
parameter 	s_RXSENDING = 3;
parameter 	s_RXRECEIVING = 4;
parameter	s_RXDONE = 5;

reg[2:0]	r_state = s_IDLE;

//Output flags
assign o_txBusy = (r_state > s_IDLE) && (r_state < s_RXSENDING);
assign o_txDone = (r_state == s_TXDONE);

assign o_rxBusy = (r_state > s_TXDONE);
assign o_rxDone = (r_state == s_RXDONE);

assign o_sen = (r_state != s_IDLE);
assign w_clockEnable = (r_state != s_IDLE);

/////////////////
//Clock Divider//
////////////////
parameter 	CLOCKS_PER_BIT = 30; //MUST BE EVEN
reg[7:0]	r_clockCounter = 0;
wire		w_clockEnable;

assign o_sck = (r_clockCounter > CLOCKS_PER_BIT[7:1]); //[7:1] is a divide by 2 in effect
//If clock is disabled or has overflowed, set r_clockCounter to 0. This also takes o_sck low which is its idle state

reg[3:0] r_bitCounter = 0;
always @(posedge i_clock) r_clockCounter <= w_clockEnable ? (r_clockCounter > CLOCKS_PER_BIT ? 0 : r_clockCounter + 1) : 0;	

always @(posedge i_clock)
begin
	case (r_state)
	
	s_IDLE:
	begin
		if(i_rxBegin)
		begin
			r_state <= s_RXSENDING;
			r_rxAddress <= {1'b0, i_rxAddress[6:0]};
			r_bitCounter <= 4'd7; //1 read bit plus 6 address bits
		end
		else if(i_txBegin)
		begin
			r_state <= s_TXSENDING;
			r_txData <= {1'b0, i_txAddress[6:0], i_txData[7:0]}; //concatenate start bit, address and data
			r_bitCounter <= 4'd15; //16 bits in total (15:0)
		end
		else r_state <= s_IDLE;
	end //case s_IDLE
	
	s_TXSENDING:
	begin
		o_sdat <= r_txData[r_bitCounter];
		if(r_clockCounter == 0)
		begin
			if(r_bitCounter == 0)
				r_state <= s_TXDONE;
			else
				r_bitCounter <= r_bitCounter - 1;
		end
	end //case s_TXSTARTBIT
	
	s_TXDONE:
	begin
		r_state <= s_IDLE; //Provides delay of 1 clock cycle for o_txDone signal
	end //case s_TXDONE;
	
	s_RXSENDING:
	begin
		o_sdat <= r_rxAddress[r_bitCounter];
		if(r_clockCounter == 0)
		begin
			if(r_bitCounter == 0)
			begin
				r_bitCounter <= 4'd7;
				r_state <= s_RXRECEIVING;
			end
			else
				r_bitCounter <= r_bitCounter - 1;
		end
	end //case s_RXSENDING
	
	s_RXRECEIVING:
	begin
		if(r_clockCounter == CLOCKS_PER_BIT[7:1]) //We are at rising edge of serial clock
		begin
			r_rxData[r_bitCounter] <= i_sout;
		end
		
		else if(r_clockCounter == 0)
		begin
			if(r_bitCounter == 0)
			begin
				r_state <= s_RXDONE;
				o_rxData <= r_rxData;
			end
			else
				r_bitCounter <= r_bitCounter - 1;
		end
	
	end //case s_RXRECEIVING
	
	
	s_RXDONE:
	begin
		r_state <= s_IDLE; //1 clock delay for rx done flag to be set
	end
	endcase
end






endmodule //spi