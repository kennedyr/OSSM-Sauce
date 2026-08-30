#include "LEDStatus.h"
#include "WifiClient.h"

String ssid;
String password;

bool connectToWiFi() {
  WiFi.mode(WIFI_STA);
  currentLEDStatus = LED_CONNECTING;

  Serial.println("");
  Serial.println("-- CONNECTING TO WIFI --");
  Serial.println("--     PLEASE WAIT    --");
  Serial.println("");

  WiFi.begin(ssid.c_str(), password.c_str());

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
      currentLEDStatus = LED_ERROR;
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
      currentLEDStatus = LED_CONNECTED;
      delay(500);
      currentLEDStatus = LED_OFF;
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
      currentLEDStatus = LED_ERROR;
      return false;
    }
    numberOfTries--;
  }
}
