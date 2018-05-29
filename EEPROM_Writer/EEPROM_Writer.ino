#include <Wire.h>
#include "eepromData_adjustable.h"

#define EDID_ADDRESS 0x50 //HDMI standard says it needs to be on this address so this should never change
#define EEPROM_SIZE 256 //EEPROM Size in bytes

void panic()
{
	digitalWrite(2, HIGH);
	digitalWrite(4, LOW);
	
	while(1);
}

void i2c_write(uint8_t address, uint8_t data)
{
	Wire.beginTransmission(EDID_ADDRESS);
	Wire.write((byte)address);
	Wire.write((byte)data);
	int x = Wire.endTransmission();
	if(x != 0) panic();
	delay(5);
}



uint8_t i2c_read(uint8_t address)
{
	Wire.beginTransmission(EDID_ADDRESS);
	Wire.write(address);
	Wire.endTransmission();
	Wire.requestFrom(EDID_ADDRESS, 1);
	unsigned long startTime = millis();
	while(!Wire.available())
	{
		if (millis() - startTime > 5000)
			//Device not responding, likely not connected
			panic();
	}
	return Wire.read();
}	


void setup()
{
	//Wanted to do in preprocessor but sizeof not supported
	if (sizeof(eepromData) != 127) panic();		
	Wire.begin();
	pinMode(2, OUTPUT);
	digitalWrite(2, LOW);
	pinMode(4, OUTPUT);
	digitalWrite(4, LOW);
}

void loop()
{
	uint8_t checksum = 0;
	for(int i = 0; i < 127; i++)
	{
		i2c_write(i, eepromData[i]);
		checksum += eepromData[i];
	}

  
	//The 128th (in address 127) byte is a checksum such that the byte wise sum of all 128 bytes is 0
	i2c_write(127, (256 - checksum) & 0xFF);

	
	//Pad rest with 0xFF
	for(int i = 128; i<EEPROM_SIZE; i++)
		i2c_write(i, 0xFF);
	

	
	for(int i = 0; i < 127; i++)
		if(i2c_read(i) != eepromData[i])
				panic();
				
	
	digitalWrite(4, HIGH);
	digitalWrite(2, LOW);
  while(1);

}

