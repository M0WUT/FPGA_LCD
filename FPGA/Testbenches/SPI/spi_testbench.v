module spi_testbench;

reg r_clock = 0;
reg[7:0]	r_spiTxData;
reg[6:0]	r_spiTxAddress;
reg			r_spiTxBegin;

always #1 r_clock = !r_clock;

spi UUT
(
	//Clock
	.i_clock(r_clock),
	
	//Tx
	.i_txBegin(r_spiTxBegin),
	.i_txAddress(r_spiTxAddress),
	.i_txData(r_spiTxData),
	.o_txBusy(w_spiTxBusy),
	.o_txDone(w_spiTxDone),
	
	//IO (Named to match with HDP pin naming)
	.o_sen(w_sen), //CS (active low)
	.o_sck(w_sck), //SCK (data clocked on rising edge)
	.o_sdat(w_sdat) //MISO
);


initial 
begin
	r_spiTxBegin <= 0;
	r_spiTxAddress <= 'h12;
	r_spiTxData <= 0;
	r_spiTxBegin <= 1;
end

always @(posedge r_clock)
begin
	r_spiTxBegin <= 0;
	if(w_spiTxDone == 1)
	begin
		r_spiTxData <= r_spiTxData + 1;
		r_spiTxBegin <= 1;
		if(r_spiTxData == 20)
			$stop;
	end


end


endmodule