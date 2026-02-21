#ifndef MOTORS_H
#define MOTORS_H

#include <Arduino.h>

/*
 *  [0]--|||--[1]
 *   |         |
 *   |         |
 *  [0]       [1]
 *   |         |
 *   |         |
 *  [0]-------[1]
 */

 // Define motor pins and directions
#define MOTOR_PINS   (uint8_t[4]){2, 3, 4, 5} // Pins for the motors
#define MOTOR_DIRECTIONS (uint8_t[2]){0,1}

void carBegin();
void carSetMotors(int8_t power0, int8_t power1);
void carForward(int8_t power);
void carBackward(int8_t power);
void carTurnLeft(int8_t power);
void carTurnRight(int8_t power);
void carStop();


#endif // MOTORS_H