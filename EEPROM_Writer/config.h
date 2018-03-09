#ifndef CONFIGH
#define CONFIGH

//Pixel clock in 10s of kHz, 16 bits
#define PIXEL_CLOCK_FREQ 7100

//Both 12 bits
#define HORIZONTAL_ACTIVE 1280
#define HORIZONTAL_BLANK 100 // >= 7

//Both 12 bits
#define VERTICAL_ACTIVE 800
#define VERTICAL_BLANK 7 // >= 7

//HSYNC_WIDTH = 10 bits, VSYNC_WIDTH = 6 bits
#define HSYNC_WIDTH 5 // >= 5
#define VSYNC_WIDTH 5 // >= 5

//HSYNC_OFFSET = 10 bits, VSYNC_OFFSET = 6 bits
#define HSYNC_OFFSET 1 //Must be > 0
#define VSYNC_OFFSET 1 //Must be > 0


#endif