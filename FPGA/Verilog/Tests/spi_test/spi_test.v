module spi_test
(
	//Master clock
	input			i_clock50,
	
	
	
	//SPI
	output			o_sen,
	output			o_sck,
	output			o_sdat,
	input			i_sout,
	output			o_spiTxBusy,
	output			o_spiTxDone,
	
	//Blinky Light
	output		o_blinkyLight

	
);

reg[7:0]		r_spiTxData;
reg[6:0]		r_spiTxAddress;
reg				r_spiTxBegin;
reg[25:0]	r_clockCounter;

assign o_blinkyLight = r_clockCounter[25];

spi SPI_TCVR
(
	//TX
	.i_clock(i_clock50),
	.i_txBegin(r_spiTxBegin),
	.i_txAddress(r_spiTxAddress),
	.i_txData(r_spiTxData),
	.o_txBusy(o_spiTxBusy),
	.o_txDone(o_spiTxDone),
	
	/*
	//Rx
	input			i_rxBegin,
	input[6:0]		i_rxAddress,
	output reg[7:0]	o_rxData,
	output			o_rxBusy,
	output			o_rxDone,
	*/
	
	//IO
	.i_sout(i_sout), //MOSI
	.o_sen(o_sen), //CS (active low)
	.o_sck(o_sck), //SCK (data clocked on rising edge)
	.o_sdat(o_sdat) //MISO
);



always @(posedge i_clock50)
begin
	if(!o_spiTxBusy)
	begin
		r_spiTxAddress <= 7'h12;
		r_spiTxData <= 8'h34;
		r_spiTxBegin <= 1;
	end
	else
		r_spiTxBegin <= 0;

	r_clockCounter <= r_clockCounter + 1;

end

endmodule