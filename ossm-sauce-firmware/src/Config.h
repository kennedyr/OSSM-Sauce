#pragma once

#include <Preferences.h>

namespace Config {
    void initializeConfig();
    bool configEnabled();
    Preferences getConfig();
    float getHomingTrigger();
    void setHomingTrigger(float homingTrigger);
    bool getMotorReversed();
}
