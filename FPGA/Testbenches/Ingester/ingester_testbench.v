module ingester_testbench;

reg			r_clock = 0;

reg			r_writeComplete = 0;
reg[23:0]	r_hdmiData = 0;
wire[31:0]	w_fifoData;
wire[31:0]	w_fifoOutput;

hdmi_ingester HDMI_INST
(
	//HDMI in
	.i_hdmiData(r_hdmiData),
	.i_hdmiClock(r_clock && !r_writeComplete),
	.i_hdmiEnable(1'b1),

	//Output to FIFO
	.i_fifoFull(w_fifoFull),
	.o_dataValid(w_dataValid),
	.o_fifoClock(w_fifoClock),
	.o_fifoData(w_fifoData)
);

fifo_32 FIFO_INST
(
	//Input side
	.i_inputClock(w_fifoClock),
	.i_inputData(w_fifoData),
	.i_dataValid(w_dataValid),
	.o_fullFlag(w_fifoFull),
	
	
	//Output side
	.i_outputClock(r_clock && r_writeComplete),
	.o_outputData(w_fifoOutput),
	.o_emptyFlag(w_fifoEmpty)
	


);

always #1 r_clock <= !r_clock;

always @(negedge r_clock)
begin
	r_hdmiData <= r_hdmiData + 1;
	if(w_fifoEmpty && r_writeComplete)
		$stop;
	if(w_fifoFull)
		r_writeComplete <= 1;
end


		
endmodule