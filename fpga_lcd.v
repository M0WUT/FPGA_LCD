module FPGA_LCD
(
	 input 				clock_50, //Input from onboard crystal
	 
	 input				i_shutdownSwitch,
	 
	 //LCD stuff
	 output reg[31:0]	data_out,
	 output 				o_lcdClock,
	 output reg			update,
	 output				sync,
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
	///////////////////////
	//Clock Configuration//
	///////////////////////
	
	pll_30M u1 	//Change type to get different clocks speeds, currently implemented pll_1M, pll_4M, pll_8M, pll_140M
	(
		.inclk0(clock_50),
		.c0(w_pllOutput)
	);
	
	parameter 	CLOCK_SPEED = 25000000; //MUST be integer number of MHz, used to report new clock speed to transceiver modules
	
	parameter CLOCK_MHZ = CLOCK_SPEED/1000000; //Done as parameters so evaluated at compile time, does mean a bit ugly as need initialising in 1 line!
	parameter CLOCK_STRING = (CLOCK_MHZ > 100 ? 49 : 0)  << 16 | (((CLOCK_MHZ / 10) % 10) + 24'd48) << 8 | ((CLOCK_MHZ % 10) + 24'd48);
	
	
	//Setup UART Transceiver (Supervisor handles buffering then calls low level UART module uart_tx.v)
	uart_tx_supervisor #(.CLOCK_SPEED(CLOCK_SPEED), .BAUD_RATE(9600)) UART_TRANSMITTER_INSTANCE 
	(
		.i_clock(w_pllOutput),
		.i_txBegin(r_uartTxBegin),
		.i_txData(r_uartTxData),
		.i_txDataLength(r_uartTxDataLength),
		.o_txSerial(o_uartTxSerial),
		.o_txBusy(w_uartTxBusy),
		.o_txDone(w_uartTxDone)
	);
	
	//SPI Module for comminucation with the LCD's serial interface
	lcd_tcvr #(CLOCK_SPEED) LCD_TCVR_INSTANCE 
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
		.o_txBusy(w_lcdTxBusy),
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
	reg 			inverted_frame; //Must send frame then inverse to maintain DC balance, 1 if sending inverted frame
	reg[16:0] 	line_counter = 0;
	reg[31:0] 	frame_pixel_counter=0;
	reg[31:0] 	line_pixel_counter = 0;
	reg 			first = 1; //Used to prevent update pulse at start of first frame
	
	//State machine related stuff
	parameter   s_START = 0;
	parameter 	s_RESET = 1;
	parameter	s_STANDBY = 2;
	parameter 	s_NORMAL = 3;
	parameter 	s_SLEEP = 4;
	parameter 	s_SHUTDOWN = 5;
	parameter 	s_SETUP = 6;
	parameter 	s_TRANSISTION_STANDBY_NORMAL = 7;
	parameter	s_TRANSISTION_NORMAL_SLEEP = 8;
	reg[7:0]		r_state = s_START;
	
	//General counter
	reg[31:0]	r_clockCounter = 0;
	
	//Setup Stuff
	reg[15:0]	r_setupState = 0;
	reg[23:0]	r_deviceID = 0;
	reg[7:0]		r_IDByteCounter = 0;
	
	parameter 	s_SETUP_START = 0;
	parameter 	s_SETUP_CONFIG_REQUEST = 1;
	parameter 	s_SETUP_CONFIG_RECEIVED = 2;
	parameter 	s_SETUP_CONFIG_UART_WAITING = 3;
	parameter 	s_FAILED = 4;
	parameter 	s_SETUP_ID_REQUEST = 5;
	parameter 	s_SETUP_ID_RECEIVED = 6;
	parameter 	s_SETUP_ID_UART_WAITING = 7;
	parameter	s_SETUP_ADDRESS_SET_MSB = 8;
	parameter	s_SETUP_ADDRESS_SET_MSB_WAITING = 9;
	parameter	s_SETUP_ADDRESS_SET_LSB = 10;
	parameter	s_SETUP_ADDRESS_SET_LSB_WAITING = 11;
	parameter	s_SETUP_SET_START_ADDRESS = 12;
	parameter	s_SETUP_SET_START_ADDRESS_WAITING = 13;
	parameter	s_SETUP_START_REPORT = 14;
	parameter	s_SETUP_START_REPORT_LSB = 15;
	parameter	s_SETUP_SET_CURRENT_ADDRESS = 16;
	parameter	s_SETUP_SET_CLOCK_SPEED = 17;
	parameter 	s_SETUP_CHECK_CLOCK = 18;
	parameter	s_SETUP_PRINT_FREQ = 19;
	parameter 	s_SETUP_STANDBY_COMMAND = 20;
	parameter 	s_SETUP_DONE = 21;
	
	
	
	//Debug stuff
	reg[31:0]  	led_counter = 0;
	
	//Register addresses within the LCD
	parameter 	HW_CONFIG_ADDRESS = 'h78; //Contains version number, only version 0x20 was released
	parameter	HW_ID_ADDRESS_BASE = 'h79; // 3 registers starting at this address containing device serial number
	parameter	SERIAL_ROW_ADDRESS_BASE = 'h06; //Contains address of current row being written to
	parameter	HDP_MODE_ADDRESS = 'h01; //Configuration bits
	parameter	SERIAL_COMMAND_ADDRESS = 'h08; //Register that behaviour a bit weirdly but allows serial commands to be executed
	parameter	ROW_ADDRESS_START_ADDRESS_BASE = 'h0A; //2 registers containing row address that will be returned to after an update command
	parameter	HDP_CLOCK_FREQ_ADDRESS = 'h09; //Must contain clock frequency in MHz
	parameter	HDP_TEMPERATURE_ADDRESS = 'h13; //Register containg LCD Temperature
	
	parameter DATA_END = 1280 * 44; //1280 lines, each with 44 clocks
	parameter FRAME_END = DATA_END + 24; //Invert must be set in correct state for 24 clocks before updated is asserted (at start of next frame)
	
assign o_lcdClock = r_clockEnable ? w_pllOutput : 0;
assign sync = 0;


always @ (negedge w_pllOutput) //main LCD writing routine
begin
	case(r_state)
	
		s_START:
		begin
			led[0] <= 0;
			led[1] <= 0;
			o_nreset <= 0;
			r_clockEnable <= 0; 
			if(r_clockCounter < 30) //Hold Device in reset, datasheet specs minimum of 100ns, at max clock speed (140MHz), this is 14 clocks
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
			if(r_clockCounter < 1000000) //Datasheet specs 960000 minimum
				r_clockCounter <= r_clockCounter + 1;
			else
			begin
				//Serial Interface can now be used, start SETUP mode 
				r_clockCounter <= 0;
				r_state <= s_SETUP;
			end
		end //case s_RESET
		
		s_SETUP:
		begin
			case(r_setupState)
				s_SETUP_START:
				begin
					r_lcdAddress <= HW_CONFIG_ADDRESS;
					r_lcdRxBegin <= 1;
					r_setupState <= s_SETUP_CONFIG_REQUEST;
				end //case s_SETUP_START
				
				s_SETUP_CONFIG_REQUEST:
				begin
					r_lcdRxBegin <= 0;
					if(w_lcdRxDone == 1)
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
							r_setupState <= s_FAILED;
						end
					end
					else
						r_setupState <= s_SETUP_CONFIG_REQUEST;
				end //case s_SETUP_CONFIG_REQUEST
								
				s_SETUP_CONFIG_UART_WAITING:
				begin
					r_uartTxBegin <= 0;
					if(w_uartTxDone == 1)
						r_setupState <= s_SETUP_ID_REQUEST;
						r_IDByteCounter <= 0;
				end //case s_SETUP_UART_WAITING
				
				s_FAILED:
				begin
					if(r_clockCounter < CLOCK_SPEED) // Oops, wait 1s (at 1MHz) and ask again
						r_clockCounter <= r_clockCounter + 1;
					else
					begin
							r_clockCounter <= 0;
							r_setupState <= s_SETUP_START;
					end
				end //case s_FAILED
				
				s_SETUP_ID_REQUEST:
				begin
					r_lcdRxBegin <= 0;
					if(r_IDByteCounter == 3) //We are done so print data
					begin
						r_uartTxData <= 	{"ID: ",
											r_deviceID[23:20]+(r_deviceID[23:20] < 10 ? 8'd48 : 8'd55), //Converts to HEX in ASCII
											r_deviceID[19:16]+(r_deviceID[19:16] < 10 ? 8'd48 : 8'd55),
											r_deviceID[15:12]+(r_deviceID[15:12] < 10 ? 8'd48 : 8'd55),
											r_deviceID[11:8]+(r_deviceID[11:8] < 10 ? 8'd48 : 8'd55),
											r_deviceID[7:4]+(r_deviceID[7:4] < 10 ? 8'd48 : 8'd55),
											r_deviceID[3:0]+(r_deviceID[3:0] < 10 ? 8'd48 : 8'd55),
											"\r\n"};
						r_uartTxBegin <= 1;
						r_uartTxDataLength <= 12;
						r_setupState <= s_SETUP_ID_UART_WAITING;
					end
					else
					begin
						if(w_lcdRxDone == 1) //If we have received data
						begin
							r_deviceID[(r_IDByteCounter << 3) +: 8] <= w_lcdRxData[7:0];
							r_IDByteCounter <= r_IDByteCounter + 1;
						end
						else if(w_lcdRxBusy == 0) //Haven't got all of our data but tcvr is not busy so request next byte
						begin
							r_lcdAddress <= HW_ID_ADDRESS_BASE + r_IDByteCounter;
							r_lcdRxBegin <= 1;
						end
						else //Twiddle thumbs
							r_setupState <= s_SETUP_ID_REQUEST;
					end
				end//case s_SETUP_ID_REQUEST
				
				s_SETUP_ID_UART_WAITING:
				begin
			
					r_uartTxBegin <= 0;
					
					if(w_uartTxDone == 1)
					begin
					
						r_lcdTxData <= 0;
						r_lcdAddress <= SERIAL_ROW_ADDRESS_BASE;
						r_lcdTxBegin <= 1;
						r_setupState <= s_SETUP_ADDRESS_SET_MSB_WAITING;
					end
					
					else
						r_setupState <= s_SETUP_ID_UART_WAITING;
						
				end //case s_SETUP_ID_UART_WAITING
				
				
				s_SETUP_ADDRESS_SET_MSB_WAITING:
				begin
					
					r_lcdTxBegin <= 0;
					if(w_lcdTxDone == 1)
					begin
						r_lcdTxData <= 0;
						r_lcdAddress <= SERIAL_ROW_ADDRESS_BASE + 1;
						r_lcdTxBegin <= 1;
						r_setupState <= s_SETUP_ADDRESS_SET_LSB_WAITING;
					end
					else
						r_setupState <= s_SETUP_ADDRESS_SET_MSB_WAITING;
				end //case s_SETUP_ADDRESS_SET_WAITING
				
				
				s_SETUP_ADDRESS_SET_LSB_WAITING:
				begin
			
					r_lcdTxBegin <= 0;
					if(w_lcdTxDone == 1)
					begin
						r_lcdAddress <= SERIAL_COMMAND_ADDRESS;
						r_lcdTxData <= 8'h30; 	//Setting 3 in the upper nibble sets the row address start pointer (where the screen returns to after an update pulse)
														//to the value in the Serial Row Address registers which we have just set to 0
						r_lcdTxBegin <= 1;
						r_setupState <= s_SETUP_SET_CURRENT_ADDRESS;
					end
					else
						r_setupState <= s_SETUP_ADDRESS_SET_LSB_WAITING;
				end //case s_SETUP_ADDRESS_SET_WAITING
				
				
				s_SETUP_SET_CURRENT_ADDRESS:
				begin
			
					r_lcdTxBegin <= 0;
					if(w_lcdTxDone == 1)
					begin
						r_lcdAddress <= SERIAL_COMMAND_ADDRESS;
						r_lcdTxData <= 8'h40; 	//Setting 4 in the upper nibble sets the current address pointer 
														//to the value in the Serial Row Address registers which we have just set to 0
						r_lcdTxBegin <= 1;
						r_setupState <= s_SETUP_SET_START_ADDRESS_WAITING;
					end
					else
						r_setupState <= s_SETUP_SET_CURRENT_ADDRESS;
				end //case s_SETUP_ADDRESS_SET_WAITING
				
				s_SETUP_SET_START_ADDRESS_WAITING:
				begin
					
					r_lcdTxBegin <= 0;
					if(w_lcdTxDone == 1)
					begin
						r_lcdAddress <= ROW_ADDRESS_START_ADDRESS_BASE;
						r_lcdRxBegin <= 1;
						r_setupState <= s_SETUP_START_REPORT;
					end
					else
						r_setupState <= s_SETUP_SET_START_ADDRESS_WAITING;
				end //case s_SETUP_SET_START_ADDRESS_WAITING
				
				s_SETUP_START_REPORT:
				begin
					r_lcdRxBegin <= 0;
					if(w_lcdRxDone == 1)
					begin
						if(w_lcdRxData[2:0] == 0) //Good as this should be set to 0
						begin
							r_lcdAddress <= ROW_ADDRESS_START_ADDRESS_BASE + 1;
							r_lcdRxBegin <= 1;
							r_setupState <= s_SETUP_START_REPORT_LSB;
						end
						else
						begin
							r_uartTxData <= "Failed\r\n";
							r_uartTxDataLength <= 8;
							r_setupState <= s_FAILED;
						end
					end
					else
						r_setupState <= s_SETUP_START_REPORT;
				end //s_SETUP_START_REPORT
				
				s_SETUP_START_REPORT_LSB:
				begin
					r_lcdRxBegin <= 0;
					r_uartTxBegin <= 0;
					if(w_lcdRxDone == 1)
					begin
						r_uartTxBegin <= 1;
						if(w_lcdRxData[7:0] == 0)
						begin
							r_uartTxData[96:0] <= "S Addr Set\r\n";
							r_uartTxDataLength <= 12;
							r_setupState <= s_SETUP_SET_CLOCK_SPEED;
						end
						else
						begin
							r_uartTxData[63:0] <= "Failed\r\n";
							r_uartTxDataLength <= 8;
							r_setupState <= s_FAILED;
						end
					end
					else
						r_setupState <= s_SETUP_START_REPORT_LSB;
				end //case s_SETUP_START_REPORT_LSB
				
				s_SETUP_SET_CLOCK_SPEED:
				begin
					r_uartTxBegin <= 0;
					if(w_uartTxDone == 1)
					begin
						r_lcdAddress <= HDP_CLOCK_FREQ_ADDRESS;
						r_lcdTxData <= CLOCK_MHZ[7:0]; 	//Setting 4 in the upper nibble sets the current address pointer 
														//to the value in the Serial Row Address registers which we have just set to 0
						r_lcdTxBegin <= 1;
						r_setupState <= s_SETUP_CHECK_CLOCK;
					end
					else
						r_setupState <= s_SETUP_SET_CLOCK_SPEED;
				end //case s_SETUP_SET_CLOCK_SPEED
				
				s_SETUP_CHECK_CLOCK: //Readback clock frequency
				begin
					r_lcdTxBegin <= 0;
					if(w_lcdTxDone == 1)
					begin
						r_lcdAddress <= HDP_CLOCK_FREQ_ADDRESS;
						r_lcdRxBegin <= 1;
						r_setupState <= s_SETUP_PRINT_FREQ;
					end
					else
						r_setupState <= s_SETUP_CHECK_CLOCK;
				end //case s_SETUP_CHECK_CLOCK
				
				s_SETUP_PRINT_FREQ:
				begin
					r_lcdRxBegin <= 0;
					if(w_lcdRxDone == 1)
					begin
						r_uartTxBegin <= 1;
						if(w_lcdRxData[7:0] == CLOCK_MHZ)
						begin
							r_uartTxData[87:0] <= {"Clk: ", CLOCK_STRING[23:0] ,"M\r\n"};
							r_uartTxDataLength <= 11;
							r_setupState <= s_SETUP_STANDBY_COMMAND;
						end
						else
						begin
							r_uartTxData[63:0] <= "Failed\r\n";
							r_uartTxDataLength <= 8;
							r_setupState <= s_FAILED;
						end
					end
					else
						r_setupState <= s_SETUP_PRINT_FREQ;
				end //case s_SETUP_PRINT_FREQ
				
				s_SETUP_STANDBY_COMMAND:
				begin
					r_uartTxBegin <= 0;
					if(w_uartTxDone == 1)
					begin
						r_lcdAddress <= HDP_MODE_ADDRESS;
						r_lcdTxData <= 8'h01; 	//Go into Standby Mode
						r_lcdTxBegin <= 1;
						r_setupState <= s_SETUP_DONE;
					end
					else
						r_setupState <= s_SETUP_STANDBY_COMMAND;
					
				end //case s_SETUP_STANDBY_COMMAND
				 
				s_SETUP_DONE:
				begin
					r_lcdTxBegin <= 0;
					if(w_lcdTxDone == 1)
					begin
						r_state <= s_STANDBY;
						led[0] <= 1;
						r_setupState <= s_SETUP_START; //Clean up in case we re-setup (if that's a word)
					end
					else
						r_setupState <= s_SETUP_DONE;
				end //case s_SETUP_DONE
				
			endcase//case with s_SETUP
		end //case s_SETUP
		
		s_STANDBY:
		begin
			o_nreset <= 1;
			r_clockEnable <= 1;
			if(r_clockCounter < 1000000) //Datasheet specs 960000 minimum
				r_clockCounter <= r_clockCounter + 1;
			else
			begin
				//Serial Interface can now be used, start SETUP mode 
				r_clockCounter <= 0;
				
				r_lcdAddress <= HDP_MODE_ADDRESS;
				r_lcdTxData <= 8'h02; 	//Go into normal mode 
				r_lcdTxBegin <= 1;
				r_state <= s_TRANSISTION_STANDBY_NORMAL;
			end
		end //case s_STANDBY
		
		s_TRANSISTION_STANDBY_NORMAL:
		begin
			r_lcdTxBegin <= 0;
			//Wait until transistion complete before sending image data
			if(w_lcdTxDone == 1)
				r_state <= s_NORMAL;
			else
				r_state <= s_TRANSISTION_STANDBY_NORMAL;
		end //case s_TRANSISTION_STANDBY_NORMAL
		
		s_NORMAL:
		begin
			r_uartTxBegin <= 0;
			r_lcdTxBegin <= 0;
			r_lcdRxBegin <= 0;
			r_clockEnable <= 1;
			frame_pixel_counter <= frame_pixel_counter + 1;	
			update <= (first == 0) && (frame_pixel_counter < 48); //update must be high for first 48 clock pulses
			
			//invert <= (first == 0) && (((frame_pixel_counter >= DATA_END) && inverted_frame) || ((frame_pixel_counter < 72) && ~inverted_frame));
			invert<=0; //DEEBUG

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
						if((line_counter < 320) || line_counter > 960)
							data_out[31:0] = 31'hFFFFFFFF; //Replace this bit with valid data
						else
							data_out[31:0] = 31'h0;
						
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
			else //We are in the back porch, send 24 clocks
			begin
				valid <= 0;
				first <= 0;
				data_out[31:0] <= 0;
				if(frame_pixel_counter == FRAME_END - 1) //minus 1 because of parallel magic
				begin
					frame_pixel_counter <= 0;
					line_pixel_counter <= 0;
					line_counter <= 0;
					//inverted_frame <= ~inverted_frame; //DEBUG
				end
			end
			
			if(i_shutdownSwitch == 0)
			begin
				led[1] <= 1;
				r_lcdAddress <= HDP_MODE_ADDRESS;
				r_lcdTxData <= 8'h00; 	//Go into sleep mode 
				r_lcdTxBegin <= 1;
				r_state <= s_TRANSISTION_NORMAL_SLEEP;
			end
				
			/* //This section reads temperature continually, not sure what use it is but threw it in anyway
			if(w_uartTxBusy == 0 && w_lcdRxBusy == 0)
			begin
				r_lcdAddress <= HDP_TEMPERATURE_ADDRESS; 
				r_lcdRxBegin <= 1;
			end
			
			if(w_lcdRxDone == 1)
			begin
				r_uartTxBegin <= 1;
				r_uartTxData[39:0] <= {((w_lcdRxData[7:0] / 100) + 8'd48) << 16 | (((w_lcdRxData[7:0] / 10) % 10) + 8'd48) << 8 | (w_lcdRxData[7:0] % 10) + 8'd48 ,"\r\n"};
				r_uartTxDataLength <= 5;
			end
			*/
				
		end //case s_NORMAL
		
		s_TRANSISTION_NORMAL_SLEEP:
		begin
		
			r_lcdTxBegin <= 0;
			//Wait until transistion complete before going to sleep
			if(w_lcdTxDone == 1)
				r_state <= s_SLEEP;
			else
				r_state <= s_TRANSISTION_NORMAL_SLEEP;
		
		end //case s_TRANSISTION_NORMAL_SLEEP
		
		s_SLEEP:
		begin
			o_nreset <= 1;
			r_clockEnable <= 1;
			if(r_clockCounter < CLOCK_SPEED) //Datasheet specs wait for 1500us minimum before removing clock, this waits for 1s
				r_clockCounter <= r_clockCounter + 1;
			else
			begin
				//All done
				r_clockCounter <= 0;
				r_state <= s_SHUTDOWN;
			end
		end //case s_SLEEP
		
		s_SHUTDOWN:
		begin
			o_nreset <= 0;
			r_clockEnable <= 0;
			led[0] <= 0;
			led[1] <= 0;
		end
		
		
	endcase//Case for whole program
			

end //of main loop	
	
	
always @ (negedge w_pllOutput)
begin
	led_counter <= led_counter + 1;
	if(led_counter > (CLOCK_SPEED >> 1)) //1Hz blinky light to indicate running
	begin
		led[5] <= ~led[5];
		led_counter <= 0;
	end
end
	
endmodule