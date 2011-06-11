#include <WiFly.h>

byte desktopIp[] = {192, 168, 0, 100};
Client client(desktopIp, 80);

//tilt switch variables
int tiltSwitchPin = 5;

//SHT15 variables
int sht15TempCmd = 0b00000011;
int sht15HumidCmd = 0b00000101;
int sht15DataPin = 4;
int sht15ClockPin = 2;
int sht15TemperatureVal;
int sht15HumidityVal;
int currentTemperatureInF;
int currentTemperatureInC;
int currentHumidityInPercent;
int ack;

//Photoresistor variables
int lightSensorPin = 0;
int lightADCReading;
double lastLightADCReading = -1;

//event variables
byte temperatureUpperThresholdReachedEvent = 0;
byte lightsOnEvent = 1;
byte lightsOffEvent = 2;
byte doorOpenEvent = 3;
byte doorClosedEvent = 4;
byte humidityLowerThresholdReachedEvent = 5;
byte temperatureBackToNormalEvent = 6;
byte humidityBackToNormalEvent = 7;
boolean isTemperatureUpperThresholdReachedEventReported = false;
boolean isHumidityLowerThresholdReachedEventReported = false;
boolean isDoorOpenEventReported = false;

void setup() {
  //Serial init for debugging
  Serial.begin(9600);
  //WiFi init
  SpiSerial.begin();
 
  //exit CMD mode if not already done
  SpiSerial.println("");
  SpiSerial.println("exit");
  delay(1000);
 
  //set into CMD mode
  SpiSerial.print("$$$");
  delay(1000);

  //set <authorization level (have a look into wifly docs)>
  SpiSerial.println("set w a #");
  delay(1000);

  //set <password>
  SpiSerial.println("set w p ###");
  delay(1000);
 
  //set localport
  SpiSerial.println("set i l 80");
  delay(1000);
 
  //disable *HELLO* default message on connect
  SpiSerial.println("set comm remote 0");
  delay(1000);

  //join wifi network <ssid>
  SpiSerial.println("join ###"); 
  delay(5000);
 
  //exit CMD mode
  SpiSerial.println("exit"); 
  delay(1000);
 
 digitalWrite(tiltSwitchPin, HIGH);
}


void loop() {
  listenForEvents();
}

void listenForEvents() {
  
  //-----------------------
  //Check tilt switch state
  //-----------------------
  if(digitalRead(tiltSwitchPin) == HIGH) {
    if(!isDoorOpenEventReported && client.connect()) {
      Serial.println("door is open");
      client.write(doorOpenEvent);
      client.stop();
      isDoorOpenEventReported = true;
    }
  } else {
    if(isDoorOpenEventReported && client.connect()) {
      Serial.println("door is closed");
      client.write(doorClosedEvent);
      client.stop();
      isDoorOpenEventReported = false;
    }
  }
  //-----------------------
  
  //-----------------------
  //Check temperature
  //-----------------------
  sendCommandSHT(sht15TempCmd, sht15DataPin, sht15ClockPin);
  waitForResultSHT(sht15DataPin);
  sht15TemperatureVal = getData16SHT(sht15DataPin, sht15ClockPin);
  skipCrcSHT(sht15DataPin, sht15ClockPin);
  //Get more precise temperature by combining temperature readings of both sensors
  currentTemperatureInF = -40.2 + 0.018 * sht15TemperatureVal;
  currentTemperatureInC = -40.1 + 0.01 * sht15TemperatureVal;
  
  Serial.print("currentTemperatureInC: ");
  Serial.println(currentTemperatureInC, DEC);
  
  if(currentTemperatureInC > 26) {
    if (!isTemperatureUpperThresholdReachedEventReported && client.connect()) {
       client.write(temperatureUpperThresholdReachedEvent);
       isTemperatureUpperThresholdReachedEventReported = true;
       client.stop();
     } 
  } else if(currentTemperatureInC < 27) {
    if (isTemperatureUpperThresholdReachedEventReported && client.connect()) {
       client.write(temperatureBackToNormalEvent);
       isTemperatureUpperThresholdReachedEventReported = false;
       client.stop();
     } 
  }
  //-----------------------

  //-----------------------
  //Check humidity
  //-----------------------
  sendCommandSHT(sht15HumidCmd, sht15DataPin, sht15ClockPin);
  waitForResultSHT(sht15DataPin);
  sht15HumidityVal = getData16SHT(sht15DataPin, sht15ClockPin);
  skipCrcSHT(sht15DataPin, sht15ClockPin);
  currentHumidityInPercent = -4.0 + 0.0405 * sht15HumidityVal + -0.0000028 * sht15HumidityVal * sht15HumidityVal;
  
  Serial.print("currentHumidityInPercent: ");
  Serial.println(currentHumidityInPercent, DEC);
  
  if(currentHumidityInPercent < 60) {
    if (!isHumidityLowerThresholdReachedEventReported && client.connect()) {
       client.write(humidityLowerThresholdReachedEvent);
       isHumidityLowerThresholdReachedEventReported = true;
       client.stop();
     } 
  } else if (currentHumidityInPercent > 59) {
    if(isHumidityLowerThresholdReachedEventReported && client.connect()) {
       client.write(humidityBackToNormalEvent);
       isHumidityLowerThresholdReachedEventReported = false;
       client.stop();
     }
  }
  //-----------------------
  
  //-----------------------
  //Check light
  //-----------------------
  lightADCReading = analogRead(lightSensorPin);
  
  Serial.print("lightADCReading: ");
  Serial.println(lightADCReading, DEC);
  
  if(lastLightADCReading < 0) {
    lastLightADCReading = lightADCReading;
  }
  if((lightADCReading > lastLightADCReading + 300) && client.connect()) {
    client.write(lightsOnEvent);
    client.stop();
  } else if((lightADCReading < lastLightADCReading - 300) && client.connect()) {
    client.write(lightsOffEvent);
    client.stop();
  }
  lastLightADCReading = lightADCReading;
  //-----------------------
  
  delay(1000);
}

