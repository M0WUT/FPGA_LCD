/******************************************************************************************
Wrapper around the basic SPI module / UART supervisor to handle startup / shutdown

Minimum config register setup is:
* Read HW_CONFIG register (0x78), should be 0x20 for valid device
* Write 0 to Serial row address MSB and LSB (0x06 and 0x07)
* Write 0x30 to Serial Command register (0x08) to set the value in the serial row address to be the 
	value we return to after update
* Write 0x40 to Serial Command register to set current row address to Serial row address
* Write clock frequency in MHZ to Clock register (0x09)
* Write 0x01 to HDP Mode (0x01) to put device into standby
* Wait for >960000 clock cycles
* Write 0x02 to HDP Mode to put device into active mode

Shutdown is:
* Write 0x00 to HDP Mode
* Wait >1500us
* Device can then be put into reset

***********************************************************************************************
Strongly recommend moving this task to a separate microcontroller if this is developed further.
***********************************************************************************************

Dan McGraw, dpm39, University of Cambridge
*******************************************************************************************/

module comms_master
(
	//Clock
	input 			i_clock,
	
	//Control signals
	input 			i_setup,
	input			i_activate,
	input 			i_shutdown,
	
	//SPI (Named to match with HDP pin naming)
	input			i_sout, //MOSI
	output			o_sen, //CS (active low)
	output			o_sck, //SCK (data clocked on rising edge)
	output  		o_sdat, //MISO
	
	//UART
	input 			i_uartRx,
	output			o_uartTx,
	
	//Done flag
	output			o_done
	
);

parameter CLOCK_SPEED = 50;

spi #(.CLOCKS_PER_BIT(CLOCK_SPEED)) SPI_INST
(
	//Clock
	.i_clock(i_clock),
	
	//Tx
	.i_txBegin(r_spiTxBegin),
	.i_txAddress(r_spiTxAddress),
	.i_txData(r_spiTxData),
	.o_txBusy(w_spiTxBusy),
	.o_txDone(w_spiTxDone),

	//Rx
	.i_rxBegin(r_spiRxBegin),
	.i_rxAddress(r_spiRxAddress),
	.o_rxData(w_spiRxData),
	.o_rxBusy(w_spiRxBusy),
	.o_rxDone(w_spiRxDone),
	
	//IO
	.i_sout(i_sout),
	.o_sen(o_sen),
	.o_sck(o_sck),
	.o_sdat(o_sdat)
);

uart_tx_supervisor #(.CLOCKS_PER_BIT(CLOCK_SPEED * 100)) UART_TX_INST
(
	.i_clock(i_clock),
	.i_txBegin(r_uartTxBegin),
	.i_txData(r_uartTxData),
	.i_txDataLength(r_uartTxDataLength),
	.o_txBusy(w_uartTxBusy),
	.o_txSerial(o_uartTx),
	.o_txDone(w_uartTxDone)
);

//SPI Tx
reg 		r_spiTxBegin = 0;
reg[6:0]	r_spiTxAddress = 0;
reg[7:0]	r_spiTxData = 0;

//SPI Rx
reg			r_spiRxBegin = 0;
reg[6:0]	r_spiRxAddress = 0;
wire[7:0]	w_spiRxData;

//UART Tx
reg 		r_uartTxBegin = 0;
reg[111:0]	r_uartTxData = 0;
reg[7:0]	r_uartTxDataLength = 0;

//Delay counter
reg[32:0] r_clockCounter = 0;

//State machine
reg[7:0]	r_state = 0;

parameter 	s_IDLE = 0;
parameter	s_ID_REQUEST = 1;
parameter 	s_FAILED = 2;
parameter	s_SERIAL_ROW_MSB = 3;
parameter	s_SERIAL_ROW_LSB = 4;
parameter	s_SET_RETURN_ADDRESS = 5;
parameter	s_SET_CURRENT_ADDRESS = 6;
parameter	s_SET_CLOCK = 7;
parameter	s_STANDBY = 8;
parameter	s_DONE = 9;
parameter	s_WAITING = 10;


//Addresses
parameter	CONFIG_ADDRESS = 'h78;
parameter	SERIAL_ROW_ADDRESS = 'h06;
parameter	SERIAL_COMMAND_ADDRESS = 'h08;
parameter	HDP_MODE_ADDRESS = 'h01;
parameter	HDP_CLOCK_ADDRESS = 'h09;

assign o_done = (r_state == s_DONE);

