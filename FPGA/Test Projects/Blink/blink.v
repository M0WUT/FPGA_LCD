module blink
(
	input	i_clock50,
	
	input	i_vSync,
	output	o_active //This is the LED, named the same as the master project so the same pin constraints file could be used
);



assign o_active = i_vSync;




endmodule