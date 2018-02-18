/******************************************************************************************
Ingester module to take the 24 bit wide HDMI RGB data and bit juggle into
32 bit wide data and feed to FIFO. Assumes a MSB first system where R > G > B

Dan McGraw, dpm39, University of Cambridge
*******************************************************************************************/


module hdmi_ingester
(
	//HDMI in
	input[23:0]			i_hdmiData,
	input				i_hdmiClock,
	input				i_hSync,
	input 				i_vSync,
	input				i_hdmiEnable,

	//FIFO out
	input				i_fifoFull,
	output				o_dataValid,
	input				o_fifoClock,
	output reg[31:0]	o_fifoData
);

reg[1:0]	r_state;
reg[31:0]	r_tempData;
//Important to use a reg rather than a wire so r_clockEnable can only change synchronously with i_hdmiClock

//Even though data is only sent to FIFO on 3 out of 4 clocks,
//the clock enable pin can be used to disable the clock having effect when desired
assign o_fifoClock = !i_hdmiClock && i_hdmiEnable; 

assign o_dataValid = (r_state != 0); // Used to indicate valid data in o_fifoData

always @(posedge i_hdmiClock) //Assumes that TFP401 is in DFP mode where pixel clock is only active during valid video data
begin
	case (r_state)
		0: //tempData is empty (of bits that haven't been sent)
		begin
			r_tempData[31:8] <= i_hdmiData[23:0];
		end
		
		1: //Have 24 MSB of r_tempData filled
		begin
			o_fifoData[31:0] <= {r_tempData[31:8], i_hdmiData[23:16]};
			r_tempData[31:16] <= i_hdmiData[15:0];
		end
	
		2: //Have 16MSB of r_tempData filled
		begin
			o_fifoData[31:0] <= {r_tempData[31:16], i_hdmiData[23:8]};
			r_tempData[31:24] <= i_hdmiData[7:0];
		end
		
		3: //Have 8 MSB of r_tempData filled
		begin
			o_fifoData[31:0] <= {r_tempData[31:24], i_hdmiData[23:0]};
			r_tempData <= 0;
		end
	endcase

	r_state <= r_state + 2'b1;

end


endmodule