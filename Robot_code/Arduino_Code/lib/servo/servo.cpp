#include "servo.h"

Servo::Servo(uint8_t pin) : pin(pin), angle(0) {}

void Servo::attach() {
  SoftPWMSet(pin, 0); // Initialize the pin with 0% duty cycle
}

void Servo::write(uint8_t angle) {
  this->angle = angle;
  // Map the angle (0-180) to a duty cycle (0-255)
  uint8_t dutyCycle = map(angle, 0, 180, 0, 255);
  SoftPWMSet(pin, dutyCycle);
}
