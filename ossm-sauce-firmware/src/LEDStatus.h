#ifndef LEDSTATUS_H
#define LEDSTATUS_H

// LED status indicators
enum LEDStatus {
  LED_OFF,
  LED_WAITING_CONFIG, // Breathing blue
  LED_CONFIG_MODE,    // Pulsing purple
  LED_CONNECTING,     // Solid orange
  LED_CONNECTED,      // Green flash sequence
  LED_ERROR           // Flashing red
};

// LED control functions
void initializeLED();
void updateLED();
void setLEDStatus(LEDStatus status);

#endif