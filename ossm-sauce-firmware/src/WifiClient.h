#ifndef WIFICLIENT_H
#define WIFICLIENT_H

const char* getSSID();
void setSSID(const String& newSSID);
void setPassword(const String& newPassword);
// Configuration and connection functions
bool connectToWiFi();

#endif