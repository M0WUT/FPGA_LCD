module FPGA_LCD_top
(
	//Master clock
	input			i_clock50,
	
	//HDMI Input
	input[23:0]		i_hdmiData,
	input 			i_hdmiClock,
	input			i_hSync,
	input			i_vSync,
	
	//HDP Output,
	output reg[31:0]o_lcdData,
	output			o_valid,
	output			o_sync,
	output			o_nReset,
	output			o_update,
	output			o_invert,
	output			o_lcdClock,
	
	//UART
	output			o_uartTx,
	input			i_uartRx, //Not yet implemented
	
	//SPI
	output			o_sen,
	output			o_sck,
	output			o_sdat,
	input			i_sout,
	
	//Debug
	output			o_active,
	input			i_shutdown,
	output			o_fifoFull,
	output			o_fifoEmpty
);

//Direct drive or use PLL
wire 	w_lcdClock;
assign	w_lcdClock = i_clock50;
parameter CLOCK_SPEED = 50; //Clock speed in MHz


reg		r_commSetup = 0;
reg		r_commActivate = 0;
reg		r_commShutdown = 0;
wire	w_commDone;
wire[31:0]	w_fifoData;
wire[31:0]	w_lcdData;
wire		w_fifoClock;
wire		w_fifoDataValid;

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


fifo_32 FIFO_INST
(
	//Input from HDMI Ingester
	.i_inputClock(w_fifoClock),
	.i_inputData(w_fifoData),
	.i_dataValid(w_fifoDataValid),
	//.o_fullFlag(o_fifoFull), //DEBUG
	
	//Output to LCD
	.i_outputClock(o_lcdClock && o_valid),
	.o_outputData(w_lcdData)
	//.o_emptyFlag(o_fifoEmpty) //DEBUG
);


hdmi_ingester HDMI_INGESTER_INST
(
	//HDMI input
	.i_hdmiData(i_hdmiData),
	.i_hdmiClock(i_hdmiClock),
	.i_hSync(i_hSync),
	.i_vSync(i_vSync), 
	.i_hdmiEnable(o_active),
	
	//Fifo connections
	.i_fifoFull(o_fifoFull),
	.o_dataValid(w_fifoDataValid),
	.o_fifoClock(w_fifoClock),
	.o_fifoData(w_fifoData)
);


//Used to gate the clock to the HDP
assign 		o_nReset = ((r_state != s_START) && (r_state != s_SHUTDOWN));
assign 		o_lcdClock = (w_lcdClock && o_nReset); //Clock is only active when reset is high
assign 		o_active = (r_state == s_NORMAL); 
assign 		o_valid = (o_active && (r_linePacketCounter < 40));
assign		o_update = (o_active && (r_packetCounter < 28));
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

//DEBUG//
assign o_uartTx = r_state[0];
assign o_fifoEmpty = r_state[1];
assign o_fifoFull = r_state[2];

parameter DATA_END = (44 * 1280); //44 clocks per line(40 valid and 4 blank) * 1280 lines
parameter FRAME_END = DATA_END + 24; //Back porch of 24 clock at the end

always @(negedge w_lcdClock)
begin
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
		//Used for whole frame
		r_packetCounter <= r_packetCounter + 1;
		//Used for where we are in a line
		r_linePacketCounter <= r_linePacketCounter + 1;
		if(r_linePacketCounter == 43)
		begin
			r_linePacketCounter <= 0;
			r_lineCounter <= r_lineCounter + 1;
		end

		if(r_packetCounter < DATA_END)
		begin
			if(r_linePacketCounter < 40)
			begin
				////////////////////////////////////
				//This is where valid data is sent//
				////////////////////////////////////
				o_lcdData <= (r_linePacketCounter[2] == 1'b0 ? 32'hFFFFFFFF: 32'h0);
			end	
			else
				//Need 4 clocks of 0 data with valid low at the end of each line
				o_lcdData[31:0] <= 32'b0;
		end
		else
		begin
			//In the back porch
			if(r_packetCounter == (FRAME_END - 1)) //minus 1 because of zero indexing
			begin
				r_packetCounter <= 0;
				r_linePacketCounter <= 0;
				r_lineCounter <= 0;
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
	end
	
	s_SHUTDOWN:
	begin
	end
	
	endcase
	
end

endmodule