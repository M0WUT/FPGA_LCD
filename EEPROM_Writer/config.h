#ifndef CONFIGH
#define CONFIGH

//Pixel clock in 10s of kHz, 16 bits
#define PIXEL_CLOCK_FREQ 3200 

//Both 12 bits
#define HORIZONTAL_ACTIVE 800 
#define HORIZONTAL_BLANK 128

//Both 12 bits
#define VERTICAL_ACTIVE 480
#define VERTICAL_BLANK 45

//HSYNC_WIDTH = 10 bits, VSYNC_WIDTH = 6 bits
#define HSYNC_WIDTH 48
#define VSYNC_WIDTH 3

//HSYNC_OFFSET = 10 bits, VSYNC_OFFSET = 6 bits
#define HSYNC_OFFSET 40
#define VSYNC_OFFSET 13


#endif