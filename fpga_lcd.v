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
	 output reg[5:0]	led, //6 LEDS on breakout board
	 output				o_uartTxSerial

	 
);


	pll_1M u1 	//Change type to get different clocks speeds, currently implemented pll_1M, pll_4M, pll_8M, pll_140M
	(
		.inclk0(clock_50),
		.c0(w_pllOutput)
	);
	
	uart_tx_supervisor UART_TRANSMITTER_INSTANCE
	(
		.i_clock(w_pllOutput),
		.i_txBegin(r_uartTxBegin),
		.i_txData(r_uartTxData),
		.i_txDataLength(r_uartTxDataLength),
		.o_txSerial(o_uartTxSerial),
		.o_txBusy(w_uartTxBusy),
		.o_txDone(w_uartTxDone)
	);
	
	lcd_tcvr LCD_TCVR_INSTANCE
	(
		.i_clock(w_pllOutput),
		.i_txBegin(r_lcdTxBegin),
		.i_rxBegin(r_lcdRxBegin),
		.i_address(r_lcdAddress),
		.i_txData(r_lcdTxData),
		.i_rxSerial(i_lcdRxSerial),
		.o_clock(o_lcdSerialClock),
		.o_txSerial(o_lcdTxSerial),
		.o_serialEnable(o_lcdSerialEnable),
		.o_txDone(w_lcdTxDone),
		.o_rxBusy(w_lcdRxBusy),
		.o_rxDone(w_lcdRxDone),
		.o_rxData(w_lcdRxData)
	);
	
	//UART TX related stuff
	reg[111:0]	r_uartTxData = 0;
	reg[7:0]		r_uartTxDataLength = 1;
	reg			r_uartTxBegin = 0;
	wire 			w_uartTxDone;
	wire			w_uartTxBusy;
	
	
	//LCD Serial related stuff
	reg			r_clockEnable = 0; //Clock should not be present while device is in reset state
	wire			w_pllOutput;
	reg			r_lcdTxBegin = 0;
	reg[6:0]		r_lcdAddress = 0;
	reg[7:0]		r_lcdTxData = 0;
	wire			w_lcdTxDone;
	reg			r_lcdRxBegin = 0;
	wire[7:0]	w_lcdRxData;
	wire			w_lcdRxDone;
	wire			w_lcdRxBusy;
	
	//LCD related stuff
	reg inverted_frame; //Must send frame then inverse to maintain DC balance, 1 if sending inverted frame
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
	parameter 	s_SETUP = 6;
	reg[3:0]		r_state = s_START;
	
	//General counter
	reg[31:0]	r_clockCounter = 0;
	
	//Setup Stuff
	reg[15:0]	r_setupState = 0;
	reg[23:0]	r_deviceID = 0;
	reg[1:0]		r_IDByteCounter = 0;
	
	parameter 	s_SETUP_START = 0;
	parameter 	s_SETUP_CONFIG_REQUEST = 1;
	parameter 	s_SETUP_CONFIG_RECEIVED = 2;
	parameter 	s_SETUP_CONFIG_UART_WAITING = 3;
	parameter 	s_DETECTION_FAILED = 4;
	parameter 	s_SETUP_ID_REQUEST = 5;
	parameter 	s_SETUP_ID_RECEIVED = 6;
	parameter 	s_SETUP_ID_UART_WAITING = 7;
	
	
	
	
	
	//Debug stuff
	reg[22:0]  	led_counter = 0;
	
	//Register addresses within the LCD
	parameter 	HW_CONFIG_ADDRESS = 'h78;
	parameter	HW_ID_ADDRESS_BASE = 'h79;
	
	
	parameter DATA_END = 1280 * 44; //1280 lines, each with 44 clocks
	parameter FRAME_END = DATA_END + 24; //Invert must be set in correct state for 24 clocks before updated is asserted (at start of next frame)
	
assign o_lcdClock = r_clockEnable ? w_pllOutput : 0;



