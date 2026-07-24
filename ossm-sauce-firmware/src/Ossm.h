#include "MotorMovement.h"
#include "CommandType.h"

void initializeMoveQueue();
void updateState();

// Command Controls
void enqueueMove(StrokeCommand movement);
void initiateLoop(StrokeCommand loopPushInput, StrokeCommand loopPullInput);
void moveToPosition(uint32_t positionInput);
void initiateVibrate(Vibration vibrationInput);
void initiateSmoothMove(StrokeCommand smoothMoveInput);
void play(MovementMode movementModeInput);
void play(MovementMode movementModeInput, unsigned long playTimeMsInput);
void pauseNow();
void resetNow();
void initiateHoming(uint32_t positionInput);
void setSpeedLimit(int speedLimit);
void setGlobalAcceleration(int acceleration);
void setRangeLimit(short rangeLimitInput, byte selectedRange);
void setHomingSpeed(uint32_t homingSpeedHzInput);
void setHomingTrigger(float homingTriggerInput);
