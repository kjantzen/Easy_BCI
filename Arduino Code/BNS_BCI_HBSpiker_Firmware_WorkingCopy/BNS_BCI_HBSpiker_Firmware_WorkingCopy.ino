// WWU BNS BCI firmware for BYB HBSpikerBox
// KJ Jantzen
// V0.1 - Feb - 2023
// ALlows for operation in two modes: Continuous mode streams data to the host
// at 250 Hz.  Single trial mode collects data into an internal buffer and 
// transmits a single trial of data on reciept of a TTL signal on the 
// expansion pins D9 & D11.
// In single trial mode, the maximum buffer size at 500 Hz is 1.5 seconds
// The user defined pre and post stimulus portions of the trial must not 
// exceed this maximum
// 
// Based on:
// Heart & Brain based on ATMEGA 328 (UNO)
// V1.0
// Made for Heart & Brain SpikerBox (V0.62)
// Backyard Brains
// Stanislav Mircic
// https://backyardbrains.com/
//
//This code has been modified to read a single analog channel and 2 digital channels at Fs=1000
//the channels combined into 3 bytes

#define CURRENT_SHIELD_TYPE "HWT:HBLEOSB;"
#define FIRMEWARE_VERSION "BNS_HBSpikerV0.1"
#define RAW_BUFFER_SIZE 100
#define SIZE_OF_COMMAND_BUFFER 30  //command buffer max size
#define TRIAL_BUFFER_MAX_SAMPLES 600
#define SAMPLE_RATE 250

// defines for setting and clearing register bits
#ifndef cbi
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#endif
#ifndef sbi
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
#endif

#define POWER_LED_PIN 13
#define TRIG_BIT0 9   //digital input pin 9
#define TRIG_BIT1 11  //digital input pin 11

#define ESCAPE_SEQUENCE_LENGTH 6
#define TRIG_LED 7

/// Interrupt number - very important in combination with bit rate to get accurate data
//KJ  - the interrupt (configured below) will trigger an interrupt whenever the value in the timer reaches this number
//KJ - It is clear that the base clock rate (16 * 10^6) is being divided by the sample rate to get the number of clock ticks between samples
//KJ - I am guessing that the same rate is multiplied by 8 to account for the prescaling applied below?
//KJ - I am not sure why the actual value used by BYB is 198 instead of 199
// Output Compare Registers  value = (16*10^6) / (Fs*8) - 1  set to 1999 for 1000 Hz sampling, set to 3999 for 500 Hz sampling, set to 7999 for 250Hz sampling, 199 for 10000 Hz Sampling
#define INTERRUPT_NUMBER 3999

const byte MODE_LED[2] = {5, 7};

//buffer position variables
int head = 0;  //head index for sampling circular buffer
int tail = 0;  //tail index for sampling circular buffer
int prestimSamples = 30;  //defualt pre stim sample #
int pststimSamples = 300; //default post stim sample #
int circBufferHead = 0;
int trialBufferHead = prestimSamples;

int erpTrialSampleLength = prestimSamples + pststimSamples;

char commandBuffer[SIZE_OF_COMMAND_BUFFER];  //receiving command buffer
byte rawBuffer[2][RAW_BUFFER_SIZE];              //Sampling buffer
//byte circBuffer[2][prestimSamples];
//byte trialBuffer[2][pststimSamples];
byte trialBuffer[2][TRIAL_BUFFER_MAX_SAMPLES];

bool circBufferIsFull = false;
bool trialBufferIsFull = false;
bool haveTriggerSignal = false;
byte eventMarker = 0;

const byte MODE_CONTINUOUS = 0;
const byte MODE_TRIAL = 1;
byte collectionMode = MODE_CONTINUOUS;

//bytes for characters "trial onset" which identify erp packet
byte trialHeader[11] = { 116, 114, 105, 97, 108, 32, 111, 110, 115, 101, 116 };

