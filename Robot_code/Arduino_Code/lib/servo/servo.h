#ifndef __SERVO_H__
#define __SERVO_H__ 

#include <Arduino.h>
#include <Servo.h>

class MyServo { // Renamed to avoid conflict with the library class name
  private:
    uint8_t pin;
    Servo internalServo; 

  public:
    MyServo(uint8_t pin);
    void attach();
    void write(uint8_t angle);
};

#endif // __SERVO_H__