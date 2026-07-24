#ifndef WIFICLIENT_H
#define WIFICLIENT_H

#include <WiFi.h>

extern String ssid;
extern String password;

// Configuration and connection functions
bool connectToWiFi();

#endif