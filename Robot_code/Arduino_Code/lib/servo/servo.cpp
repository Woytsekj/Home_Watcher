#include "servo.h"

MyServo::MyServo(uint8_t pin) : pin(pin) {}

void MyServo::attach() {
  internalServo.attach(pin); 
}

void MyServo::write(uint8_t angle) {
  internalServo.write(angle);
}