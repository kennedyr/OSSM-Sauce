#pragma once

// Configuration and connection functions
void initializeConfiguration(bool fastBoot = true);
void withConfigMenufallback(bool (*connectFunc)(), const char* message);