int digPin0 = 0;           //KJ - these will be used to store the digital inputs read on each sample
int digPin1 = 0;
int commandMode = 0;  //flag for command mode. Don't send data when in command mode

//SETUP function
void setup() {
  Serial.begin(115200);  //Serial communication baud rate (alt. 115200)
  while (!Serial)
  delay(1);
  Serial.println(FIRMEWARE_VERSION);
  Serial.setTimeout(2);

  //KJ-set the mode of the AM modulation and power LED pints to output
  pinMode(POWER_LED_PIN, OUTPUT);
  pinMode(TRIG_BIT0, INPUT);  //setup the two digital input trigger pins
  pinMode(TRIG_BIT1, INPUT);

  //KJ-turn on the power LED
  digitalWrite(POWER_LED_PIN, HIGH);

  //on board VU meter LEDs
  pinMode(2, OUTPUT);
  pinMode(3, OUTPUT);
  pinMode(4, OUTPUT);
  pinMode(5, OUTPUT);
  pinMode(6, OUTPUT);
  pinMode(7, OUTPUT);
  pinMode(8, OUTPUT);

  signalMode();
  configureTimers(); 
}

void loop() {
  //check to see if there is any incoming commnands on the serial buffer
  checkForCommands();

  //handle any data that is currently in the raw buffer
  while (head != tail && commandMode != 1) 
  {
    if (collectionMode == MODE_CONTINUOUS) {
      Serial.write(rawBuffer[0][tail]);
      Serial.write(rawBuffer[1][tail]);
      tail++;
    } else if (collectionMode == MODE_TRIAL) {
      
      if (trialBufferIsFull) {
        compileAndSendTrial();
        //digitalWrite(TRIG_LED, LOW);
        resetTrialBuffers();

      } else {
        if (haveTriggerSignal && circBufferIsFull) {
          //digitalWrite(TRIG_LED, HIGH); //signal the onset of trial collection
          trialBuffer[0][trialBufferHead] = rawBuffer[0][tail];
          trialBuffer[1][trialBufferHead] = rawBuffer[1][tail];
          trialBufferHead++;
          tail++;
          if (trialBufferHead == erpTrialSampleLength){
            trialBufferIsFull = true;
          }
        } else {
          trialBuffer[0][circBufferHead] = rawBuffer[0][tail];
          trialBuffer[1][circBufferHead] = rawBuffer[1][tail];  
          tail++;        
          //check for an event marker
          if (circBufferIsFull) {
            haveTriggerSignal = checkForEventMarker(trialBuffer[0][circBufferHead]);
          }
          circBufferHead++;
          if (circBufferHead == prestimSamples) {
            circBufferIsFull = true;
            circBufferHead = 0;
          }
        }
      }
    }
    if (tail >= RAW_BUFFER_SIZE) {
      tail = 0;
    }
  }
}

//function to check if the passed sample byte contains
//an event marker that is non zero
bool checkForEventMarker(byte sample){
  bool returnVal = false;
  eventMarker = (sample & 96) >> 5;
  if (eventMarker > 0){
    returnVal = true;
  }
  return returnVal;
}

//this is the callback function called when the interrupt fires
ISR(TIMER1_COMPA_vect) {
  //10bit ADC we will split every sample to 2 bytes
  //First byte contains 3 most significant bits and second byte contains 7 least significat bits.
  //First bit in high byte always be 1, marking begining of the 2 byte data frame
  

  int tempSample = analogRead(A0);
  //read digital input 
  digPin0 = digitalRead(TRIG_BIT0);
  digPin1 = digitalRead(TRIG_BIT1);
  int digEvent = (digPin1 << 1) + digPin0;

  //write the samples to the LEDs
  digitalWrite(2, digPin0);
  digitalWrite(3, digPin1);

  //shift the upper byte to the right, set the MSB to high (Ox80) and add in the event marker
  //into the second and third bit
  rawBuffer[0][head] = (tempSample >> 7) | 0x80 | (digEvent << 5);
  rawBuffer[1][head] = tempSample & 0x7F;  //create a byte with the lower 7 bits
  //advance the pointer
  head++;
  if (head == RAW_BUFFER_SIZE) {
    head = 0;
  }
}

