#ifndef WIFI_PORTAL_H
#define WIFI_PORTAL_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

bool has_saved_wifi_creds(void);

void get_saved_wifi_creds(char *ssid, char *pass);

void start_wifi_setup_portal(void);

void clear_wifi_creds(void);

#ifdef __cplusplus
}
#endif

#endif // WIFI_PORTAL_H