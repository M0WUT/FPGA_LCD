module FPGA_LCD_top
(
	//Master clock
	input			i_clock50,
	
	//SPI input
	input			i_hSync,
	input 			i_mosi,
	input			i_sck,
	input 			i_vSync,
		
		
	//HDP Output,
	output reg[31:0]o_lcdData,
	output			o_valid,
	output			o_sync,
	output			o_nReset,
	output			o_update,
	output			o_invert,
	output			o_lcdClock,
	
	//SPI
	output			o_sen,
	output			o_sck,
	output			o_sdat,
	input			i_sout,
	
	//Debug
	output			o_active,
	input			i_shutdown,
	output reg[7:0]	o_debug

);

//Direct drive or use PLL
parameter CLOCK_SPEED = 50; //Clock speed in MHz


reg		r_commSetup = 0;
reg		r_commActivate = 0;
reg		r_commShutdown = 0;
wire	w_commDone;


comms_master #(.CLOCK_SPEED(CLOCK_SPEED)) COMMS_MASTER_INST
(
	//Clock
	.i_clock(i_clock50),
	
	//Control signals
	.i_setup(r_commSetup),
	.i_activate(r_commActivate),
	.i_shutdown(r_commShutdown),
	
	//SPI (Named to match with HDP pin naming)
	.i_sout(i_sout), //MOSI 
	.o_sen(o_sen), //CS (active low)
	.o_sck(o_sck), //SCK (data clocked on rising edge)
	.o_sdat(o_sdat), //MISO
	
	//UART
	//.i_uartRx(i_uartRx),  //DEBUG
	//.o_uartTx(o_uartTx), //DEBUG
	
	//Done flag
	.o_done(w_commDone)


);


//Used to gate the clock to the HDP
assign		w_active = (r_state == s_NORMAL);
assign 		o_nReset = ((r_state != s_START) && (r_state != s_SHUTDOWN));
assign 		o_lcdClock = (i_clock50 && o_nReset); //Clock is only active when reset is high
assign 		o_active = w_active;
assign 		o_valid = (w_active && (r_linePacketCounter < 40));
assign		o_update = (w_active && (r_packetCounter < 28));
assign 		o_invert = 0; //DEBUG
assign		o_sync = 0;

parameter   s_START = 0;
parameter 	s_RESET = 1;
parameter	s_SETUP = 2;
parameter	s_STANDBY = 3;
parameter 	s_TRANSISTION_STANDBY_NORMAL = 4;
parameter 	s_NORMAL = 5;
parameter	s_TRANSISTION_NORMAL_SLEEP = 6;
parameter 	s_SLEEP = 7;
parameter 	s_SHUTDOWN = 8;
reg[7:0]	r_state = s_START;

reg[31:0]	r_clockCounter = 0; //Used to count clock pulses for delays
reg[31:0]	r_packetCounter = 0; //Total number of packets sent
reg[31:0]	r_linePacketCounter = 0; //Used to indicate where we are within a line (1280/32 = 40 packets per line)
reg[31:0]	r_lineCounter = 0; //What line we are on
parameter DATA_END = (44 * 1280); //44 clocks per line(40 valid and 4 blank) * 1280 lines
parameter FRAME_END = DATA_END + 24; //Back porch of 24 clock at the end


reg[7:0]	r_spiBitCounter = 0;
reg[7:0]	r_spiWordCounter = 0;
reg			r_bufferNumber = 0;
reg			r_bufferZeroReady = 0;
reg			r_bufferOneReady = 0;
reg[31:0] 	r_bufferZero [40:0]; //4 lines per buffer (Needed a number that nicely divides 1280)
reg[31:0] 	r_bufferOne [40:0];
reg[31:0]	r_temp = 0;

always @(posedge i_sck)
begin
	o_debug[1] <= r_bufferZeroReady;
	o_debug[2] <= r_bufferOneReady;

	
	r_bufferZeroReady <= 0;
	r_bufferOneReady <= 0;
	
	r_temp[r_spiBitCounter] <= i_mosi;
	
	if(r_spiBitCounter == 31) //Have completed a word
	begin
		r_spiBitCounter <= 0;
		if(r_bufferNumber == 0)
			r_bufferZero[r_spiWordCounter] <= r_temp;
		else
			r_bufferOne[r_spiWordCounter] <= r_temp;
			
		if(r_spiWordCounter == 39) //40 words in a line
		begin
			r_spiWordCounter <= 0;
			r_bufferNumber <= ~r_bufferNumber;
			if(r_bufferNumber == 0)
				r_bufferZeroReady <= 1;	
			else
				r_bufferOneReady <= 1;
		end
		else
			r_spiWordCounter <= r_spiWordCounter + 1;
	end
	else
		r_spiBitCounter <= r_spiBitCounter + 1;
	
	
end

always @(posedge i_hSync) o_debug[0] <= (r_spiBitCounter == 0);

reg r_bufferZeroSending = 0;
reg r_bufferOneSending = 0;
reg	r_sendingBuffer = 0;

