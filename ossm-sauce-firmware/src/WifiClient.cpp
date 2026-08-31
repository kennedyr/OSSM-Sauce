#include "LEDStatus.h"
#include <WiFi.h>
#include "WifiClient.h"


const char* ssid;
const char* getSSID() {
  return ssid;
}
void setSSID(const String& newSSID) {
  ssid = newSSID.c_str();
}

const char* password;
void setPassword(const String& newPassword) {
  password = newPassword.c_str();
}

bool connectToWiFi() {
  WiFi.mode(WIFI_STA);
  setLEDStatus(LED_CONNECTING);

  Serial.println("");
  Serial.println("-- CONNECTING TO WIFI --");
  Serial.println("--     PLEASE WAIT    --");
  Serial.println("");

  WiFi.begin(ssid, password);

  // Will try for about 10 seconds (20x 500ms)
  int tryDelay = 500;
  int numberOfTries = 20;
  // Wait for the WiFi event
  while (true) {
    switch (WiFi.status()) {
    case WL_NO_SSID_AVAIL:
      Serial.println("[WiFi] SSID not found");
      break;
    case WL_CONNECT_FAILED:
      Serial.print("[WiFi] Failed - WiFi not connected! Reason: ");
      Serial.println(WiFi.status());
      setLEDStatus(LED_ERROR);
      return false;
      break;
    case WL_CONNECTION_LOST:
      Serial.println("[WiFi] Connection was lost");
      break;
    case WL_SCAN_COMPLETED:
      Serial.println("[WiFi] Scan is completed");
      break;
    case WL_DISCONNECTED:
      Serial.println("[WiFi] WiFi is disconnected");
      break;
    case WL_CONNECTED:
      Serial.println("[WiFi] WiFi is connected!");
      Serial.print("[WiFi] IP address: ");
      Serial.println(WiFi.localIP());
      setLEDStatus(LED_CONNECTED);
      delay(500);
      setLEDStatus(LED_OFF);
      return true;
      break;
    default:
      Serial.print("[WiFi] WiFi Status: ");
      Serial.println(WiFi.status());
      break;
    }
    delay(tryDelay);

    if (numberOfTries <= 0) {
      Serial.print("[WiFi] Failed to connect to WiFi!");
      // Use disconnect function to force stop trying to connect
      WiFi.disconnect();
      setLEDStatus(LED_ERROR);
      return false;
    }
    numberOfTries--;
  }
}
