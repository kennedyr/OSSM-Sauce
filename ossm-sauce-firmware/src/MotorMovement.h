#ifndef MOTOR_MOVEMENT_H
#define MOTOR_MOVEMENT_H

#include "Common.h"

extern LoopPhase activeLoopPhase;
extern MovementMode movementMode;
extern Vibration vibration;

extern float powerAvgRangeMultiplier;

extern int rangeLimitHardMin;
extern int rangeLimitHardMax;

extern int rangeLimitUserMin;
extern int rangeLimitUserMax;

extern unsigned long globalSpeedLimitHz;
extern unsigned long globalAcceleration;

extern int homingTargetPosition;
extern unsigned long homingSpeedHz;

void initializeMotor();
void sensorlessHoming();
unsigned long getMoveBaseSpeedHz(StrokeCommand stroke, unsigned long moveDuration, bool useFullUserRange = false);
void processSafeAccel();
void processStroke(StrokeCommand* stroke, unsigned long elapsedTimeMs);

// Stepper pass through
void stepperSetSpeedInHz(unsigned long newSpeed);
void stepperMoveTo(int targetPosition);
void stepperStop();
int stepperGetCurrentPosition();

#endif
