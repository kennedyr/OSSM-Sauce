#ifndef WEBSOCKETCLIENT_H
#define WEBSOCKETCLIENT_H

#include "Arduino.h"
#include "CommandType.h"
#include "esp_websocket_client.h"


// Global variables
extern esp_websocket_client_config_t wsConfig;
extern esp_websocket_client_handle_t wsClient;
extern String websocketAddress;

struct Response {
  CommandType commandType = RESPONSE;
  CommandType responseType;
};

// Configuration and connection functions
bool connectToWebSocketServer();
void register_event_handler(esp_event_handler_t websocket_event_handler);

void sendTextResponse(char* message, int messageSize);
void sendResponse(CommandType responseCommand);

#endif