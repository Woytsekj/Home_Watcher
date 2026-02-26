#ifndef __SERVO_H__
#define __SERVO_H__ 

#include <Arduino.h>
#include <SoftPWM.h>

class Servo {
  private:
    uint8_t pin;
    uint8_t angle;

  public:
    Servo(uint8_t pin);
    void attach();
    void write(uint8_t angle);
};

#endif // __SERVO_H__