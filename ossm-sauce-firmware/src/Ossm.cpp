#include "Arduino.h"
#include "Common.h"
#include "Configuration.h"
#include "Ossm.h"
#include "WebsocketClient.h"


unsigned long playStartTime;
unsigned long playTimeMs;

StrokeCommand activeMove;

StrokeCommand loopPush;
StrokeCommand loopPull;

QueueHandle_t moveQueue;
const char moveQueueSize = 50;
bool moveQueueIsEmpty = true;

int previousTargetPosition;

StrokeCommand smoothMoveCommand;
unsigned long smoothMoveStartTime;
bool smoothMoveActive = false;


void initializeMoveQueue() {
  moveQueue = xQueueCreate(moveQueueSize, 9);
}

void moveStart() {
  activeMove.active = false;
  short lastTargetDepth = activeMove.depth;
  if (!xQueueReceive(moveQueue, &activeMove, (TickType_t)10))
    Serial.println("ERROR: Queue empty.");

  // start of next path
  if (activeMove.endTimeMs == 0 && uxQueueSpacesAvailable(moveQueue) < moveQueueSize) {
    playTimeMs = 0;
    playStartTime = millis();
  } else if (activeMove.endTimeMs == 0 || activeMove.depth == lastTargetDepth) {
    return;
  }

  // if activeMove has already expired, recurse
  if (playTimeMs >= activeMove.endTimeMs) {
    Serial.println("WARN: Queued move already expired.");
    moveStart();
  }

  short constrainedPosition = constrain(activeMove.depth, 0, 10000);
  activeMove.targetPosition = map(constrainedPosition, 0, 10000, rangeLimitUserMin, rangeLimitUserMax);
  activeMove.playTimeStartedMs = playTimeMs;
  unsigned long durationMs = activeMove.endTimeMs - activeMove.playTimeStartedMs;
  activeMove.durationReciprocal = 1.0 / durationMs;
  activeMove.baseSpeedHz = getMoveBaseSpeedHz(activeMove, durationMs);
  activeMove.active = true;
}

void enqueueMove(StrokeCommand movement) {
  if (movementMode == MODE_HOMING) {
    return;
  }

  if (!xQueueSend(moveQueue, &movement, (TickType_t)10)) {
    Serial.println("ERROR: Failed to add move command to queue. Is queue full?");
    return;
  }

  if (moveQueueIsEmpty) {
    moveStart();
  }
  moveQueueIsEmpty = false;
}

void initiateLoop(StrokeCommand loopPushInput, StrokeCommand loopPullInput) {
  if (movementMode == MODE_HOMING) {
    return;
  }

  if (loopPushInput.endTimeMs != 0) {
    loopPushInput.targetPosition = rangeLimitUserMax;
    loopPushInput.durationReciprocal = 1.0 / loopPushInput.endTimeMs;
    loopPushInput.baseSpeedHz = getMoveBaseSpeedHz(loopPushInput, loopPushInput.endTimeMs, true);
  }
  if (loopPullInput.endTimeMs != 0) {
    loopPullInput.targetPosition = rangeLimitUserMin;
    loopPullInput.durationReciprocal = 1.0 / loopPullInput.endTimeMs;
    loopPullInput.baseSpeedHz = getMoveBaseSpeedHz(loopPullInput, loopPullInput.endTimeMs, true);
  }

  loopPush = loopPushInput;
  loopPull = loopPullInput;
  movementMode = MODE_LOOP;
}

void moveToPosition(int positionInput) {
  if (movementMode != MODE_POSITION) {
    return;
  }

  int constrainedPosition = constrain(positionInput, 0, 10000);
  int targetPosition = map(constrainedPosition, 0, 10000, rangeLimitUserMin, rangeLimitUserMax);
  int positionDelta = targetPosition - previousTargetPosition;
  int currentPosition = stepperGetCurrentPosition();
  bool lockedMin = targetPosition < currentPosition && positionDelta > 0;
  bool lockedMax = targetPosition > currentPosition && positionDelta < 0;
  previousTargetPosition = targetPosition;
  if (lockedMin || lockedMax) {
    return;
  }

  unsigned long speed = abs(positionDelta) * 50;
  stepperSetSpeedInHz(min(speed, globalSpeedLimitHz));
  stepperMoveTo(targetPosition);
  processSafeAccel();
}

