#include "MotorMovement.h"
#include "Common.h"

void initializeMoveQueue();
void updateState();

// Command Controls
void enqueueMove(StrokeCommand movement);
void initiateLoop(StrokeCommand loopPushInput, StrokeCommand loopPullInput);
void moveToPosition(int positionInput);
void initiateVibrate(Vibration vibrationInput);
void initiateSmoothMove(StrokeCommand smoothMoveInput);
void play(MovementMode movementModeInput);
void play(MovementMode movementModeInput, unsigned long playTimeMsInput);
void pauseNow();
void resetNow();
void initiateHoming(int positionInput);
void setSpeedLimit(int speedLimit);
void setGlobalAcceleration(int acceleration);
void setRangeLimit(RangeLimit rangeLimitInput);
void setHomingSpeed(unsigned long homingSpeedHzInput);
void setHomingTrigger(float homingTriggerInput);
