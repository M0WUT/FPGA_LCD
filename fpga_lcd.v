module fpga_lcd
(
	 input 				clock_50, //Input from onboard crystal
	 
	 //LCD stuff
	 output reg[31:0]	data_out,
	 output 				o_lcdClock,
	 output reg			update,
	 //sync,
	 output reg			valid,
	 output reg			invert,
	 output reg			o_nreset,
	 
	 //LCD Serial Interface (looks like SPI)
	 input				i_lcdRxSerial,
	 output 				o_lcdSerialClock,
	 output				o_lcdTxSerial,
	 output				o_lcdSerialEnable,
	 
	 //Debug stuff
	 output reg[7:0]	led, //Onboard 8 LEDs
	 output				o_uartTxSerial

	 
);


	pll_1M u1 	//Change type to get different clocks speeds, currently implemented pll_1M, pll_4M, pll_8M, pll_140M
	(
		.inclk0(clock_50),
		.c0(w_pllOutput)
	);
	
	uart_tx UART_TX_INSTANCE
	(
		.i_clock(w_pllOutput),
		.i_txDV(r_uartTxDV),
		.i_txData(r_uartTxData),
		.o_txSerial(o_uartTxSerial),
		.o_txBusy(),
		.o_txDone(w_uartTxDone)
	);
	
	lcd_tcvr LCD_TCVR_INSTANCE
	(
		.i_clock(w_pllOutput),
		.i_txBegin(r_lcdTxBegin),
		.i_rxBegin(r_lcdRxBegin),
		.i_address(r_lcdAddress),
		.i_txData(r_lcdTxData),
		.i_rxSerial(r_lcdRxSerial),
		.o_clock(o_lcdSerialClock),
		.o_txSerial(o_lcdTxSerial),
		.o_serialEnable(o_lcdSerialEnable),
		.o_txDone(w_lcdTxDone),
		.o_rxDone(w_lcdRxDone)
	);
	
	//UART TX related stuff
	reg[7:0]		r_uartTxData = 0;
	reg			r_uartTxDV = 0;
	wire 			w_uartTxDone;
	reg			r_started = 0;
	reg[3:0]		r_byteCounter = 0;
	
	
	//LCD Serial related stuff
	reg			r_clockEnable = 0; //Clock should not be present while device is in reset state
	wire			w_pllOutput;
	reg			r_lcdTxBegin = 0;
	reg[6:0]		r_lcdAddress = 0;
	reg[7:0]		r_lcdTxData = 0;
	wire			w_lcdTxDone;
	reg			r_lcdRxBegin = 0;
	reg[7:0]		r_lcdRxData = 0;
	wire			w_lcdRxDone;
	
	//LCD related stuff
	reg inverted_frame; //Must send frame then inverse to maintain DC balance, 1 if sending inverted frame
	reg[24:0] led_counter = 0;
	reg[16:0] line_counter = 0;
	reg[31:0] frame_pixel_counter=0;
	reg[31:0] line_pixel_counter = 0;
	
	//State machine related stuff
	parameter   s_START = 0;
	parameter 	s_RESET = 1;
	parameter	s_STANDBY = 2;
	parameter 	s_NORMAL = 3;
	parameter 	s_SLEEP = 4;
	parameter 	s_SHUTDOWN = 5;
	reg[3:0]		r_state = s_START;
	
	//General counter
	reg[31:0]	r_clockCounter = 0;
	
	parameter[31:0] DATA_END = 1280 * 44; //1280 lines, each with 44 clocks
	parameter[31:0] FRAME_END = DATA_END + 24; //Invert must be set in correct state for 24 clocks before updated is asserted (at start of next frame)
	
assign o_lcdClock = r_clockEnable ? w_pllOutput : 0;


always @ (negedge w_pllOutput) //main LCD writing routine
begin
	case(r_state)
	
		s_START:
		begin
			o_nreset <= 0;
			r_clockEnable <= 0; 
			if(r_clockCounter < 20) //Datasheet specs minimum of 100ns, at max clock speed (140MHz), this is 14 clocks
				r_clockCounter <= r_clockCounter + 1;
			else
			begin
				r_clockCounter <= 0;
				r_state <= s_RESET;
			end
		end //case s_START
		
		s_RESET:
		begin
			o_nreset <= 1;
			r_clockEnable <= 1;
			if(r_clockCounter < 970000) //Datasheet specs 960000 minimum
				r_clockCounter <= r_clockCounter + 1;
			else
			begin
				//Serial Interface can now be used, get device ID to test communications
				
			end
		end //case s_RESET
		s_NORMAL:
		begin
			r_clockEnable <= 1;
			frame_pixel_counter <= frame_pixel_counter + 1;	
			update <= (frame_pixel_counter < 48) ? 1 : 0; //update must be high for first 48 clock pulses
			
			if (((frame_pixel_counter >= DATA_END) && inverted_frame) || ((frame_pixel_counter < 72) && ~inverted_frame))
			begin
				invert <= 1;
			end
			else
			begin
				invert <= 0;
			end
				
			if (frame_pixel_counter < DATA_END)
			begin
				//We are sending data
				line_pixel_counter <= line_pixel_counter + 1;
				if(line_pixel_counter < 40) //40 lots of data in 1 line
				begin
					if(inverted_frame)
					begin
						valid <= 0;
						data_out[31:0] <= 0;
					end
					else
					begin
						valid <= 1;
								
						///////////////////////////////////////////
						//This bit is where valid data is written//
						///////////////////////////////////////////
									
						//data_out[31:0] = line_pixel_counter; //Replace this bit with valid data
						if((line_pixel_counter > 10 && line_pixel_counter < 30) || (line_counter > 320 && line_counter < 960))
							data_out[31:0] <= 32'hFFFFFFFF;
						else
							data_out[31:0] <= 32'h00000000;	
					end
				end
				else
				begin
					//Last 4 clocks of each line must have valid set to low
					valid <= 0;
					data_out[31:0] <= 0;
				end
					
				if(line_pixel_counter == 43) //Words 0 - 43 have been sent so reset
				begin
					line_pixel_counter <= 0;
					line_counter <= line_counter + 1;
				end
			end
			else //We are in the back porch, send 24 clocks with invert set to value for this frame 
			begin
				valid <= 0;
				data_out[31:0] <= 0;
				if(frame_pixel_counter == FRAME_END - 1) //minus 1 because of parallel magic
				begin
					frame_pixel_counter <= 0;
					line_pixel_counter <= 0;
					line_counter <= 0;
					inverted_frame <= ~inverted_frame;
				end
			end
		end //case s_NORMAL
	endcase

end //of main loop	
	
	
always @ (negedge w_pllOutput)
	begin
		led_counter <= led_counter + 1;
		led[7:0] <= led_counter[24:17]; //Just used to indicate program is running
	end
	
endmodule