void initiateVibrate(Vibration vibrationInput) {
  if (movementMode == MODE_HOMING) {
    return;
  }

  int constrainedPosition = constrain(vibrationInput.position, 0, 10000);
  vibrationInput.origin = map(constrainedPosition, 0, 10000, rangeLimitUserMin, rangeLimitUserMax);
  unsigned long totalRange = abs(rangeLimitUserMax - rangeLimitUserMin);
  unsigned long vibrationRange = vibrationInput.rangePercent * 0.01f * totalRange;
  long vibrationEndpoint = vibrationInput.origin + vibrationRange;
  vibrationInput.crest = constrain(vibrationEndpoint, rangeLimitUserMin, rangeLimitUserMax);

  float halfPeriodReciprocal = 1 / float(vibrationInput.halfPeriodMs);
  unsigned long duration = 1000 * halfPeriodReciprocal;
  float waveformSpeedScaling = vibrationInput.speedScaling * 0.01f;
  unsigned long newSpeed = vibrationRange * duration * waveformSpeedScaling;
  stepperSetSpeedInHz(min(newSpeed, globalSpeedLimitHz));

  vibration = vibrationInput;

  if (vibration.duration > 0) {
    vibration.timed = true;
    vibration.endMs = millis() + vibration.duration;
  } else if (vibration.duration < 0) {
    vibration.timed = false;
  } else {
    movementMode = MODE_IDLE;
    return;
  }

  processSafeAccel();
  movementMode = MODE_VIBRATE;
}

void initiateSmoothMove(StrokeCommand smoothMoveInput) {
  if (movementMode == MODE_HOMING) {
    return;
  }

  short constrainedPosition = constrain(smoothMoveInput.depth, 0, 10000);
  smoothMoveInput.targetPosition = map(constrainedPosition, 0, 10000, rangeLimitUserMin, rangeLimitUserMax);
  smoothMoveInput.endTimeMs = constrain(smoothMoveInput.endTimeMs, 20, 3600000);
  smoothMoveInput.durationReciprocal = 1.0 / smoothMoveInput.endTimeMs;
  smoothMoveInput.baseSpeedHz = getMoveBaseSpeedHz(smoothMoveInput, smoothMoveInput.endTimeMs);

  smoothMoveCommand = smoothMoveInput;
  smoothMoveStartTime = millis();
  smoothMoveActive = true;
  movementMode = MODE_SMOOTH_MOVE;
}

void play(MovementMode movementModeInput) {
  if (movementMode == MODE_HOMING) {
    return;
  }

  movementMode = movementModeInput;
  playStartTime = millis() - playTimeMs;
}

void play(MovementMode movementModeInput, unsigned long playTimeMsInput) {
  if (movementMode == MODE_HOMING) {
    return;
  }

  playTimeMs = playTimeMsInput;
  play(movementModeInput);
}

void pauseNow() {
  if (movementMode == MODE_HOMING) {
    return;
  }

  movementMode = MODE_IDLE;
  stepperStop();
}

void resetNow() {
  if (movementMode == MODE_HOMING) {
    return;
  }

  movementMode = MODE_IDLE;
  playTimeMs = 0;
  xQueueReset(moveQueue);
  moveQueueIsEmpty = true;
}

void initiateHoming(int positionInput) {
  if (movementMode == MODE_HOMING) {
    return;
  }

  int constrainedPosition = constrain(positionInput, 0, 10000);
  homingTargetPosition = map(constrainedPosition, 0, 10000, rangeLimitUserMin, rangeLimitUserMax);
  movementMode = MODE_HOMING;
}

