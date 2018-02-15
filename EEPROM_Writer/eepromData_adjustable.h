#ifndef eepromDataAdjustableH
#define eepromDataAdjustableH

#include "config.h"

const uint8_t eepromData[127] = {

//NOTE: the 128th byte written should be a checksum such that the 1 byte sum
//of all 128 bytes is 0, this array only contains 127 bytes and the programmer is expected to
//calculate automatically (and remember to write it to the EEPROM!)
//Any unused bytes in the EEPROM should be set to 0xFF (at least, that's what Adafruit did)
//Adafruit page: https://learn.adafruit.com/adafruit-tfp401-hdmi-slash-dvi-decoder-to-40-pin-ttl-display/editing-the-edid

//Explanation of EDID standard taken from: http://read.pudn.com/downloads110/ebook/456020/E-EDID%20Standard.pdf

//The original source of this data is kindly provided by Adafruit 
//to support their TFP401 breakout board, one of which was purchased
//during development. All annotations are dpm39

//All changes have had the original saved, marked ADAFRUIT,
//the modified version is marked dpm39 with explanation


//Header
0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, //Start

//Vendor / Product Info
0x04, 0x81, //Manufacturer ID (EISA 3 character ID)
0x04, 0x00, //ID Product Code (Vendor ID code)
0x01, 0x00, 0x00, 0x00, //ID Serial Number 
0x01, //Week of manufacture (binary)
0x11, //Year of manufacture (binary)

//EDID type
0x01, //Version (binary)
0x03, //Revision (binary)

//Basic Display Parameters
0x80, //Video Input Definition
//0x0F, //Max Horizontal Image Size (cm) ADAFRUIT
//0x0A, //Max Vertical Image Size (cm)  ADAFRUIT
0x00, //Max Horizontal Image Size (cm) dpm39 - size only used for text scaling, 0 means undefined, prevents monitor adjusting things
0x00, //Max Vertical Image Size (cm)  dpm39
0x00, //Display Transfer Characteristic (Gamma) (binary)
//0x0A, //Feature Support ADAFRUIT
0x06, //Feature Support dpm39 - bit[4:3] = 10 is for non RGB monitor, changed to 01 for RGB monitor

//Colour Characteristics
0x00, //Red/Green Low Bits
0x00, //Blue/White Low Bits
0x00, //Red-x
0x00, //Red-y
0x00, //Green-x
0x00, //Green-y
0x00, //Blue-x
0x00, //Blue-y
0x00, //White-x
0x00, //White-y

//Established Timings 
0x00, //Established Timings 1
0x00, //Established Timings 2
0x00, //Manufacturer Reserved Timings

//Standard Timing Identification
//the value of 0x01, 0x01 means unused, the only option is detailed timing #1
0x01, 0x01, //Standard Timing Identification 1
0x01, 0x01, //Standard Timing Identification 2
0x01, 0x01, //Standard Timing Identification 3
0x01, 0x01, //Standard Timing Identification 4
0x01, 0x01, //Standard Timing Identification 5
0x01, 0x01, //Standard Timing Identification 6
0x01, 0x01, //Standard Timing Identification 7
0x01, 0x01, //Standard Timing Identification 8

//Detailed Timing Description 1 - only option available
(PIXEL_CLOCK_FREQ & 0xFF), ((PIXEL_CLOCK_FREQ >> 8) & 0xFF), //Pixel clock / 10000 - stored LS Byte first
(HORIZONTAL_ACTIVE & 0xFF), //Horizontal Active Pixels, lower 8 bits
(HORIZONTAL_BLANK & 0xFF), //Horizontal Blanking Pixels - lower 8 bits
((HORIZONTAL_ACTIVE >> 4) & 0xF0) | ((HORIZONTAL_BLANK >> 8) & 0x0F), //Upper nibble: upper 4 bits of Horizontal Active, Lower nibble, upper 4 bits of Horizontal Blankin
(VERTICAL_ACTIVE & 0xFF), //Vertical Active Lines, lower 8 bits
(VERTICAL_BLANK & 0xFF), //Vertical Blanking Lines, lower 8 bits
((VERTICAL_ACTIVE >> 4) & 0xF0) | ((VERTICAL_BLANK >> 8) & 0x0F), //Upper nibble: upper 4 bits of Vertical Active, Lower nibble, upper 4 bits of Vertical Blanking
0x00, //Horizontal Sync Offset (pixels from blanking starts, lower 8 bits)
HSYNC_WIDTH & 0xFF, //Horizontal Sync Pulse Width (pixels, lower 8 bits)
VSYNC_WIDTH & 0x0F, //Upper nibble: lines, lower 4 bits of Vertical Sync Offset, Lower nibble: lines, lower 4 bits of Vertical Sync Pulse Width
((HSYNC_WIDTH >> 4) & 0x30) | ((VSYNC_WIDTH >> 4) & 0x03), //Two bit pairs containg the upper 2 bits of:
	  //[7:6] - Horizontal Sync Offset, [5:4] - Horizontal Sync Pulse Width
	  //[3:2] - Vertical Sync Offset, [1:0] - Vertical Sync Pulse Width
0x6C, //Horizontal Image size (mm, lower 8 bits)
0x44, //Vertical Image Size (mm,lower 8 bits)
0x00, //Upper nibble: upper 4 bits of Horizontal Image Size, Lower nibble: upper 4 bits of Vertical Image Size
0x00, //Horizontal Border (pixels)
0x00, //Vertical Border (Lines)
0x18, //Flags - see table 3.16-3.18
	  //These correspond to Non interlaced, non-stereo display,
	  //with no audio and active low sync pulses
	

//Detailed Timing Description 2 - not used
0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

//Detailed Timing Description 3 - not used
0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
 
//Detailed Timing Description 4 - not used
0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

//Extension Flag (how many EDID blocks follow)
0x00,

//Checksum (1 byte sum of all 128 bytes shall be 0) 
//0x17 //ADAFRUIT
//dpm39: will calculate whilst programming as can't be bothered manually working it out each time
};

#endif