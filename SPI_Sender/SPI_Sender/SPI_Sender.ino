#include <SPI.h>


#define HSYNC 8
#define VSYNC 9
#define CLOCK_SPEED 1 //in MHz


void SPI_write(uint8_t *data, int dataSize)
{

  SPI.beginTransaction(SPISettings(30000000 * CLOCK_SPEED, MSBFIRST, SPI_MODE0));
  
  for(int i = 0; i<(dataSize - 1); i++)
    SPI.transfer(data[i], SPI_CONTINUE);

  SPI.transfer(data[dataSize - 1]);
  digitalWrite(HSYNC, LOW);
  digitalWrite(HSYNC,HIGH);
  SPI.endTransaction();
  
}

volatile bool flag;
uint8_t black[160];
uint8_t white[160];


void setup() 
{

  SPI.begin();
  pinMode(HSYNC, OUTPUT);
  digitalWrite(HSYNC, HIGH);
  pinMode(VSYNC, OUTPUT);
  digitalWrite(VSYNC,HIGH);
  pinMode(VSYNC, OUTPUT);
  digitalWrite(VSYNC,HIGH);
  for(int i = 0; i<160; i++)
  {
    black[i] = 0;
    white[i] = 255;
  }
}

void loop() 
{

    for(int i = 0; i<1280; i++)
      SPI_write(black, 160);
    digitalWrite(VSYNC,LOW);
    digitalWrite(VSYNC, HIGH);

    for(int i = 0; i<1280; i++)
      SPI_write(white, 160);
    digitalWrite(VSYNC,LOW);
    digitalWrite(VSYNC, HIGH);

}
