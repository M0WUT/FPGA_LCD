`timescale 1ns / 1ps

module fifo_32_testbench;

reg 		r_readClock=1'b0;
reg 		r_writeClock=1'b0;
wire[31:0]	w_readData;
reg[31:0]	r_writeData = 32'b0;


wire		w_fifoFull;
wire		w_fifoEmpty;

fifo_32 UUT
(
	.i_inputClock(r_writeClock),
	.i_inputData(r_writeData[31:0]),
	.o_fullFlag(w_fifoFull),
	
	.i_outputClock(r_readClock),
	.o_outputData(w_readData[31:0]),
	.o_emptyFlag(w_fifoEmpty)
);

always #1 r_writeClock <= !r_writeClock;

always @(negedge r_writeClock) //setup data on negedge to be clocked in on posedge
begin
	r_writeData[31:0] <= r_writeData[31:0] + 32'b1;
	if(r_writeData[31:0] > 32'd260)
		$finish;
end

endmodule //fifo_32_testbench


