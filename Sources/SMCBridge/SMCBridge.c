#include "SMCBridge.h"
#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stddef.h>

struct STIXSMC { io_connect_t connection; };
typedef struct { uint8_t major, minor, build, reserved; uint16_t release; } Version;
typedef struct { uint16_t version, length; uint32_t cpu, gpu, memory; } Limits;
typedef struct { uint32_t size, type; uint8_t attributes; } KeyInfo;
typedef struct {
    uint32_t key; Version version; Limits limits; KeyInfo info;
    uint8_t result, status, command; uint32_t index; uint8_t bytes[32];
} Packet;
_Static_assert(sizeof(Packet) == 80, "AppleSMC packet ABI must be 80 bytes");
_Static_assert(offsetof(Packet, bytes) == 48, "AppleSMC payload offset");
static uint32_t fourcc(const char *key) {
    return ((uint32_t)(uint8_t)key[0]<<24) | ((uint32_t)(uint8_t)key[1]<<16) | ((uint32_t)(uint8_t)key[2]<<8) | (uint8_t)key[3];
}
static int32_t call(STIXSMC *s, Packet *in, Packet *out) {
    size_t size = sizeof(*out);
    int32_t result = IOConnectCallStructMethod(s->connection, 2, in, sizeof(*in), out, &size);
    if (result) return result;
    if (size != sizeof(*out) || out->result) return kIOReturnError;
    return 0;
}
static int32_t read_packet(STIXSMC *s, const char *key, Packet *out) {
    if (!s || !key || strlen(key) != 4) return kIOReturnBadArgument;
    Packet in = {0}, info = {0}; in.key = fourcc(key); in.command = 9;
    int32_t result = call(s, &in, &info);
    if (result) return result;
    if (!info.info.size || info.info.size > 32) return kIOReturnUnsupported;
    in.info = info.info; in.command = 5;
    result = call(s, &in, out);
    out->info = info.info; out->key = in.key;
    return result;
}
STIXSMC *stix_smc_open(void) {
    io_service_t device = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!device) return NULL;
    STIXSMC *s = calloc(1, sizeof(*s));
    if (s && IOServiceOpen(device, mach_task_self(), 0, &s->connection)) { free(s); s = NULL; }
    IOObjectRelease(device); return s;
}
void stix_smc_close(STIXSMC *s) { if (s) { IOServiceClose(s->connection); free(s); } }
int32_t stix_smc_read(STIXSMC *s, const char *key, double *value) {
    if (!value) return kIOReturnBadArgument;
    Packet p = {0}; int32_t result = read_packet(s, key, &p); if (result) return result;
    uint32_t t = p.info.type, n = p.info.size; double v;
    if (t == fourcc("flt ") && n == 4) { float f; memcpy(&f, p.bytes, 4); v = f; }
    else if (t == fourcc("fpe2") && n == 2) v = ((p.bytes[0]<<8) | p.bytes[1]) / 4.0;
    else if (t == fourcc("sp78") && n == 2) v = (int16_t)((p.bytes[0]<<8) | p.bytes[1]) / 256.0;
    else if (t == fourcc("ui8 ") && n == 1) v = p.bytes[0];
    else if (t == fourcc("ui16") && n == 2) v = (p.bytes[0]<<8) | p.bytes[1];
    else if (t == fourcc("ui32") && n == 4) v = ((uint32_t)p.bytes[0]<<24) | ((uint32_t)p.bytes[1]<<16) | ((uint32_t)p.bytes[2]<<8) | p.bytes[3];
    else return kIOReturnUnsupported;
    if (!isfinite(v)) return kIOReturnBadArgument;
    *value = v; return 0;
}
int32_t stix_smc_write_fan(STIXSMC *s, const char *key, double value) {
    if (!s || !key || strlen(key) != 4 || !isfinite(value)) return kIOReturnBadArgument;
    int unlock = strcmp(key, "Ftst") == 0;
    int fan = key[0] == 'F' && key[1] >= '0' && key[1] <= '9';
    int mode = fan && (!strcmp(key+2, "Md") || !strcmp(key+2, "md"));
    int target = fan && !strcmp(key+2, "Tg");
    if (!(unlock || mode || target)) return kIOReturnNotPermitted;
    if ((unlock || mode) && value != 0 && value != 1) return kIOReturnBadArgument;
    if (target && (value < 0 || value > 20000)) return kIOReturnBadArgument;
    Packet p = {0}; int32_t result = read_packet(s, key, &p); if (result) return result;
    memset(p.bytes, 0, sizeof(p.bytes));
    if ((unlock || mode) && p.info.size == 1 && p.info.type == fourcc("ui8 ")) p.bytes[0] = (uint8_t)value;
    else if (target && p.info.type == fourcc("flt ") && p.info.size == 4) { float f = (float)value; memcpy(p.bytes, &f, 4); }
    else if (target && p.info.type == fourcc("fpe2") && p.info.size == 2 && value <= 16383) { uint16_t v = (uint16_t)(value*4); p.bytes[0] = v>>8; p.bytes[1] = v & 255; }
    else return kIOReturnUnsupported;
    p.command = 6; Packet out = {0}; return call(s, &p, &out);
}

uint32_t stix_power_will_sleep_message(void) { return kIOMessageSystemWillSleep; }
uint32_t stix_power_can_sleep_message(void) { return kIOMessageCanSystemSleep; }