void sendCommandSHT(int command, int dataPin, int clockPin)
{
  // Transmission Start
  pinMode(dataPin, OUTPUT);
  pinMode(clockPin, OUTPUT);
  digitalWrite(dataPin, HIGH);
  digitalWrite(clockPin, HIGH);
  digitalWrite(dataPin, LOW);
  digitalWrite(clockPin, LOW);
  digitalWrite(clockPin, HIGH);
  digitalWrite(dataPin, HIGH);
  digitalWrite(clockPin, LOW);

  // The command (3 msb are address and must be 000, and last 5 bits are command)
  shiftOut(dataPin, clockPin, MSBFIRST, command);

  // Verify we get the correct ack
  digitalWrite(clockPin, HIGH);
  pinMode(dataPin, INPUT);
  ack = digitalRead(dataPin);
  if (ack != LOW){
  }
  digitalWrite(clockPin, LOW);
  ack = digitalRead(dataPin);
  if (ack != HIGH){
  }
}

void waitForResultSHT(int dataPin)
{
  int i;

  pinMode(dataPin, INPUT);

  for(i= 0; i < 200; ++i)
  {
    delay(5);
    ack = digitalRead(dataPin);

    if (ack == LOW)
      break;
  }

  if (ack == HIGH){
  }
  //Serial.println("Ack Error 2");
}

int getData16SHT(int dataPin, int clockPin)
{
  int val;

  // Get the most significant bits
  pinMode(dataPin, INPUT);
  pinMode(clockPin, OUTPUT);
  val = shiftIn(dataPin, clockPin, 8);
  val *= 256;

  // Send the required ack
  pinMode(dataPin, OUTPUT);
  digitalWrite(dataPin, HIGH);
  digitalWrite(dataPin, LOW);
  digitalWrite(clockPin, HIGH);
  digitalWrite(clockPin, LOW);

  // Get the least significant bits
  pinMode(dataPin, INPUT);
  val |= shiftIn(dataPin, clockPin, 8);

  return val;
}

void skipCrcSHT(int dataPin, int clockPin)
{
  // Skip acknowledge to end trans (no CRC)
  pinMode(dataPin, OUTPUT);
  pinMode(clockPin, OUTPUT);

  digitalWrite(dataPin, HIGH);
  digitalWrite(clockPin, HIGH);
  digitalWrite(clockPin, LOW);
}