module fifo_testbench;

reg			r_clock = 0;
reg[31:0]	r_fifoData = 0;
wire[31:00]	w_outputData;
always #1 r_clock = !r_clock;



fifo_32 FIFO_INST
(
	.i_inputClock(r_clock),
	.i_inputData(r_fifoData),
	.i_dataValid(1'b1),
	.o_fullFlag(w_fifoFull),
	
	.o_outputData(w_outputData)
);

always @(negedge r_clock)
begin
	r_fifoData <= r_fifoData + 1;

	if(w_fifoFull == 1)
	 $stop;
end

endmodule