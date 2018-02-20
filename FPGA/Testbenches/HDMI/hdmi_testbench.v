module hdmi_testbench;

reg			r_clock = 0;

reg[23:0]	r_hdmiData = 0;
wire[31:0]	w_fifoData;

hdmi_ingester HDMI_INST
(
	//HDMI in
	.i_hdmiData(r_hdmiData),
	.i_hdmiClock(r_clock),
	.i_hdmiEnable(1'b1),

	//FIFO out
	.i_fifoFull(1'b0),
	.o_dataValid(w_dataValid),
	.o_fifoClock(w_fifoClock),
	.o_fifoData(w_fifoData)
);

always #1 r_clock <= !r_clock;

always @(negedge r_clock)
begin
	r_hdmiData <= r_hdmiData + 1;
	if(r_hdmiData > 20)
		$stop;

end
		
endmodule