always @(posedge i_clock)
begin
	case (r_state)
	s_IDLE:
	begin
		if(i_setup == 1)
		begin
			r_state <= s_ID_REQUEST;
		end
		else if(i_activate == 1)
		begin
			r_spiTxData <= 'h2;
			r_spiTxAddress <= HDP_MODE_ADDRESS;
			r_spiTxBegin <= 1;
			r_state <= s_WAITING;
		end
		else if(i_shutdown == 1)
		begin
			r_spiTxData <= 0;
			r_spiTxAddress <= HDP_MODE_ADDRESS;
			r_spiTxBegin <= 1;
			r_state <= s_WAITING;
		end
		else
			r_state <= s_IDLE;
	end //case s_IDLE
	
	s_ID_REQUEST:
	begin
		r_spiRxAddress <= CONFIG_ADDRESS;
		r_spiRxBegin <= 1;
	end //case s_ID_REQUEST
	
	s_FAILED:
	begin
		if(r_clockCounter > CLOCK_SPEED * 1000000)
		begin
			r_clockCounter <= 0;
			r_state <= s_ID_REQUEST;
		end
		else
			r_clockCounter <= r_clockCounter + 1;
	end //case s_FAILED
			
	
	s_SERIAL_ROW_MSB:
	begin
		r_spiRxBegin <= 0;
		if(w_spiRxDone == 1)
		begin	
			if(w_spiRxData == 'h20)
			begin
				r_spiTxAddress <= SERIAL_ROW_ADDRESS;
				r_spiTxData <= 0;
				r_spiTxBegin <= 1;
				r_state <= s_SERIAL_ROW_LSB;
			end
			else
				r_state <= s_FAILED;
		end
		else	
			r_state <= s_SERIAL_ROW_MSB;
	end //case s_SERIAL_ROW_MSB
	
	s_SERIAL_ROW_LSB:
	begin
		r_spiTxBegin <= 0;
		if(w_spiTxDone == 1)
		begin
			r_spiTxAddress <= SERIAL_ROW_ADDRESS + 1;
			r_spiTxData <= 0;
			r_spiTxBegin <= 1;
			r_state <= s_SET_RETURN_ADDRESS;
		end
		else
			r_state <= s_SERIAL_ROW_LSB;
	end //case s_SERIAL_ROW_LSB
	
	s_SET_RETURN_ADDRESS:
	begin
		r_spiTxBegin <= 0;
		if(w_spiTxDone == 1)
		begin
			r_spiTxAddress <= SERIAL_COMMAND_ADDRESS;
			r_spiTxData <= 'h30;
			r_spiTxBegin <= 1;
			r_state <= s_SET_CURRENT_ADDRESS;
		end
		else
			r_state <= s_SET_RETURN_ADDRESS;
	end //case s_SET_RETURN_ADDRESS

	s_SET_CURRENT_ADDRESS:
	begin
		r_spiTxBegin <= 0;
		if(w_spiTxDone == 1)
		begin
			r_spiTxAddress <= SERIAL_COMMAND_ADDRESS;
			r_spiTxData <= 'h40;
			r_spiTxBegin <= 1;
			r_state <= s_SET_CLOCK;
		end
		else
			r_state <= s_SET_CURRENT_ADDRESS;
	end //case s_SET_CURRENT_ADDRESS
	
	s_SET_CLOCK:
	begin
		r_spiTxBegin <= 0;
		if(w_spiTxDone == 1)
		begin
			r_spiTxAddress <= HDP_CLOCK_ADDRESS;
			r_spiTxData <= CLOCK_SPEED;
			r_spiTxBegin <= 1;
			r_state <= s_STANDBY;
		end
		else
			r_state <= s_SET_CLOCK;
	end //case s_SET_CLOCK
	
	s_STANDBY:
	begin
		r_spiTxBegin <= 0;
		if(w_spiTxDone == 1)
		begin
			r_spiTxAddress <= HDP_MODE_ADDRESS;
			r_spiTxData <= 'h1; //Standby mode
			r_spiTxBegin <= 1;
			r_clockCounter <= 0;
			r_state <= s_WAITING;
		end
		else
			r_state <= s_STANDBY;
	end //case s_STANDBY

	s_DONE:
	begin
		//Provides a single clock delay for the done flag to be set high
		r_state <= s_IDLE;
	end
	
	s_WAITING:
	begin
		r_spiTxBegin <= 0;
		if(w_spiTxDone == 1)
			r_state <= s_DONE;
		else
			r_state <= s_WAITING;
	end //case s_WAITING
	
	endcase
end

endmodule