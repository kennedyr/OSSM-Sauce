#ifndef WEBSOCKETCLIENT_H
#define WEBSOCKETCLIENT_H

#include "Arduino.h"
#include "CommandType.h"
#include "esp_websocket_client.h"

// Global variables
extern esp_websocket_client_handle_t wsClient;

struct Response {
  CommandType commandType = RESPONSE;
  CommandType responseType;
};

void setWebsocketAddress(const String& newWebsocketAddress);

// Configuration and connection functions
bool connectToWebSocketServer();

void sendTextResponse(char* message, int messageSize);
void sendResponse(CommandType responseCommand);

#endif