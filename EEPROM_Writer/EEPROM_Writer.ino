#include <Wire.h>
#include "eepromData_adjustable.h"

#define EDID_ADDRESS 0x50 //HDMI standard says it needs to be on this address so this should never change
#define EEPROM_SIZE 256 //EEPROM Size in bytes

void panic(String message)
{
	while(1)
	{
		Serial.println(message);
		delay(1000);
	}	
}

void i2c_write(uint8_t address, uint8_t data)
{
	Wire.beginTransmission(EDID_ADDRESS);
	Wire.write((byte)address);
	Wire.write((byte)data);
  int x = Wire.endTransmission();
	if(x != 0) panic("I2C Write at address " + String(address) + " failed, error " + String(x));
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
			panic("EEPROM not detected, check connections and reset MCU");
	}
	return Wire.read();
}	


void setup()
{
	//Wanted to do in preprocessor but sizeof not supported
	if (sizeof(eepromData) != 127) panic("EEPROM Data is wrong size");		

	Serial.begin(9600);
	Wire.begin();
	
	Serial.println("EDID EEPROM Writer, dpm39");
}

void loop()
{
	//i2c_read(0); //This will never return and notify user is EEPROM not responding
	
	Serial.println("EEPROM detected");
	Serial.println("\n\nPress any key to flash EEPROM Data...");
 
	while(!Serial.available());

  Serial.println("Flashing data...");
   
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
	
	Serial.println("Data written, begin verification...");
	
	for(int i = 0; i < 127; i++)
		if(i2c_read(i) != eepromData[i])
				panic("Verification failed at address: " + String(i) + " Got: " + String(i2c_read(i)) + " Expected: " + String(eepromData[i]));
				
	
  while(Serial.available()) Serial.read();
	Serial.println("Verification complete");

}

