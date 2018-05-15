/******************************************************************************************
32 bit FIFO that is 256 words deep
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
	output			o_emptyFlag,
	output[7:0]		o_writeAddress,
	output[7:0]		o_readAddress
);	

//Address pointers
reg[7:0] r_readAddress = 0;
reg[7:0] r_writeAddress = 0;

reg[31:0] FIFO [255:0];

assign o_emptyFlag = (r_readAddress == r_writeAddress); //We have no data if the current location to be written is the current to be read
assign o_fullFlag = (r_readAddress == r_writeAddress + 8'b1); //Full if we have looped around the entire buffer and are about to overwrite unread data
assign o_writeAddress = r_writeAddress;
assign o_readAddress = r_readAddress;
assign o_outputData = FIFO[r_readAddress];

always @(posedge i_inputClock)
begin
	if(!o_fullFlag && i_dataValid)
	begin
		FIFO[r_writeAddress] <= i_inputData;
		r_writeAddress <= r_writeAddress + 1;
	end
end

always @(posedge i_outputClock) //Want to grab data on negedge so setup for LCD write on posedge
begin
	if(!o_emptyFlag)
	begin
		r_readAddress <= r_readAddress + 1;
	end
end

endmodule //fifo_32