//reset the flags and location pointers in the single trial storage buffers
void resetTrialBuffers(){
  circBufferHead = 0;
  trialBufferHead = prestimSamples;
  trialBufferIsFull = false;
  circBufferIsFull = false;
  haveTriggerSignal = false;
  head = 0;
  tail = 0;
}

//read serial input from host computer and change parameters accordingly
void checkForCommands() {
  if (Serial.available() > 0) {
    int paramValue = -1;
    int tl = pststimSamples;
    int ptl = prestimSamples;

    commandMode = 1;  //flag that we are receiving commands through serial
    String inString = Serial.readStringUntil('\n');
  
    //convert string to null terminate array of chars
    inString.toCharArray(commandBuffer, SIZE_OF_COMMAND_BUFFER);
    commandBuffer[inString.length()] = 0;

    // breaks string str into a series of commands using delimiter ";"
    char* command = strtok(commandBuffer, ";");
  
    while (command != 0) {
      // Split the command in name and value components
      char* separator = strchr(command, ':');
   
      if (separator != 0) {

        *separator = 0;
        --separator;

        switch (*separator) {
          /*case 'c':
            //disable setting # of channels
            separator = separator + 2;
            numberOfChannels = 1;  //atoi(separator);//read number of channels
            break;*/
          case 's':
            //disable setting sample rate
            //for changing the sample rate, which we will not actually ever do
            break;
          case 'm':
            //set the operation mode
            separator = separator + 2;
            paramValue = atoi(separator);
            if ((paramValue == MODE_CONTINUOUS) || (paramValue == MODE_TRIAL)) {
              collectionMode = paramValue;
              signalMode();
              Serial.print("mode set: ");
              Serial.println(paramValue);
            }
            break;
          case 't':
            separator = separator + 2;
            paramValue = atoi(separator);
            if ((paramValue > 0) && (paramValue < (TRIAL_BUFFER_MAX_SAMPLES-1))) {
              tl = paramValue;
            }
            break;
          case 'p':
            //set the pre stim length
            separator = separator + 2;
            paramValue = atoi(separator);
            if ((paramValue > 0) && (paramValue < (TRIAL_BUFFER_MAX_SAMPLES-1))) {
              ptl = paramValue;
            }
            break;
        }
      }

      // Find the next command in input string
      command = strtok(0, ";");
    }
    //set up new buffers
    if ((tl+ptl)<TRIAL_BUFFER_MAX_SAMPLES) {
        prestimSamples = ptl;
        pststimSamples = tl;
        erpTrialSampleLength = prestimSamples + pststimSamples;
        resetTrialBuffers();
    }
    commandMode = 0;
  }
}

//signal a change in the current collection state using LEDs
void signalMode() {

  digitalWrite(MODE_LED[0], LOW);
  digitalWrite(MODE_LED[1], LOW);
  for (int i = 0; i < 3; i++) {
    digitalWrite(MODE_LED[collectionMode], LOW);
    delay(50);
    digitalWrite(MODE_LED[collectionMode], HIGH);
    delay(50);
  }
}

