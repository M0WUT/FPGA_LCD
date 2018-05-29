/******************************************************************************************
Ingester module to take the 24 bit wide HDMI RGB data and bit juggle into
32 bit wide data and feed to FIFO. Assumes a MSB first system where R > G > B

Dan McGraw, dpm39, University of Cambridge
*******************************************************************************************/


module spi_ingester
(
	input 		i_sck,
	input		i_mosi,
	input		i_cs,	
	
	output reg	o_buffer1Ready,
	output reg	o_buffer2Ready
);


reg buffer1 [1279:0];
reg buffer2 [1279:0];

always @(posedge i_sck) 
begin
	if(i_cs == 0)
	begin
		
	
	
	end
end
endmodule