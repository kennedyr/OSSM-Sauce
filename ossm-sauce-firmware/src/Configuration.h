#ifndef CONFIGURATION_H
#define CONFIGURATION_H

#include <Preferences.h>

#define CONFIG_TIMEOUT_MS 5000

// Global variables
const bool enablePreferences = false;
extern Preferences preferences;

// Configuration and connection functions
void initializeConfiguration(boolean fastBoot = true);
bool checkForConfigMode();

// Configuration menu functions
void handleConfigMenu();
void withConfigMenufallback(bool (*connectFunc)(), String message);

#endif