//configure resgiters on ATMEGA to set correct timing and to fire an interrupt 
//at the desired sample interval
void configureTimers() {  
  /* TIMER SETUP- the timer interrupt allows precise timed measurements of the read switch
  for more info about configuration of arduino timers see http://arduino.cc/playground/Code/Timer1 
  I spent alot of time figure out what each of these calls does and know I will forget so I added
  an obnoxious number of comments*/

  cli();  //stop interrupts

  //Make ADC sample faster. Change ADC clock
  //Change prescaler division factor to 16 ,- (KJ) I am not sure why this is done - it does not factor into the calculation of sample rate
  //which are still based on the base 16MHz clock speed - probably because the timer is running in CTC mode?
  //KJ - the first 3 bits of the ADCSRA register control the prescale value
  //KJ - 100 (bits 2,1,0 respectively) is a prescale or division factor of 16
  sbi(ADCSRA, ADPS2);  //1
  cbi(ADCSRA, ADPS1);  //0
  cbi(ADCSRA, ADPS0);  //0

  //KJ - this just initializes things
  TCCR1A = 0;  // set entire TCCR1A register to 0
  TCCR1B = 0;  // same for  TCCR1B
  TCNT1 = 0;   //initialize counter value to 0;

  //KJ - assign our clock tick number to the output compare register
  //KJ - this register holds the value that will be compared against the clock count (TCNT1)
  //KJ - many things can happen when they match depending on the mode and flags that are set
  OCR1A = INTERRUPT_NUMBER;  // Output Compare Registers

  // turn on CTC mode
  //KJ - CTC is Clear Timer on Compare Match
  // in CTC mode the timer counter (TCNT1 in our case) is reset when it reaches the number of samples in the OCR1A register
  //this is used to set the sample frequency to an exact desired value
  //and generate an interrupt when the number of samples is reached
  TCCR1B |= (1 << WGM12);

  // Set CS11 bit for 8 prescaler
  //KJ - a prescaler value of 8 is being set which will sample at fclk/8 or fs=2x10^8
  TCCR1B |= (1 << CS11);

  // enable timer compare interrupt
  //KJ this line sets the OCIE pin for output compare register A which enables
  //KJ - the interrupt when a match occurs
  //KJ - this indicates that an interrupt will fire when the value at OCR1A equals the nunber of ticks since the last interrupt
  TIMSK1 |= (1 << OCIE1A);

  //this enables interrupts generally by setting the interrupt flag in the status register
  sei();  //allow interrupts

  //END TIMER SETUP
  //KJ - this is the same as the line above and I have no idea what it is doing
  //TIMSK1 |= (1 << OCIE1A);
}

void compileAndSendTrial() {
  int ii = 0, readLoc = 0;

  //transmit the entire packet one byte at a time
  for (ii = 0; ii < int(sizeof(trialHeader)); ii++) {
    Serial.write(trialHeader[ii]);
  }

  Serial.write(eventMarker);
  //send 16 bit values on byte at a time
  Serial.write(((SAMPLE_RATE) >> 8) & 0xFF);         // Send the upper byte first
  Serial.write((SAMPLE_RATE) & 0xFF);                // Send the lower byte
  Serial.write(((prestimSamples * 2) >> 8) & 0xFF);  // Send the upper byte first
  Serial.write((prestimSamples * 2) & 0xFF);         // Send the lower byte
  Serial.write(((pststimSamples * 2) >> 8) & 0xFF);   // Send the upper byte first
  Serial.write((pststimSamples * 2) & 0xFF);          // Send the lower byte

  //read the ring buffer
  readLoc = circBufferHead;  // oldest point in the ring buffer
  ii = 0;
  //send the raw value payload
  while (ii < prestimSamples) {
    //Serial.write(circBuffer[0][readLoc]);
    //Serial.write(circBuffer[1][readLoc]);
    Serial.write(trialBuffer[0][readLoc]);
    Serial.write(trialBuffer[1][readLoc]);
    readLoc++;
    ii++;
    if (readLoc == prestimSamples) {
      readLoc = 0;
    }
  }
  //add the post stimulus data
  readLoc = prestimSamples;
  while (ii < erpTrialSampleLength) {
    Serial.write(trialBuffer[0][readLoc]);
    Serial.write(trialBuffer[1][readLoc]);
    //erpTrial[ii * 2] = trialBuffer[0][readLoc];
    //erpTrial[ii * 2 + 1] = trialBuffer[1][readLoc];
    ii++;
    readLoc++;
  }
  //add a carriage return and line feed for making it easy without
  //knowing the trial length
  Serial.println(""); 
}

