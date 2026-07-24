#include "LEDStatus.h"

// RGB LED variables
CRGB leds[NUM_LEDS];
unsigned long lastLEDUpdate = 0;
uint8_t breatheValue = 0;
bool breatheDirection = true;
uint8_t ledBrightness = 25; // 0-255, adjust as needed

// LED status tracking
LEDStatus currentLEDStatus = LED_OFF;

void initializeLED() {
  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.setBrightness(ledBrightness);
  setLEDColor(COLOR_OFF);
}

void setLEDColor(CRGB color) {
  leds[0] = color;
  FastLED.show();
}

void updateLED() {
  unsigned long now = millis();

  switch (currentLEDStatus) {
  case LED_OFF:
    setLEDColor(COLOR_OFF);
    break;

  case LED_WAITING_CONFIG:
    // Breathing blue effect
    if (now - lastLEDUpdate >= 20) { // Update every 20ms for smooth breathing
      if (breatheDirection) {
        breatheValue += 2;
        if (breatheValue >= 255) {
          breatheValue = 255;
          breatheDirection = false;
        }
      } else {
        breatheValue -= 2;
        if (breatheValue <= 30) { // Don't go completely dark
          breatheValue = 30;
          breatheDirection = true;
        }
      }

      leds[0] = CRGB(0, 0, breatheValue); // Blue breathing
      FastLED.show();
      lastLEDUpdate = now;
    }
    break;

  case LED_CONFIG_MODE:
    // Pulsing purple
    if (now - lastLEDUpdate >= 500) { // 500ms pulse
      static bool pulseState = false;
      pulseState = !pulseState;
      setLEDColor(pulseState ? COLOR_CONFIG : COLOR_OFF);
      lastLEDUpdate = now;
    }
    break;

  case LED_CONNECTING:
    setLEDColor(COLOR_CONNECTING);
    break;

  case LED_CONNECTED:
    // Quick green flash sequence then off
    if (now - lastLEDUpdate < 200) {
      setLEDColor(COLOR_CONNECTED);
    } else if (now - lastLEDUpdate < 400) {
      setLEDColor(COLOR_OFF);
    } else if (now - lastLEDUpdate < 600) {
      setLEDColor(COLOR_CONNECTED);
    } else if (now - lastLEDUpdate < 2000) {
      setLEDColor(COLOR_OFF);
    } else {
      lastLEDUpdate = now; // Reset for next cycle
    }
    break;

  case LED_ERROR:
    // Flashing red
    if (now - lastLEDUpdate >= 300) { // 300ms flash
      static bool errorState = false;
      errorState = !errorState;
      setLEDColor(errorState ? COLOR_ERROR : COLOR_OFF);
      lastLEDUpdate = now;
    }
    break;
  }
}

void setLEDStatus(LEDStatus status) {
  currentLEDStatus = status;
  lastLEDUpdate = millis(); // Reset timing for new status
  breatheValue = 30;        // Reset breathing animation
  breatheDirection = true;
}
