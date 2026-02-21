#include "motors.h"
/** 
 * @file motors.cpp
 * @brief Motor control implementation for the GalaxyRVR project
 * This file contains functions to control the motors of the GalaxyRVR, including
 * initialization, setting
 * 
 * Taken from the glaxyRVR codebase with some stuff ripped out
 * https://github.com/sunfounder/galaxy-rvr/tree/main
*/
#include <Arduino.h>
#include <SoftPWM.h>

#define MOTOR_POWER_MIN 28

/**
 * @brief Motor initialization
 * 
 */

 void carBegin() {
    for (uint8_t i = 0; i < 4; i++) {
        pinMode(MOTOR_PINS[i], OUTPUT);
        SoftPWMSet(MOTOR_PINS[i], 0); // Start with motors off
        SoftPWMSetFadeTime(MOTOR_PINS[i], 100, 100); // 100ms fade time for all motors
    }
}

/**
 * @brief Set movement for both motors
 * 
 * @param power Power for motor 0 (-100 to 100)
 */

void carForward(int8_t power) {carSetMotors(power, power);}
void carBackward(int8_t power) {carSetMotors(-power, -power);}
void carTurnLeft(int8_t power) {carSetMotors(-power, power);}
void carTurnRight(int8_t power) {carSetMotors(power, -power);}
void carStop() {carSetMotors(0, 0);}

/**
 * @brief Set motor power with direction
 * 
 * @param power0 Power for motor 0 (-100 to 100)
 * @param power1 Power for motor 1 (-100 to 100)
 */

 void carSetMotors(int8_t power0, int8_t power1) {
    bool dir[2];
    int8_t power[2] = {power0, power1};
    int8_t newPower[2];

    for (uint8_t i = 0; i < 2; i++) {
    dir[i] = power[i] > 0;

    if (MOTOR_DIRECTIONS[i]) dir[i] = !dir[i];

    if (power[i] == 0) {
        newPower[i] = 0;
    } else {
        newPower[i] = map(abs(power[i]), 0, 100, MOTOR_POWER_MIN, 255);
    }
    SoftPWMSet(MOTOR_PINS[i*2], dir[i] * newPower[i]);
    SoftPWMSet(MOTOR_PINS[i*2+1], !dir[i] * newPower[i]);
  }
 }

