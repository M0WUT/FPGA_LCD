/******************************************************************************************
Wrapper around Lattice ice40 Block RAM to make it look like 32 bit FIFO
This FIFO provides full/empty flags, data is clocked in/out on rising edge

//NOTE
If you try to write data when the FIFO is Full it is ignored
If you try to read data when the FIFO is Empty, the last value read will stay on the output 

Dan McGraw, dpm39, University of Cambridge
*******************************************************************************************/

module fifo_32
(
	//Input side
	input 			i_inputClock,
	input[31:0]		i_inputData,
	input			i_dataValid,
	output			o_fullFlag,
	
	//Output side
	input			i_outputClock,
	output[31:0]	o_outputData,
	output			o_emptyFlag
);

//Address pointers
reg[7:0] r_readAddress = 0;
reg[7:0] r_writeAddress = 0;

assign o_emptyFlag = (r_readAddress == r_writeAddress); //We have no data if the current location to be written is the current to be read
assign o_fullFlag = (r_writeAddress + 1 == r_readAddress); //Full if we have looped around the entire buffer and are about to overwrite unread data

//Instantiate 2 256x16 Block RAMs to be used in parallel as 256x32
//Online stuff say these should probably be "inferred" but nowhere really said how to do this!
/*
WDATA[15:0]	Input Write Data input.
MASK[15:0] 	Input Masks write operations for individual data bit-lines. 0 = write bit; 1 = don’t write bit
WADDR[7:0] 	Input Write Address input. Selects one of 256 possible RAM locations.
WE 			Input Write Enable input.
WCLKE 		Input Write Clock Enable input.
WCLK 		Input Write Clock input. Default rising-edge, but with falling-edge option.
RDATA[15:0] Output Read Data output.
RADDR[7:0] 	Input Read Address input. Selects one of 256 possible RAM locations.
RE1 		Input Read Enable input. Only available for SB_RAM256x16 configurations.
RCLKE 		Input Read Clock Enable input.
RCLK 		Input Read Clock input. Default rising-edge, but with falling-edge option.
*/
SB_RAM256x16 lsb
(
	//Reading 
	.RDATA(o_outputData[15:0]),
	.RADDR(r_readAddress[7:0]),
	.RCLK(i_outputClock),
	.RCLKE(!o_fullFlag),
	.RE(1'b1),
	
	//Writing
	.WADDR(r_writeAddress[7:0]),
	.WCLK(i_inputClock),
	.WCLKE(!o_emptyFlag && i_dataValid),
	.WDATA(i_inputData[15:0]),
	.WE(1'b1),
	.MASK(16'b0) //0 in a bit allows that bit to be written
);

SB_RAM256x16 msb
(
	//Reading 
	.RDATA(o_outputData[31:16]),
	.RADDR(r_readAddress[7:0]),
	.RCLK(i_outputClock),
	.RCLKE(!o_fullFlag),
	.RE(1'b1),
	
	//Writing
	.WADDR(r_writeAddress[7:0]),
	.WCLK(i_inputClock),
	.WCLKE(!o_emptyFlag && i_dataValid),
	.WDATA(i_inputData[31:16]),
	.WE(1'b1),
	.MASK(16'b0) //0 in a bit allows that bit to be written
);

//Update address on falling edge so stable when data is read on rising edge
always @(negedge i_inputClock) r_writeAddress <= (o_fullFlag ? r_writeAddress : r_writeAddress + 8'b1);
always @(negedge i_outputClock) r_readAddress <= (o_emptyFlag ? r_readAddress : r_readAddress + 8'b1);

endmodule //fifo_32