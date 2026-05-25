/// SMC (System Management Controller) bridge header.
/// Provides C functions for reading fan speeds and thermal data via IOKit.

#ifndef SMCBridge_h
#define SMCBridge_h

#include <MacTypes.h>

// AppleSMC kernel extension private types (from XNU open source)
typedef struct {
    UInt16 major;
    UInt16 minor;
    UInt16 build;
    UInt16 reserved;
    UInt16 release;
} SMCVersion;

typedef struct {
    UInt8 supported;
    UInt8 version;
    UInt8 length;
    UInt8 reserved;
    char model[32];
} SMCBounds;

typedef struct {
    UInt32 dataSize;
    UInt32 dataType;
    UInt8 dataAttributes;
} SMCCmdStruct;

// SMC parameter structure matching AppleSMC driver interface
typedef struct {
    UInt32 key;
    SMCVersion vers;
    SMCBounds bounds;
    SMCCmdStruct cmd;
    UInt32 polled;
    UInt32 result;
    UInt32 data8;
    UInt32 data32;
    UInt32 unused[4];
    UInt8 bytes[32];
    UInt8 unused2[2];
} SMCParamStruct;

enum {
    kSMCGetKeyInfo = 2,
    kSMCReadKey = 5,
    kSMCHandleYPCEvent = 2,
};

/// Open connection to AppleSMC service. Must be called before any reads.
/// @return 0 on success, -1 on failure.
int SMCBridgeOpen(void);

/// Close the SMC connection.
void SMCBridgeClose(void);

/// Read fan speed for a given fan index (usually 0 or 1).
/// @param fanIndex Fan number (0-based).
/// @return Fan speed in RPM, or -1 on failure.
float SMCBridgeReadFanSpeed(int fanIndex);

/// Get the number of fans.
/// @return Number of fans detected.
int SMCBridgeGetFanCount(void);

/// Read CPU proximity temperature.
/// @return Temperature in degrees Celsius, or -1 on failure.
float SMCBridgeReadCPUTemperature(void);

/// Read GPU proximity temperature (Apple Silicon).
/// @return Temperature in degrees Celsius, or -1 on failure.
float SMCBridgeReadGPUProximity(void);

#endif /* SMCBridge_h */
