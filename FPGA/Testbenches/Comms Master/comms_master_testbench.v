module comms_master_testbench;

reg r_clock = 0;
always #1 r_clock <= !r_clock;

reg r_setup = 0;

comms_master COMM_MASTER_INST
(
	//Clock
	.i_clock(r_clock),
	
	//Control signals
	.i_setup(r_setup),
	/*,
	input			i_activate,
	input 			i_shutdown,
	*/
	
	//SPI (Named to match with HDP pin naming)
	.i_sout(1'b0), //MOSI
	.o_sen(w_sen), //CS (active low)
	.o_sck(w_sck), //SCK (data clocked on rising edge)
	.o_sdat(w_sdat), //MISO
	
	/*
	//UART
	input 			i_uartRx,
	output			o_uartTx,
	*/
	//Done flag
	.o_done(w_done)
);

reg started = 0;

always @(posedge r_clock)
begin
	r_setup <= !started;
	started <= 1;
	if(w_done == 1)
		$stop;
end



endmodule