module fifo_testbench;

reg			r_clock = 0;
wire		w_clock;
wire		w_readClock;
wire		w_writeClock;
wire		w_readEnable;
reg[31:0]	r_fifoData = 0;
wire[31:0]	w_outputData;

always #1 r_clock = !r_clock;



fifo_32 FIFO_INST
(
	.i_inputClock(w_writeClock),
	.i_inputData(r_fifoData),
	.i_dataValid(1'b1),
	.o_fullFlag(w_fifoFull),
	
	.i_outputClock(w_readClock),
	.o_outputData(w_outputData),
	.o_emptyFlag(w_fifoEmpty)
);

assign w_readClock = (w_readEnable == 1) ? r_clock : 1'b0;
assign w_writeClock = (w_readEnable == 0) ? r_clock : 1'b0;
assign w_readEnable = (r_fifoData > 32'd50) ? 1'b1 : 1'b0;

always @(negedge r_clock)
begin
	r_fifoData <= r_fifoData + 1;
	
	if(w_readEnable == 1 && w_fifoEmpty == 1)
		$stop;
end


endmodule