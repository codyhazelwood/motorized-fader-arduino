/* -----------------------------------------------------------------------
 * Programmer:   Cody Hazelwood
 * Date:         May 17, 2012
 * Platform:     Arduino Uno
 * Description:  MIDI controller using a motorized fader and an Arduino
 * Dependencies: CapSense Arduino Library (for fader touch sensitivity)
 *               http://www.arduino.cc/playground/Main/CapSense
 *               MIDI Library for Arduino
 *               http://www.arduino.cc/playground/Main/MIDILibrary
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
 * -----------------------------------------------------------------------
 */

 /************************************************************************
  *   Currently known issues:
  *
  *   *  Only DAW Channels 1-8 work right now
  *   *  Better Fader Calibration is needed
  *   *  Doesn't work with Pro Tools due to Avid's restrictions (but any
  *         other DAW that supports Mackie Control without HUI support will
  *         work fine (Cubase, Logic, Digital Performer, Live, etc.)
  *
  *************************************************************************/

#include <CapSense.h>         //Library for fader touch sensitivity
#include <MIDI.h>             //Library for receiving MIDI messages

//Arduino Pin Assignments
const int motorDown    = 5;   //H-Bridge control to make the motor go down
const int motorUp      = 6;   //H-Bridge control to make the motor go up

//Inputs
const int wiper        = 0;   //Position of fader relative to GND (Analog 0)
const int touchSend    = 7;   //Send pin for Capacitance Sensing Circuit (Digital 7)
const int touchReceive = 8;   //Receive pin for Capacitance Sensing Circuit (Digital 8)

//Variables
double   faderMax        = 0;     //Value read by fader's maximum position (0-1023)
double   faderMin        = 0;     //Value read by fader's minimum position (0-1023)
int      faderChannel    = 1;     //Value from 1-8
bool     touched         = false; //Is the fader currently being touched?
bool     positionUpdated = false; //Since touching, has the MIDI position been updated?

CapSense touchLine     = CapSense(touchSend, touchReceive);

void setup() {
    MIDI.begin(MIDI_CHANNEL_OMNI);  //Receive messages on all MIDI channels
    MIDI.turnThruOff();             //We don't need MIDI through for this

    pinMode (motorUp, OUTPUT);
    pinMode (motorDown, OUTPUT);

    calibrateFader();

    attachInterrupt(0, nextChannel, RISING);
    attachInterrupt(1, prevChannel, RISING);
}

void loop() {
    /* If there is a MIDI message waiting, and it is for the currently selected
       fader, and it is a PitchBend message (used for fader control), then convert
       the PitchBend value and update the fader's current position.  */
    if (MIDI.read() && MIDI.getChannel() == faderChannel && MIDI.getType() == PitchBend ) {
        /* Bitwise math to take two 7 bit values for the PitchBend and convert to
           a single 14 bit value.  Then converts it to value between 0 and 1023
           to control the fader. */
        int value = (((MIDI.getData2() << 7) + MIDI.getData1()) * 0.0625);
        updateFader(value);
    }

    checkTouch();  //Checks to see if the fader is being touched

    //If the fader has been touched, it needs to update the position on the MIDI host
    if (!positionUpdated) {
        updateFaderMidi();
        positionUpdated = true;
    }
}

void updateFaderMidi() {
    int  velocity    = faderPosition();
    byte channelData = 0xE0 + (faderChannel - 1);
                                             // MIDI Message:
    Serial.write(channelData);               //  E(PitchBend)  Channel (0-9)
    Serial.write(velocity & 0x7F);           //  Least Sig Bits of Data
    Serial.write((velocity >> 7) & 0x7F);    //  Most  Sig Bits of Data
}

//Calibrates the min and max position of the fader
void calibrateFader() {
    //Send fader to the top and read max position
    digitalWrite(motorUp, HIGH);
    delay(250);
    digitalWrite(motorUp, LOW);
    faderMax = analogRead(wiper) - 5;

    //Send fader to the bottom and read min position
    digitalWrite(motorDown, HIGH);
    delay(250);
    digitalWrite(motorDown, LOW);
    faderMin = analogRead(wiper) + 5;
}

//Returns a MIDI pitch bend value for the fader's current position
//Cases ensure that there is a -infinity (min) and max value despite possible math error
int faderPosition() {
    int position = analogRead(wiper);
    int returnValue = 0;

    if (position <= faderMin) {
        returnValue = 0;
    }
    else if (position >= faderMax) {
        returnValue = 16383;
    }
    else {
        returnValue = ((float)(position - faderMin) / (faderMax - faderMin)) * 16383;
    }

    return returnValue;
}

//Check to see if the fader is being touched
void checkTouch() {
    //For the capSense comparison below,
    //700 is arbitrary and may need to be changed
    //depending on the fader cap used (if any).

    if (!touched && touchLine.capSense(30) >= 700) {
        touched = true;

        //Send MIDI Touch On Message
        Serial.write(0x90);
        Serial.write(0x67 + faderChannel);
        Serial.write(0x7f);
    }
    else if (touched && touchLine.capSense(30) < 700) {
        touched = false;

        //Send MIDI Touch Off Message
        Serial.write(0x90);
        Serial.write(0x67 + faderChannel);
        Serial.write((byte) 0x00);
    }

    if (touched) {
        positionUpdated = false;
    }
}

//Function to move fader to a specific position between 0-1023 if it's not already there
void updateFader(int position) {
    if (position < analogRead(wiper) - 10 && position > faderMin && !touched) {
        digitalWrite(motorDown, HIGH);
        while (position < analogRead(wiper) - 10 && !touched) {};  //Loops until motor is done moving
        digitalWrite(motorDown, LOW);
    }
    else if (position > analogRead(wiper) + 10 && position < faderMax && !touched) {
        digitalWrite(motorUp, HIGH);
        while (position > analogRead(wiper) + 10 && !touched) {}; //Loops until motor is done moving
        digitalWrite(motorUp, LOW);
    }
}

//Selects the next channel in the DAW
void nextChannel() {
    static unsigned long last_interrupt0_time = 0;      //Interrupt Debouncing
    unsigned long interrupt0_time = millis();           //Interrupt Debouncing

    if (interrupt0_time - last_interrupt0_time > 200) { //Interrupt Debouncing
        if (faderChannel < 8) {
            faderChannel++;

            Serial.write(0x90);
            Serial.write(0x17 + faderChannel);
            Serial.write(0x7f);                         //Note On
            Serial.write(0x90);
            Serial.write(0x17 + faderChannel);
            Serial.write((byte) 0x00);                    //Note Off
        }
    }

    last_interrupt0_time = interrupt0_time;             //Interrupt Debouncing
}

//Selects the previous channel in the DAW
void prevChannel() {
    static unsigned long last_interrupt1_time = 0;      //Interrupt Debouncing
    unsigned long interrupt1_time = millis();           //Interrupt Debouncing

    if (interrupt1_time - last_interrupt1_time > 200) { //Interrupt Debouncing
        if (faderChannel > 1) {
            faderChannel--;

            Serial.write(0x90);
            Serial.write(0x17 + faderChannel);
            Serial.write(0x7f);                         //Note On
            Serial.write(0x90);
            Serial.write(0x17 + faderChannel);
            Serial.write((byte) 0x00);                    //Note Off
        }
    }

    last_interrupt1_time = interrupt1_time;             //Interrupt Debouncing
}