always @(negedge i_clock50)
begin
	o_debug[3] <= r_sendingBuffer;
	o_debug[4] <= r_bufferZeroSending;
	
	case (r_state)
	
	s_START:
	begin
		if(r_clockCounter > 30) //Hold Device in reset, datasheet specs minimum of 100ns, at max clock speed (140MHz), this is 14 clocks
		begin
			r_clockCounter <= 0;
			r_state <= s_RESET;
		end
		else
			r_clockCounter <= r_clockCounter + 1;
			
	end //case s_START
	
	s_RESET:
	begin
		if(r_clockCounter > 1000000) //Datasheet specs 960000 minimum
		begin
			//Serial Interface can now be used, start SETUP mode 
			r_clockCounter <= 0;
			r_commSetup <= 1;
			r_state <= s_SETUP;
		end
		else
			r_clockCounter <= r_clockCounter + 1;
	end //case s_RESET
	
	s_SETUP:
	begin
		
		if(w_commDone == 1)
		begin
			r_commSetup <= 0;
			r_clockCounter <= 0;
			r_state <= s_STANDBY;
		end
		else	
		begin
			r_commSetup <= 1;
			r_state <= s_SETUP;
		end
	end //case s_SETUP
	
	s_STANDBY:
	begin
		if(r_clockCounter > 1000000) //Datasheet specs 960000 minimum
		begin
			r_commActivate <= 1;
			r_state <= s_TRANSISTION_STANDBY_NORMAL;
			r_clockCounter <= 0;
		end
		else
			r_clockCounter <= r_clockCounter + 1;
	end //case s_STANDBY
	
	s_TRANSISTION_STANDBY_NORMAL:
	begin
		r_commActivate <= 0;
		if(w_commDone == 1)
			r_state <= s_NORMAL;
		else
			r_state <= s_TRANSISTION_STANDBY_NORMAL;
	end //case s_TRANSISTION_STANDBY_NORMAL
	
	s_NORMAL:
	begin
		
		if(r_packetCounter > (DATA_END-1))
		begin
			//In the back porch
			r_packetCounter <= r_packetCounter + 1;
			if(r_packetCounter == (FRAME_END - 1)) //minus 1 because of zero indexing
			begin
				r_packetCounter <= 0;
				r_linePacketCounter <= 0;
				r_lineCounter <= 0;
			end
		end
		else
		begin
			if(r_sendingBuffer == 0) //We are sending buffer 0 /waiting for buffer 1 ready
			begin
				r_bufferZeroSending <= 1;
				if(r_linePacketCounter == 44) //Have reached end of line
				begin
					r_bufferZeroSending <= 0;
					if(r_bufferOneReady == 1) //Wait for buffer 1 to be ready
					begin
						r_lineCounter <= r_lineCounter + 1;
						r_sendingBuffer <= 1;
						r_linePacketCounter <= 0;
					end
				end
				else
				begin
					if(r_linePacketCounter > 39) //4 pulses with 'Valid' Low
					begin
						o_lcdData <= 32'h0;
						r_linePacketCounter <= r_linePacketCounter + 1;
						r_packetCounter <= r_packetCounter + 1;
					end
					else //Sending image data
					begin
						o_lcdData <= r_bufferZero[r_linePacketCounter];
						r_linePacketCounter <= r_linePacketCounter + 1;
						r_packetCounter <= r_packetCounter + 1;
					end
				end
			end
			else //Sending from Buffer 1
			begin
				r_bufferOneSending <= 1;
				if(r_linePacketCounter == 44) //Have reached end of line
				begin
					r_bufferOneSending <= 0;
					if(r_bufferZeroReady == 1) //Wait for buffer 1 to be ready
					begin
						r_lineCounter <= r_lineCounter + 1;
						r_sendingBuffer <= 0;
						r_linePacketCounter <= 0;
					end
				end
				else 
				begin
					if(r_linePacketCounter > 39) //4 pulses with 'Valid' Low
					begin
						o_lcdData <= 32'h0;
						r_linePacketCounter <= r_linePacketCounter + 1;
						r_packetCounter <= r_packetCounter + 1;
					end
					else //Sending image data
					begin
						o_lcdData <= r_bufferOne[r_linePacketCounter];
						r_linePacketCounter <= r_linePacketCounter + 1;
						r_packetCounter <= r_packetCounter + 1;
					end
				end
			
			end
			
			
		end
		

		//Code for shutdown button
		if(i_shutdown == 0)
		begin
			r_commShutdown <= 1;
			r_state <= s_TRANSISTION_NORMAL_SLEEP;
		end
	end //case s_NORMAL
	
	s_TRANSISTION_NORMAL_SLEEP:
	begin
		r_commShutdown <= 0;
		if(w_commDone == 1)
		begin
			r_state <= s_SLEEP;
			r_clockCounter <= 0;
		end
		else	
			r_state <= s_TRANSISTION_NORMAL_SLEEP;
	end //case s_TRANSISTION_NORMAL_SLEEP
	
	s_SLEEP:
	begin
		if(r_clockCounter > (CLOCK_SPEED * 1000000))
			r_state <= s_SHUTDOWN;
		else
			r_clockCounter <= r_clockCounter + 1;
	end //case s_SLEEP
	
	s_SHUTDOWN:
	begin
	end // case s_SHUTDOWN
	
	endcase
	
end

endmodule