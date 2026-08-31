#include "LEDStatus.h"
#include "Ossm.h"
#include "WebsocketClient.h"

// Global variables
esp_websocket_client_config_t wsConfig;
esp_websocket_client_handle_t wsClient;
const char* websocketAddress;
void setWebsocketAddress(const String& newWebsocketAddress) {
  websocketAddress = newWebsocketAddress.c_str();
}

// Message Handling
void parseBinaryMessage(esp_websocket_event_data_t* data) {
  byte* message = (byte*)data->data_ptr;
  int messageLength = data->data_len;
  CommandType commandType = static_cast<CommandType>(message[0]);

  switch (commandType) {
    // noop
  case RESPONSE:
    return;

  case CONNECTION: {
    sendResponse(CONNECTION);
    return;
  }

  case MOVE: {
    if (messageLength != 10) {
      return;
    }
    StrokeCommand inputMove;
    memcpy(&inputMove, message + 1, 9);
    enqueueMove(inputMove);
    break;
  }

  case LOOP: {
    if (messageLength != 19) {
      return;
    }
    StrokeCommand loopPush;
    memcpy(&loopPush, message + 1, 9);
    StrokeCommand loopPull;
    memcpy(&loopPull, message + 10, 9);
    initiateLoop(loopPush, loopPull);
    break;
  }

  case POSITION: {
    int inputPosition;
    memcpy(&inputPosition, message + 1, 4);
    moveToPosition(inputPosition);
    break;
  }

  case VIBRATE: {
    if (messageLength != 13) {
      return;
    }
    Vibration vibration;
    memcpy(&vibration, message + 1, 12);
    initiateVibrate(vibration);
    break;
  }

  case SMOOTH_MOVE: {
    if (messageLength != 10) {
      return;
    }
    StrokeCommand smoothMoveCommand;
    memcpy(&smoothMoveCommand, message + 1, 9);
    initiateSmoothMove(smoothMoveCommand);
    break;
  }

  case PLAY: {
    unsigned long playTimeMs = 0;
    MovementMode movementMode;
    memcpy(&movementMode, message + 1, 1);
    if (messageLength == 6) {
      memcpy(&playTimeMs, message + 2, 4);
    }
    play(movementMode, playTimeMs);
    break;
  }

  case PAUSE: {
    pauseNow();
    break;
  }

  case RESET: {
    resetNow();
    break;
  }

  case HOMING: {
    int inputPosition;
    memcpy(&inputPosition, message + 1, 4);
    initiateHoming(inputPosition);
    break;
  }

  case SET_SPEED_LIMIT: {
    int speedLimit;
    memcpy(&speedLimit, message + 1, 4);
    setSpeedLimit(speedLimit);
    break;
  }

  case SET_GLOBAL_ACCELERATION: {
    int acceleration;
    memcpy(&acceleration, message + 1, 4);
    setGlobalAcceleration(acceleration);
    break;
  }

  case SET_RANGE_LIMIT: {
    short rangeLimitInput;
    memcpy(&rangeLimitInput, message + 2, 2);
    byte selectedRange = message[1];
    setRangeLimit(rangeLimitInput, selectedRange);
    break;
  }

  case SET_HOMING_SPEED: {
    u32_t homingSpeedInputHz;
    memcpy(&homingSpeedInputHz, message + 1, 4);
    setHomingSpeed(homingSpeedInputHz);
    break;
  }

  case SET_HOMING_TRIGGER: {
    float homingTriggerInput;
    memcpy(&homingTriggerInput, message + 1, 4);
    setHomingTrigger(homingTriggerInput);
    break;
  }

  default:
    break;
  }
}

void slice(const char* str, char* result, size_t start, size_t end) {
    strncpy(result, str + start, end - start);
}

void parseTextMessage(esp_websocket_event_data_t* data) {
  char* message = (char*)data->data_ptr;
  int messageLength = data->data_len;
  if (strncmp(message, "PING", strlen("PING")) == 0) {
    char buf[messageLength + 1];
    strcpy(buf, "PONG");
    char slicedFoo[messageLength] = "";
    slice(message, slicedFoo, 4, messageLength);
    strcat(buf, slicedFoo);
    sendTextResponse(buf, data->data_len);
  }
}


static void websocket_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data) {
  esp_websocket_event_data_t* data = (esp_websocket_event_data_t*)event_data;
  switch (event_id) {
  case WEBSOCKET_EVENT_CONNECTED:
    Serial.println("Connected to WebSocket Server");
    setLEDStatus(LED_CONNECTED);  // Update LED status
    sendResponse(CONNECTION);
    break;
  case WEBSOCKET_EVENT_DISCONNECTED:
    Serial.println("Disconnected from WebSocket Server");
    setLEDStatus(LED_ERROR);  // Update LED status
    break;
  case WEBSOCKET_EVENT_DATA:
    if (data->op_code == 1) {
      parseTextMessage(data);
    } else if (data->op_code == 2) {
      parseBinaryMessage(data);
    }
    break;
  }
}


// Connect
bool connectToWebSocketServer() {
  setLEDStatus(LED_CONNECTING);

  Serial.println("Connecting to: ");
  Serial.println(websocketAddress);

  wsConfig = { .uri = websocketAddress };
  wsClient = esp_websocket_client_init(&wsConfig);

  if (wsClient) {
    Serial.println("WebSocket client initialized");
  } else {
    Serial.println("Failed to initialize WebSocket client");
    setLEDStatus(LED_ERROR);
    return false;
  }

  esp_websocket_client_start(wsClient);
  esp_websocket_register_events(wsClient, WEBSOCKET_EVENT_ANY, websocket_event_handler, (void*)wsClient);

  // Wait for connection with LED feedback
  int attempts = 50; // 5 seconds
  while (attempts > 0 && !esp_websocket_client_is_connected(wsClient)) {
    delay(100);
    updateLED();
    attempts--;
  }

  if (esp_websocket_client_is_connected(wsClient)) {
    Serial.println("WebSocket client connected successfully");
    setLEDStatus(LED_CONNECTED);
    esp_websocket_client_send_text(wsClient, "Hello WebSocket", strlen("Hello WebSocket"), portMAX_DELAY);

    return true;
  }
  Serial.println("Failed to connect to WebSocket server");
  setLEDStatus(LED_ERROR);
  return false;
}


// Message Sending
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
