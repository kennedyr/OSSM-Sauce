#include <Arduino.h>
#include "MotorMovement.h"
#include "Config.h"
#include "ConfigurationMenu.h"
#include "WebsocketClient.h"
#include "WifiClient.h"
#include "LEDStatus.h"
#include "Ossm.h"


void setup() {
  Serial.begin(115200);
  Serial.flush();

  Config::initializeConfig();
  initializeConfiguration();

  withConfigMenufallback(&connectToWiFi, "Would you like to update the Wifi connection? (y/n)");
  delay(1000);
  withConfigMenufallback(&connectToWebSocketServer, "Would you like to update the WebSocket server address? (y/n)");

  initializeMotor();

  Serial.println("");
  Serial.println("");
  Serial.println(" _____  ___  ___  __  __          ");
  Serial.println("(  _  )/ __)/ __)(  \\/  )        ");
  Serial.println(" )(_)( \\__ \\\\__ \\ )    (      ");
  Serial.println("(_____)(___/(___/(_/\\/\\_)  ____ ");
  Serial.println("/ __)  /__\\  (  )(  )/ __)( ___) ");
  Serial.println("\\__ \\ /(__)\\  )(__)(( (__  )__)");
  Serial.println("(___/(__)(__)(______)\\___)(____) ");
  Serial.println(" Firmware v1.4.3");
  Serial.println("");

  initializeMoveQueue();

  sensorlessHoming();

  delay(400);

  Serial.println("-- OSSM Ready! --");
  sendResponse(CONNECTION);
}


void loop() {
  updateLED();
  updateState();

  delay(1);
}