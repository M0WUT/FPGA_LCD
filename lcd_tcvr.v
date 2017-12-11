module lcd_tcvr
(
	input				i_clock,
	input 			i_txBegin,
	input				i_rxBegin,
	input				i_rxSerial,
	input[6:0]		i_address,
	input[7:0]		i_txData,
	output			o_clock,
	output reg		o_serialEnable,
	output reg		o_txBusy,
	output reg		o_rxBusy,
	output reg 		o_txSerial,
	output reg[7:0]o_rxData,
	output  			o_txDone,
	output 			o_rxDone
);

parameter CLOCKS_PER_BIT = 1; //i_clock frequency / 4*serial_clock_frequency (max 2MHz)

//states for the state machine (who needs enums?)
parameter 	s_IDLE = 0;
parameter	s_TXSTARTBIT = 1;
parameter 	s_TXADDRESS = 2;
parameter	s_TXDATA = 3;
parameter 	s_TXSTOPBIT = 4;
parameter 	s_TXCLEANUP	= 5;
parameter 	s_RXSTARTBIT = 6;
parameter 	s_RXADDRESS = 7;
parameter	s_RXDATA = 8;
parameter	s_RXCLEANUP = 9;
parameter 	s_RXWAIT = 10; 

reg[3:0]		r_bitCounter = 0; //which bit we're currently sending
reg[7:0]		r_address = 0; //save address to local copy in case the master changes during an operation
reg[7:0]		r_txData = 0;
reg[7:0]		r_rxData = 0;
reg[3:0]		r_state = s_IDLE; 
reg			r_clockEnable = 0; //clock is always running, determines whether routed to output pin
reg[15:0]	r_clockCounter = 0;
reg			r_serialClock = 0;
reg			r_txBegin = 0;
reg			r_rxBegin = 0;
reg			r_doneDisable = 0;
reg			r_txDone = 0;
reg			r_rxDone = 0;
reg[7:0]		r_rxBitCounter = 0;

assign o_clock = (r_clockEnable == 1) ? r_serialClock : 0;
assign o_txDone = (r_doneDisable == 1) ? r_txDone : 0;
assign o_rxDone = (r_doneDisable == 1) ? r_rxDone : 0;

always @ (posedge i_clock)
begin
	//Generate new clock for serial output
	if(r_clockCounter < CLOCKS_PER_BIT)
		r_clockCounter <= r_clockCounter + 1;	
	else
	begin
		r_clockCounter <= 0;
		r_serialClock <= ~ r_serialClock;
	end
	
	//pass begin signals through to slower clock domain
	if(r_state == s_IDLE)
	begin
		r_doneDisable <= 0;
		if(~r_txBegin)
			o_txBusy <= 0;
		if(~r_rxBegin)
			o_rxBusy <= 0;
		
		if(i_txBegin == 1)
		begin
			r_txBegin <= 1;
			o_txBusy <= 1;
		end
		else if(i_rxBegin == 1)
		begin
			r_rxBegin <= 1;
			o_rxBusy <= 1;
		end
	end	
	
	//Pass done bits back to fast clock domain once complete
	else if(r_state == s_TXCLEANUP || r_state == s_RXCLEANUP)
		r_doneDisable <= 1;
		
	//Clear Start bits once running
	else
	begin
		r_txBegin <= 0;
		r_rxBegin <= 0;
	end
	
end


always @ (negedge r_serialClock)
begin
	
	case (r_state)

		s_IDLE:
		begin
			o_txSerial <= 0;
			r_txDone <= 0;
			r_rxDone <= 0;
			o_serialEnable <= 1; //Active low
			r_clockEnable <= 0;
			if(r_txBegin == 1)
			begin
				//Start transmitting
				o_serialEnable <= 0;
				r_address <= i_address;
				r_txData <= i_txData;
				r_state <= s_TXSTARTBIT;
			end
			if(r_rxBegin == 1)
			begin
				//Request a byte
				o_serialEnable <= 0;
				r_address <= i_address;
				r_state <= s_RXSTARTBIT;
			end
			else
				r_state <= s_IDLE;
		end //case s_IDLE
		
		s_TXSTARTBIT:
		begin
			o_txSerial <= 0; //Transmits have a start bit of 0
			r_state <= s_TXADDRESS;	
			r_clockEnable <= 1;
			r_bitCounter <= 6; //7 Address bit so 6 is index of MSB
		end //case s_TXSTARTBIT
		
		s_TXADDRESS:
		begin
			o_txSerial <= r_address[r_bitCounter];
			r_bitCounter <= r_bitCounter - 1;
			if(r_bitCounter == 0)
			begin
				r_bitCounter <= 7; //8 Data bits
				r_state <= s_TXDATA;
			end
		end //case s_TXADDRESS
		
		s_TXDATA:
		begin
			o_txSerial <= r_txData[r_bitCounter];
			r_bitCounter <= r_bitCounter - 1;
			if(r_bitCounter == 0)
				r_state <= s_TXCLEANUP;
		end //case s_TXDATA
		
		s_TXCLEANUP:
		begin
			o_txSerial <= 0;
			r_txDone <= 1;
			o_serialEnable <= 1;
			r_clockEnable <= 0;
			r_state <= s_IDLE;
		end //case s_TXCLEANUP
		
		s_RXSTARTBIT:
		begin
			o_txSerial <= 1; //Transmits have a start bit of 0
			r_state <= s_RXADDRESS;	
			r_clockEnable <= 1;
			r_bitCounter <= 6; //7 Address bit so 6 is index of MSB
		end //case s_RXSTARTBIT
		
		s_RXADDRESS:
		begin
			o_txSerial <= r_address[r_bitCounter];
			r_bitCounter <= r_bitCounter - 1;
			if(r_bitCounter == 0)
			begin
				r_state <= s_RXDATA;
				r_bitCounter <= 7;

				//r_rxData <= 0; //Clear RX Buffer
			end
		end //case s_RXADDRESS
		
	
		s_RXDATA:
		begin
			o_txSerial <= 0;
			r_bitCounter <= r_bitCounter - 1;
			if(r_bitCounter == 0)
				r_state <= s_RXCLEANUP;
		end //case s_RXDATA
		
		s_RXCLEANUP:
		begin
			o_rxData <= r_rxData;
			r_rxDone <= 1;
			o_serialEnable <= 1;
			r_clockEnable <= 0;
			r_state <= s_IDLE;
		end //case s_RXCLEANUP
			
	endcase
		
end 	

always @ (posedge r_serialClock)
begin
	
	if(r_state != s_IDLE)
	begin
		//We are doing receiver things
		r_rxBitCounter <= r_rxBitCounter + 1;
		if(r_rxBitCounter > 7)
		begin
			//We are now listening to data
			r_rxData[16-r_rxBitCounter] <= i_rxSerial;
		end
		
	end
	if(r_state == s_RXSTARTBIT)
		r_rxBitCounter <= 1;
end



endmodule