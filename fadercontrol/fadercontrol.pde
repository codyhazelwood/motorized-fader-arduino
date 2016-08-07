/* -----------------------------------------------------------------------
 * Programmer:   Cody Hazelwood
 * Date:         March 20, 2012
 * Platform:     Arduino Uno
 * Description:  Calibrates a motorized fader's max and min
 *               position.  Allows changing the position with an
 *               external potentiometer.  Uses a capacitance
 *               sensing circuit for touch sensitivity.
 *               More or less a proof of concept to be used in a future
 *               project.
 * Dependencies: CapSense Arduino Library (for fader touch sensitivity)
 *               http://www.arduino.cc/playground/Main/CapSense
 * -----------------------------------------------------------------------
 * Copyright (c) 2012 Cody Hazelwood
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 * -----------------------------------------------------------------------
 */

#include <CapSense.h>         //Library for fader touch sensitivity

//Arduino Pin Assignments
const int motorDown    = 3;   //H-Bridge control to make the motor go down
const int motorUp      = 5;   //H-Bridge control to make the motor go up

//Inputs
const int wiper        = 0;   //Position of fader relative to GND (Analog 0)
const int pot          = 3;   //Potentiometer to set position of fader (Analog 3)
const int touchSend    = 7;   //Send pin for Capacitance Sensing Circuit (Digital 7)
const int touchReceive = 8;   //Receive pin for Capacitance Sensing Circuit (Digital 8)

//Variables
double faderMax        = 0;   //Value read by fader's maximum position (0-1023)
double faderMin        = 0;   //Value read by fader's minimum position (0-1023)

CapSense touchLine     = CapSense(touchSend, touchReceive);

volatile bool touched  = false; //Is the fader currently being touched?

void setup() {
    pinMode (motorUp, OUTPUT);
    pinMode (motorDown, OUTPUT);

    calibrateFader();
}

void loop() {
    int state = analogRead(pot);    //Read the state of the potentiometer
    checkTouch();                   //Checks to see if the fader is being touched

    if (state < analogRead(wiper) - 10 && state > faderMin && !touched) {
        digitalWrite(motorDown, HIGH);
        while (state < analogRead(wiper) - 10 && !touched) {};  //Loops until motor is done moving
        digitalWrite(motorDown, LOW);
    }
    else if (state > analogRead(wiper) + 10 && state < faderMax && !touched) {
        digitalWrite(motorUp, HIGH);
        while (state > analogRead(wiper) + 10 && !touched) {}; //Loops until motor is done moving
        digitalWrite(motorUp, LOW);
    }
}

//Calibrates the min and max position of the fader
void calibrateFader() {
    //Send fader to the top and read max position
    digitalWrite(motorUp, HIGH);
    delay(250);
    digitalWrite(motorUp, LOW);
    faderMax = analogRead(wiper);

    //Send fader to the bottom and read max position
    digitalWrite(motorDown, HIGH);
    delay(250);
    digitalWrite(motorDown, LOW);
    faderMin = analogRead(wiper);
}

//Check to see if the fader is being touched
void checkTouch() {
    touched = touchLine.capSense(30) > 700;  //700 is arbitrary and may need to be changed
                                             //depending on the fader cap used (if any).
}
