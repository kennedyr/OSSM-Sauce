#include "WebsocketClient.h"
#include "LEDStatus.h"

// Global variables
esp_websocket_client_config_t wsConfig;
esp_websocket_client_handle_t wsClient;
String websocketAddress;

bool connectToWebSocketServer() {
  currentLEDStatus = LED_CONNECTING;

  Serial.println("Connecting to: " + websocketAddress);

  wsConfig = { .uri = websocketAddress.c_str() };
  wsClient = esp_websocket_client_init(&wsConfig);

  if (wsClient) {
    Serial.println("WebSocket client initialized");
  } else {
    Serial.println("Failed to initialize WebSocket client");
    currentLEDStatus = LED_ERROR;
    return false;
  }

  // Note: Event handler should be registered in main.cpp after calling this function
  esp_websocket_client_start(wsClient);

  // Wait for connection with LED feedback
  int attempts = 50; // 5 seconds
  while (attempts > 0 && !esp_websocket_client_is_connected(wsClient)) {
    delay(100);
    updateLED();
    attempts--;
  }

  if (esp_websocket_client_is_connected(wsClient)) {
    Serial.println("WebSocket client connected successfully");
    currentLEDStatus = LED_CONNECTED;
    esp_websocket_client_send_text(wsClient, "Hello WebSocket", strlen("Hello WebSocket"), portMAX_DELAY);

    return true;
  } else {
    Serial.println("Failed to connect to WebSocket server");
    currentLEDStatus = LED_ERROR;
    return false;
  }
}

void register_event_handler(esp_event_handler_t websocket_event_handler) {
  esp_websocket_register_events(wsClient, WEBSOCKET_EVENT_ANY, websocket_event_handler, (void*)wsClient);
}

void sendTextResponse(char* message, int messageSize) {
  esp_websocket_client_send_text(wsClient, message, messageSize, portMAX_DELAY);
}

void sendResponse(CommandType responseCommand) {
  Response responseMessage;
  int messageSize = sizeof(responseMessage);
  responseMessage.responseType = responseCommand;
  char message[messageSize];
  memcpy(message, (char*)&responseMessage, messageSize);
  esp_websocket_client_send_bin(wsClient, message, messageSize, portMAX_DELAY);
}
