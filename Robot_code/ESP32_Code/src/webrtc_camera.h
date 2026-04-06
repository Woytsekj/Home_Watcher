#ifndef WEBRTC_CAMERA_H
#define WEBRTC_CAMERA_H

#include "esp_err.h"
#include "mqtt_client.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t init_camera(void);

void webrtc_init(esp_mqtt_client_handle_t mqtt_client);

void webrtc_handle_signaling_message(const char* json_string, int len);

#ifdef __cplusplus
}
#endif

#endif // WEBRTC_CAMERA_H