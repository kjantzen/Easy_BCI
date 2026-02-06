//code for recieving digital triggers from an external
//serial and sending them to the modified BYB 
//single channel EEG
//This code was written for a XIAO RP2040
//UART 
//K.J. Jantzen, 2024
//
#include <Adafruit_NeoPixel.h>

#define NUMPIXELS 1

const int LED_POWER = 11;
const int LED_PIN = 12;
const int TRIG_PIN_1 = 0;
const int TRIG_PIN_2 = 1;
byte commandByte;
byte trigVal;
byte currentBaseByte = 0;
unsigned long color[3];
unsigned long triggerDuration = 10;
unsigned long triggerOnsetTime = 0;

bool haveTrigger = false;

Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);

void setup() {

  //set up the neo pixel
  pixels.begin();
  pinMode(LED_POWER, OUTPUT);
  digitalWrite(LED_POWER, HIGH);

  color[0] = pixels.Color(0, 0, 255);
  color[1] = pixels.Color(255, 0, 0);
  color[2] = pixels.Color(0, 255, 0);

  // put your setup code here, to run once:
  pinMode(TRIG_PIN_1, OUTPUT);
  pinMode(TRIG_PIN_2, OUTPUT);
  Serial.begin(9600);
}
void loop() {
  if (Serial.available()) {
    commandByte = Serial.read();

    digitalWrite(TRIG_PIN_1, (commandByte & 1));
    digitalWrite(TRIG_PIN_2, (commandByte & 2));
    triggerOnsetTime = millis();
    haveTrigger = true;

    //mask out all but the first two bits since
    //that is all we can use anyway
    trigVal = commandByte & 3;
    pixels.setPixelColor(0, color[trigVal - 1]);
    pixels.show();
  }

  if (haveTrigger && ((millis() - triggerOnsetTime) > triggerDuration)) {
    unsigned long d = millis() - triggerOnsetTime;
    haveTrigger = false;
    digitalWrite(TRIG_PIN_1, 0);
    digitalWrite(TRIG_PIN_2, 0);
    pixels.clear();
    pixels.show();
  }
}
