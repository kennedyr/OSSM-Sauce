#ifndef WEBSOCKETCLIENT_H
#define WEBSOCKETCLIENT_H

#include "Common.h"
#include "esp_websocket_client.h"

enum WebsocketStatus {
  WS_CONNECTED,
  WS_DISCONNECTED,
  WS_NOT_INITIALIZED
};

struct Response {
  CommandType commandType = RESPONSE;
  CommandType responseType;
};

void setWebsocketAddress(const String& newWebsocketAddress);
WebsocketStatus getWebsocketStatus();
// Configuration and connection functions
bool connectToWebSocketServer();

void sendTextResponse(char* message, int messageSize);
void sendResponse(CommandType responseCommand);

#endif