void setSpeedLimit(int speedLimit) {
  globalSpeedLimitHz = max(speedLimit, 0);
}

void setGlobalAcceleration(int acceleration) {
  globalAcceleration = max(acceleration, 0);
}

void setRangeLimit(short rangeLimitInput, RangeLimitType selectedRange) {
  rangeLimitInput = constrain(rangeLimitInput, 0, 10000);
  rangeLimitInput = map(rangeLimitInput, 0, 10000, rangeLimitHardMin, rangeLimitHardMax);
  switch (selectedRange) {
  case MIN_RANGE:
    rangeLimitUserMin = rangeLimitInput;
    break;
  case MAX_RANGE:
    rangeLimitUserMax = rangeLimitInput;
    break;
  }
  if (movementMode == MODE_LOOP) {
    if (loopPush.endTimeMs != 0) {
      loopPush.targetPosition = rangeLimitUserMax;
      loopPush.baseSpeedHz = getMoveBaseSpeedHz(loopPush, loopPush.endTimeMs, true);
    }
    if (loopPull.endTimeMs != 0) {
      loopPull.targetPosition = rangeLimitUserMin;
      loopPull.baseSpeedHz = getMoveBaseSpeedHz(loopPull, loopPull.endTimeMs, true);
    }
  }
}

void setHomingSpeed(unsigned long homingSpeedHzInput) {
  homingSpeedHz = min(globalSpeedLimitHz, homingSpeedHzInput);
}

void setHomingTrigger(float homingTriggerInput) {
  powerAvgRangeMultiplier = constrain(homingTriggerInput, 0.1, 2);
  setPreferenceHomingTrigger(powerAvgRangeMultiplier);
}

void updateState() {
  switch (movementMode) {
  case MODE_MOVE: {
    playTimeMs = millis() - playStartTime;
    if (playTimeMs >= activeMove.endTimeMs) {
      moveStart();
    }
    if (activeMove.active) {
      processStroke(&activeMove, playTimeMs - activeMove.playTimeStartedMs);
    }
    break;
  }

  case MODE_LOOP: {
    playTimeMs = millis() - playStartTime;
    StrokeCommand* loopPhase = (activeLoopPhase == PUSH) ? &loopPush : &loopPull;
    if (playTimeMs <= loopPhase->endTimeMs) {
      processStroke(loopPhase, playTimeMs);
    } else {
      activeLoopPhase = (activeLoopPhase == PUSH) ? PULL : PUSH;
      playStartTime = millis();
    }
    break;
  }

  case MODE_VIBRATE: {
    unsigned long currentMs = millis();
    if (currentMs - vibration.currentMs >= vibration.halfPeriodMs) {
      vibration.currentMs = currentMs;
      vibration.direction = (vibration.direction == IN) ? OUT : IN;
      stepperMoveTo((vibration.direction == IN) ? vibration.origin : vibration.crest);
    }
    if (vibration.timed && currentMs >= vibration.endMs) {
      movementMode = MODE_IDLE;
    }
    break;
  }

  case MODE_HOMING: {
    if (stepperGetCurrentPosition() == homingTargetPosition) {
      movementMode = MODE_IDLE;
      sendResponse(HOMING);
    } else {
      stepperSetSpeedInHz(min(homingSpeedHz, globalSpeedLimitHz));
      stepperMoveTo(homingTargetPosition);
    }
    break;
  }

  case MODE_SMOOTH_MOVE: {
    if (smoothMoveActive) {
      unsigned long elapsed = millis() - smoothMoveStartTime;
      if (elapsed >= smoothMoveCommand.endTimeMs) {
        smoothMoveActive = false;
        movementMode = MODE_IDLE;
        sendResponse(SMOOTH_MOVE);
      } else {
        processStroke(&smoothMoveCommand, elapsed);
      }
    }
    break;
  }

  default:
    break;
  }
}