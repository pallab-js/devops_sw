/// SMC (System Management Controller) bridge for reading fan speed and thermal metrics.
/// Uses IOKit to communicate with the AppleSMC service.

#include <IOKit/IOKitLib.h>
#include <stdio.h>
#include <string.h>
#include "SMCBridge.h"

static io_connect_t conn = 0;

static UInt32 _strToFourCC(const char *str) {
    UInt32 val = 0;
    memcpy(&val, str, 4);
    return val;
}

static float _readSMCFloat(UInt32 fourCC) {
    if (!conn) return -1;

    SMCParamStruct input = {0};
    SMCParamStruct output = {0};

    input.key = fourCC;
    input.data8 = kSMCGetKeyInfo;

    size_t inputSize = sizeof(input);
    size_t outputSize = sizeof(output);

    kern_return_t kr = IOConnectCallStructMethod(
        conn, kSMCHandleYPCEvent,
        &input, inputSize, &output, &outputSize
    );
    if (kr != kIOReturnSuccess) return -1;

    input.key = fourCC;
    input.cmd.dataSize = output.cmd.dataSize;
    input.cmd.dataType = output.cmd.dataType;
    input.data8 = kSMCReadKey;

    kr = IOConnectCallStructMethod(
        conn, kSMCHandleYPCEvent,
        &input, inputSize, &output, &outputSize
    );
    if (kr != kIOReturnSuccess) return -1;

    return *((float *)output.bytes);
}

int SMCBridgeOpen(void) {
    if (conn) return 0;

    io_service_t service = IOServiceGetMatchingService(
        kIOMainPortDefault,
        IOServiceMatching("AppleSMC")
    );
    if (!service) return -1;

    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &conn);
    IOObjectRelease(service);
    return (kr == kIOReturnSuccess) ? 0 : -1;
}

void SMCBridgeClose(void) {
    if (conn) {
        IOServiceClose(conn);
        conn = 0;
    }
}

float SMCBridgeReadFanSpeed(int fanIndex) {
    char key[5];
    snprintf(key, sizeof(key), "F%dAc", fanIndex);
    return _readSMCFloat(_strToFourCC(key));
}

int SMCBridgeGetFanCount(void) {
    float count = _readSMCFloat(_strToFourCC("FNum"));
    return (count >= 0) ? (int)count : 0;
}

float SMCBridgeReadCPUTemperature(void) {
    return _readSMCFloat(_strToFourCC("TC0p"));
}

float SMCBridgeReadGPUProximity(void) {
    return _readSMCFloat(_strToFourCC("TG0p"));
}
