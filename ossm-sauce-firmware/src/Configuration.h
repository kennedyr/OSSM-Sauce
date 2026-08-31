#ifndef CONFIGURATION_H
#define CONFIGURATION_H

void setPreferenceHomingTrigger(float homingTrigger);
bool getPreferenceMotorReversed();

// Configuration and connection functions
void initializeConfiguration(bool fastBoot = true);
void withConfigMenufallback(bool (*connectFunc)(), const char * message);

#endif