always @ (negedge w_pllOutput) //main LCD writing routine
begin
	data_out[0] <= w_uartTxBusy;
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
				//Serial Interface can now be used, start DEBUG mode (for now)
				r_clockCounter <= 0;
				r_state <= s_SETUP;
				
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
		
		s_SETUP:
		begin

			case(r_setupState)
				s_SETUP_START:
				begin
					r_lcdAddress <= HW_CONFIG_ADDRESS;
					r_lcdRxBegin <= 1;
					r_setupState <= 1;
				end //case s_SETUP_START
				
				s_SETUP_CONFIG_REQUEST:
				begin
					r_lcdRxBegin <= 0;
					if(w_lcdRxDone == 1)
						r_setupState <= 2;
				end //case s_SETUP_CONFIG_REQUEST
				
				s_SETUP_CONFIG_RECEIVED:
				begin
					r_uartTxBegin <= 1;
					if(w_lcdRxData == 'h20) //From datasheet, p31, 0x20 is HDP-1280-2 Rev A
					begin
						r_uartTxData <= {8'd12,"Detected\r\n"}; // 12 Decimal causes page break in PuTTY, not sure about anything else
						r_uartTxDataLength <= 11;
						r_setupState <= s_SETUP_CONFIG_UART_WAITING;
					end
					else
					begin
						r_uartTxData <= {8'd12,"Failed\r\n"};
						r_uartTxDataLength <= 9;
						r_setupState <= s_DETECTION_FAILED;
					end
				end //case s_SETUP_CONFIG_RECEIVED
					
				s_SETUP_CONFIG_UART_WAITING:
				begin
					r_uartTxBegin <= 0;
					if(w_uartTxDone == 1)
						r_setupState <= s_SETUP_ID_REQUEST;
						r_IDByteCounter <= 0;
					
				end //case s_SETUP_UART_WAITING
				
				s_DETECTION_FAILED:
				begin
					if(r_clockCounter < 1000000) // Else, wait 1s (at 1MHz) and ask again
						r_clockCounter <= r_clockCounter + 1;
					else
					begin
							r_clockCounter <= 0;
							r_setupState <= s_SETUP_START;
					end
				end //case s_DETECTION_FAILED
				
				s_SETUP_ID_REQUEST:
				begin
					r_lcdRxBegin <= 0;
					if(r_IDByteCounter == 3)
						r_setupState <= s_SETUP_ID_RECEIVED;
					else
					begin
						if(w_lcdRxDone == 1) //If we have recieved data
						begin
							r_deviceID[(r_IDByteCounter * 8) +: 8] <= w_lcdRxData[7:0];
							r_IDByteCounter <= r_IDByteCounter + 1;
						end
						else if(w_lcdRxBusy == 0) //Haven't got all of our data but tcvr is not busy
						begin
							r_lcdAddress <= HW_ID_ADDRESS_BASE + r_IDByteCounter;
							r_lcdRxBegin <= 1;
						end
						else
							r_setupState <= s_SETUP_ID_REQUEST;
					end
				end//case s_SETUP_ID_REQUEST
				
				s_SETUP_ID_RECEIVED:
				begin
					r_uartTxData <= 	{"ID: ",
											r_deviceID[23:20]+(r_deviceID[23:20] < 10 ? 8'd48 : 8'd55),
											r_deviceID[19:16]+(r_deviceID[19:16] < 10 ? 8'd48 : 8'd55),
											r_deviceID[15:12]+(r_deviceID[15:12] < 10 ? 8'd48 : 8'd55),
											r_deviceID[11:8]+(r_deviceID[11:8] < 10 ? 8'd48 : 8'd55),
											r_deviceID[7:4]+(r_deviceID[7:4] < 10 ? 8'd48 : 8'd55),
											r_deviceID[3:0]+(r_deviceID[3:0] < 10 ? 8'd48 : 8'd55),
											"\r\n"};
					r_uartTxBegin <= 1;
					r_uartTxDataLength <= 12;
					r_setupState <= s_SETUP_ID_UART_WAITING;
				end //case s_SETUP_ID_RECEIVED
				
				s_SETUP_ID_UART_WAITING:
				begin
					r_uartTxBegin <= 0;
				end //case s_SETUP_ID_UART_WAITING
				
			endcase//case with s_SETUP
		end //case s_SETUP
	endcase//Case for whole program
			

end //of main loop	
	
	
always @ (negedge w_pllOutput)
begin
	led_counter <= led_counter + 1;
	led[5:0] <= led_counter[22:17]; //Just used to indicate program is running

end
	
endmodule