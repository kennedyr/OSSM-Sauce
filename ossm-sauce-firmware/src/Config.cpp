#include "Common.h"
#include "Config.h"
#include <Preferences.h>

using namespace Config;

Preferences preferences;
const bool enablePreferences = false;

void Config::initializeConfig() {
  preferences.begin("ossm_sauce");
}

bool Config::configEnabled() {
  return enablePreferences;
}

Preferences Config::getConfig() {
  return preferences;
}

float Config::getHomingTrigger() {
  if (enablePreferences) {
    return preferences.getFloat("homing_trigger", DEFAULT_HOMING_TRIGGER);
  }
  return DEFAULT_HOMING_TRIGGER;
}

void Config::setHomingTrigger(float homingTrigger) {
  if (enablePreferences) {
    preferences.putFloat("homing_trigger", homingTrigger);
  }
}

bool Config::getMotorReversed() {
  return enablePreferences && preferences.getBool("motor_reversed", false);
}
