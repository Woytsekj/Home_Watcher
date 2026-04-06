#include <Arduino.h>
#include <SoftPWM.h>
#include "motors.h"
#include "servo.h"

// LED stuff (not really important)
#define PIN_B 11
#define PIN_R 12
#define PIN_G 13

// Decided it was not needed
// IR stuff 
// #define IR_RIGHT 7
// #define IR_LEFT 8

// Servo stuff
#define SERVO_PIN 6
#define SERVO_MIN_ANGLE 30
#define SERVO_MAX_ANGLE 150
int currentAngle = 80; // Start at the middle position
int angleStep = 10; // Step size for each command
MyServo servo(SERVO_PIN);



// Battery stuff
#define BATTERY_PIN A3
unsigned long lastBatteryTime = 0;
unsigned long lastIRTime = 0;
unsigned long currentbatteryLevel = 0;
const long batteryInterval = 60000; // 60 seconds
const long IRInterval = 1000; // 1 second

// This function reads the battery voltage
float batteryGetVoltage() {
  // Reads the analog value from the battery pin
  int adcValue = analogRead(BATTERY_PIN);
  // Converts the analog value to voltage
  float adcVoltage = adcValue / 1023.0 * 5 * 2;
  // Rounds the voltage to two decimal places
  float batteryVoltage = int(adcVoltage * 100) / 100.0;
  return batteryVoltage;
}

// This function calculates the battery percentage based on its voltage
uint8_t batteryGetPercentage() {
  float voltage = batteryGetVoltage();  // Gets the battery voltage
  // Maps the voltage to a percentage.
  int16_t temp = map(voltage, 6.6, 8.4, 0, 100);
  // Ensures the percentage is between 0 and 100
  uint8_t percentage = max(min(temp, 100), 0);
  return percentage;
}



// --- Command Dcitionary ---
struct Command {
  const char* name;
  void (*function)();
};

void doForward() { carForward(80); }
void doBackward() { carBackward(80); }
void doTurnLeft() { carTurnLeft(80); }
void doTurnRight() { carTurnRight(80); }
void doStop() { carStop(); }  
void doLEDOn() {
  SoftPWMSet(PIN_R, 255);
  SoftPWMSet(PIN_G, 255);
  SoftPWMSet(PIN_B, 255);
}
void doLEDOff() {
  SoftPWMSet(PIN_R, 0);
  SoftPWMSet(PIN_G, 0);
  SoftPWMSet(PIN_B, 0);
}
void doServoDown() {
  currentAngle += angleStep;
  currentAngle = constrain(currentAngle, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);
  servo.write(currentAngle);
}
void doServoUp() {
  currentAngle -= angleStep;
  currentAngle = constrain(currentAngle, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);
  servo.write(currentAngle);
}
void giveBatteryLevel() {
  uint8_t pct = batteryGetPercentage();
  Serial.print("BATT:");
  Serial.println(pct);
}

Command commandList[] = {
  {"moveForward", doForward},
  {"moveBackward", doBackward},
  {"turnLeft", doTurnLeft},
  {"turnRight", doTurnRight},
  {"stop", doStop},
  {"LED_ON", doLEDOn},
  {"LED_OFF", doLEDOff},
  {"SERVO_UP", doServoUp},
  {"SERVO_DOWN", doServoDown},
  {"requestBatteryLevel", giveBatteryLevel}
};

const int commandCount = sizeof(commandList) / sizeof(Command);
// --- End Command Dictionary ---

void setup() {
  // Start Serial at 115200 baud to make sure it can talk to the ESP32
  // REMINDER: Unplug the ESP32 when uploading this code
  Serial.begin(115200);
  delay(2000); // Wait for the ESP32 from being a sleepy boy
  pinMode(BATTERY_PIN, INPUT);
  // pinMode(IR_RIGHT, INPUT);
  // pinMode(IR_LEFT, INPUT);
  
  SoftPWMBegin();
  SoftPWMSet(PIN_B, 0); // Blue off
  SoftPWMSet(PIN_R, 0); // Red off
  SoftPWMSet(PIN_G, 0); // Green off

  SoftPWMSetFadeTime(PIN_B, 100, 100); // 100ms fade time for Blue
  SoftPWMSetFadeTime(PIN_R, 100, 100); // 100ms fade time for Red
  SoftPWMSetFadeTime(PIN_G, 100, 100); // 100ms fade time for Green

  servo.write(currentAngle); // Start at the middle position
  servo.attach();
}

void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - lastBatteryTime >= batteryInterval) {
    lastBatteryTime = currentMillis;
    if (currentbatteryLevel != batteryGetPercentage()) {
      currentbatteryLevel = batteryGetPercentage();
       // Format: "BATT:85"
      uint8_t pct = batteryGetPercentage();
      Serial.print("BATT:");
      Serial.println(pct);
    }
  }

  // int rightIR = digitalRead(IR_RIGHT);
  // int leftIR = digitalRead(IR_LEFT);

  // if (rightIR == 0 && leftIR == 1) {
  //   if (currentMillis - lastIRTime >= IRInterval) {
  //     lastIRTime = currentMillis;
  //     Serial.println("wallRIGHT");
  //   }
  // } else if (rightIR == 1 && leftIR == 0) {
  //   if (currentMillis - lastIRTime >= IRInterval) {
  //     lastIRTime = currentMillis;
  //     Serial.println("wallLEFT");
  //   }
  // } else if (rightIR == 0 && leftIR == 0) {
  //   if (currentMillis - lastIRTime >= IRInterval) {
  //     lastIRTime = currentMillis;
  //      Serial.println("wallFRONT");
  //   }
  // }

  if (Serial.available()) {
    // Expect format: "255,100,50"
    String command = Serial.readStringUntil('\n');
    command.trim();

    if (command.length() == 0) return;

    if (command.indexOf(',') > 0) {
      // This is an RGB command, so we need to parse the values.
      int firstComma = command.indexOf(',');
      int secondComma = command.indexOf(',', firstComma + 1);

      if (firstComma > 0 && secondComma > 0) {
        int r = command.substring(0, firstComma).toInt();
        int g = command.substring(firstComma + 1, secondComma).toInt();
        int b = command.substring(secondComma + 1).toInt();

        SoftPWMSet(PIN_R, r);
        SoftPWMSet(PIN_G, g);
        SoftPWMSet(PIN_B, b);
      }
      return; // Exit early since we've handled the RGB command
    }

    // Go through the command list and execute the matching command
    bool matchFound = false;
    for (int i = 0; i < commandCount; i++) {
      if (command == commandList[i].name) {
        commandList[i].function();
        matchFound = true;
        break;
      }
    }
    if (!matchFound) {
      // Serial.print("Unknown command: ");
      // Serial.println(command);
    }
  
  }
}
