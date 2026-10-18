#ifndef STIX_SMC_BRIDGE_H
#define STIX_SMC_BRIDGE_H
#include <stdint.h>
// Opaque SMC connection. Callers serialize access.
typedef struct STIXSMC STIXSMC;
STIXSMC *stix_smc_open(void);
void stix_smc_close(STIXSMC *smc);
uint32_t stix_power_will_sleep_message(void);
uint32_t stix_power_can_sleep_message(void);
int32_t stix_smc_read(STIXSMC *smc, const char *key, double *value);
// Narrow write API: only known fan mode, target and unlock keys are writable.
int32_t stix_smc_write_fan(STIXSMC *smc, const char *key, double value);
#endif
