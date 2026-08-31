#ifndef COMMON_H
#define COMMON_H

#include "Arduino.h"

enum CommandType:byte {
    RESPONSE,
    MOVE,
    LOOP,
    POSITION,
    VIBRATE,
    PLAY,
    PAUSE,
    RESET,
    HOMING,
    CONNECTION,
    SET_SPEED_LIMIT,
    SET_GLOBAL_ACCELERATION,
    SET_RANGE_LIMIT,
    SET_HOMING_SPEED,
    SET_HOMING_TRIGGER,
    SMOOTH_MOVE,  // 0x0F
};

enum Direction { IN, OUT };

enum EaseType: byte {
    EASE_IN,
    EASE_OUT,
    EASE_IN_OUT,
    EASE_OUT_IN
};

enum TransType:byte {
    TRANS_LINEAR,
    TRANS_SINE,
    TRANS_CIRC,
    TRANS_EXPO,
    TRANS_QUAD,
    TRANS_CUBIC,
    TRANS_QUART,
    TRANS_QUINT
};

enum LoopPhase { PUSH, PULL };

enum MovementMode:byte {
    MODE_IDLE,
    MODE_HOMING,
    MODE_MOVE,
    MODE_POSITION,
    MODE_LOOP,
    MODE_VIBRATE,
    MODE_SMOOTH_MOVE,
};

struct StrokeCommand {
    unsigned long endTimeMs;
    short depth;
    TransType transType;
    EaseType easeType;
    byte auxiliary;
    long targetPosition;
    unsigned long playTimeStartedMs;
    float durationReciprocal;
    unsigned long baseSpeedHz;
    bool active;
};

struct Vibration {
    int duration;
    unsigned long halfPeriodMs;
    unsigned short position;
    byte rangePercent;
    byte speedScaling;
    int origin;
    int crest;
    Direction direction;
    float movementSpeed;
    bool timed;
    unsigned long endMs;
    unsigned long currentMs;
    int targetPosition;
};

enum RangeLimitType { MIN_RANGE, MAX_RANGE };

#endif