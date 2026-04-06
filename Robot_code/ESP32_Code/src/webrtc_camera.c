#include "webrtc_camera.h"
#include "esp_camera.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>
#include "cJSON.h"
#include "esp_peer.h"
#include "esp_peer_default.h"

#include "secrets.h"

static const char *TAG = "WEBRTC_CAM";

// Freenove ESP32-WROVER-CAM Pin Configuration
#define CAM_PIN_PWDN -1  
#define CAM_PIN_RESET -1 
#define CAM_PIN_XCLK 21
#define CAM_PIN_SIOD 26
#define CAM_PIN_SIOC 27
#define CAM_PIN_D7 35 
#define CAM_PIN_D6 34 
#define CAM_PIN_D5 39 
#define CAM_PIN_D4 36 
#define CAM_PIN_D3 19 
#define CAM_PIN_D2 18 
#define CAM_PIN_D1 5  
#define CAM_PIN_D0 4  
#define CAM_PIN_VSYNC 25 
#define CAM_PIN_HREF 23  
#define CAM_PIN_PCLK 22  

static esp_mqtt_client_handle_t s_mqtt_client = NULL;
static esp_peer_handle_t peer_handle = NULL;
static volatile bool webrtc_ready = false;
static volatile bool request_engine_reset = false;
static char incoming_offer_sdp[2048] = {0};

/**
 * @brief Handles outgoing messages from the WebRTC engine, identifies if they're SDP answers or ICE candidates, and publishes them to MQTT for the app to receive
 * @param msg 
 * @param arg 
 * @return int 
 */
static int peer_msg_out_handler(esp_peer_msg_t *msg, void *arg) {
    // 1. Add a safety check for msg->size
    if (msg->data == NULL || s_mqtt_client == NULL || msg->size <= 0) return 0;
    
    // 2. Allocate a temporary buffer to safely hold the exact size of the payload, 
    // plus one byte for the null terminator that cJSON expects.
    char *safe_data = (char *)malloc(msg->size + 1);
    if (safe_data == NULL) {
        ESP_LOGE(TAG, "Failed to allocate memory for safe_data");
        return -1;
    }
    
    // Copy the raw bytes and manually null-terminate it
    memcpy(safe_data, msg->data, msg->size);
    safe_data[msg->size] = '\0';

    cJSON *root = cJSON_CreateObject();

    // 3. Use the new safe_data buffer for all your string checks and JSON building
    if (strncmp(safe_data, "v=0", 3) == 0) { 
        ESP_LOGI(TAG, "Identified Full SDP Answer! Publishing to MQTT...");
        cJSON_AddStringToObject(root, "type", "answer");
        cJSON_AddStringToObject(root, "sdp", safe_data);
    } else if (strstr(safe_data, "candidate") != NULL) { 
        cJSON_AddStringToObject(root, "type", "candidate");
        cJSON_AddStringToObject(root, "candidate", safe_data);
    } else {
        free(safe_data);
        cJSON_Delete(root);
        return 0; 
    }

    char *json_str = cJSON_PrintUnformatted(root);
    if (json_str != NULL) {
        esp_mqtt_client_publish(s_mqtt_client, "robotWebRTC/tx", json_str, 0, 1, 0);
        free(json_str);
    }
    
    // 4. Free the temporary buffer and the JSON object
    free(safe_data);
    cJSON_Delete(root);
    return 0; 
}

/**
 * @brief  Handles changes in the WebRTC engine state. When the data channel opens, we set webrtc_ready to true to start sending frames. If it closes or disconnects, we set it back to false to halt the camera.
 * 
 * @param state 
 * @param arg 
 * @return int 
 */
static int peer_state_handler(esp_peer_state_t state, void *arg) {
    ESP_LOGI(TAG, "WebRTC Engine State: %d", (int)state);
    
    if (state == 10) { 
        ESP_LOGI(TAG, "DataChannel Open! Starting video stream...");
        webrtc_ready = true;
    } else {
        // If the state changes to literally anything else (2, 3, etc.), stop the camera!
        ESP_LOGW(TAG, "Peer disconnected or negotiating. Halting video stream.");
        webrtc_ready = false;
    }
    return 0; 
}

/**
 * @brief Handles incoming signaling messages from MQTT, parses them, and sends the relevant info to the WebRTC engine. This is where we get the SDP offer and ICE candidates from the app.
 * 
 * @param json_string 
 * @param len 
 */
void webrtc_handle_signaling_message(const char* json_string, int len) {
    if (peer_handle == NULL) return;

    cJSON *json = cJSON_ParseWithLength(json_string, len);
    if (json != NULL) {
        cJSON *type = cJSON_GetObjectItem(json, "type");
        if (type != NULL && cJSON_IsString(type)) {
            
            if (strcmp(type->valuestring, "offer") == 0) {
                cJSON *sdp = cJSON_GetObjectItem(json, "sdp");
                if (sdp != NULL && cJSON_IsString(sdp)) {
                    ESP_LOGI(TAG, "New WebRTC Offer Received! Flagging for hard reset...");
                    
                    strncpy(incoming_offer_sdp, sdp->valuestring, sizeof(incoming_offer_sdp) - 1);
                    request_engine_reset = true; 
                }
            }
            else if (strcmp(type->valuestring, "candidate") == 0) {
                cJSON *candidate = cJSON_GetObjectItem(json, "candidate");
                if (candidate && cJSON_IsString(candidate)) {
                    esp_peer_msg_t msg_in = {0};
                    msg_in.type = 1; // ESP_PEER_MSG_TYPE_CANDIDATE
                    msg_in.data = (void *)candidate->valuestring;
                    msg_in.size = strlen(candidate->valuestring);
                    esp_peer_send_msg(peer_handle, &msg_in);
                }
            }
        }
        cJSON_Delete(json); 
    }
}

/**
 * @brief Main task that runs the WebRTC engine, captures camera frames, and sends them to the peer when ready
 * 
 * @param pvParameters 
 */
static void webrtc_task(void *pvParameters) {
    ESP_LOGI(TAG, "Starting WebRTC Task...");

    esp_peer_ice_server_cfg_t ice_servers[] = {
        {
            // .stun_url = "stun:stun.l.google.com:19302",
            .stun_url = "stun:ec2-3-149-184-208.us-east-2.compute.amazonaws.com:3478",
            .user = NULL,
            .psw = NULL
        },
        {
            .stun_url = "turn:ec2-3-149-184-208.us-east-2.compute.amazonaws.com:3478",
            .user = SECRET_MQTT_USER,
            .psw = SECRET_MQTT_PASS
        }
    };
    
    esp_peer_cfg_t cfg = {
        .role = ESP_PEER_ROLE_CONTROLLED,
        .on_msg = peer_msg_out_handler, 
        .on_state = peer_state_handler, 
        .enable_data_channel = true,
        .server_lists = ice_servers,
        .server_num = 2
    };
    ESP_ERROR_CHECK(esp_peer_open(&cfg, esp_peer_get_default_impl(), &peer_handle));

    vTaskDelay(pdMS_TO_TICKS(2000)); 
    esp_peer_new_connection(peer_handle); 

    // Keep track of when we last sent a frame
    TickType_t last_frame_time = 0;

    while (1) {
        // Let the WebRTC engine run fast to process heartbeats!
        esp_peer_main_loop(peer_handle);

        if (request_engine_reset) {
            ESP_LOGW(TAG, "Executing Hard Reset of WebRTC Engine...");
            webrtc_ready = false;
            
            // 1. Completely destroy the old, glitchy encryption state
            if (peer_handle != NULL) {
                esp_peer_close(peer_handle);
                peer_handle = NULL;
            }
            
            // 2. Spin up a brand new, clean engine
            esp_peer_open(&cfg, esp_peer_get_default_impl(), &peer_handle);
            esp_peer_new_connection(peer_handle);
            
            // 3. Feed it the saved SDP offer from Flutter
            esp_peer_msg_t msg_in = {0}; 
            msg_in.type = ESP_PEER_MSG_TYPE_SDP; 
            msg_in.data = (void *)incoming_offer_sdp;
            msg_in.size = strlen(incoming_offer_sdp); 
            esp_peer_send_msg(peer_handle, &msg_in); 
            
            request_engine_reset = false;
        }

        // Only process background heartbeats if the engine exists
        if (peer_handle != NULL) {
            esp_peer_main_loop(peer_handle);
        }

        if (webrtc_ready && peer_handle != NULL) {
            TickType_t now = xTaskGetTickCount();
            
            if (now - last_frame_time >= pdMS_TO_TICKS(100)) { // Change this to 33 for 30fps, or 66 for 15fps, or longer if need be

                uint32_t free_heap = esp_get_free_heap_size();
                if (free_heap < 40000) {
                    ESP_LOGW(TAG, "RAM critically low (%lu bytes). Skipping frame to let Wi-Fi catch up...", free_heap);
                    last_frame_time = now;
                    continue; 
                }

                camera_fb_t *fb = esp_camera_fb_get();
                if (fb != NULL) {
                    esp_peer_data_frame_t data_frame = {0};
                    data_frame.data = fb->buf;
                    data_frame.size = fb->len;
                    
                    // Catch any errors from the send function
                    esp_err_t err = esp_peer_send_data(peer_handle, &data_frame);
                    if (err != ESP_OK) {
                        ESP_LOGE(TAG, "Buffer full or send failed! Error Code: %d", err);
                        
                        // Error -3 (Closed) or -9 (Timeout) means the client is gone
                        if (err == -3 || err == -9) {
                            ESP_LOGW(TAG, "Connection lost. Auto-halting stream.");
                            webrtc_ready = false;
                        }
                    }
                    
                    esp_camera_fb_return(fb);
                    last_frame_time = now;
                }
            }
        }
        vTaskDelay(pdMS_TO_TICKS(10)); // Gotta make this short to keep sending those images
    }
}

void webrtc_init(esp_mqtt_client_handle_t mqtt_client) {
    s_mqtt_client = mqtt_client;
    xTaskCreatePinnedToCore(webrtc_task, "webrtc_task", 32768, NULL, 5, NULL, 1);
}

/**
 * @brief Initializes the camera hardware
 * 
 * @return esp_err_t 
 */
esp_err_t init_camera() {
    camera_config_t config = {
        .pin_pwdn = CAM_PIN_PWDN, 
        .pin_reset = CAM_PIN_RESET, 
        .pin_xclk = CAM_PIN_XCLK,
        .pin_sscb_sda = CAM_PIN_SIOD, 
        .pin_sscb_scl = CAM_PIN_SIOC,
        .pin_d7 = CAM_PIN_D7, 
        .pin_d6 = CAM_PIN_D6, 
        .pin_d5 = CAM_PIN_D5, 
        .pin_d4 = CAM_PIN_D4,
        .pin_d3 = CAM_PIN_D3, 
        .pin_d2 = CAM_PIN_D2, 
        .pin_d1 = CAM_PIN_D1, 
        .pin_d0 = CAM_PIN_D0,
        .pin_vsync = CAM_PIN_VSYNC, 
        .pin_href = CAM_PIN_HREF, 
        .pin_pclk = CAM_PIN_PCLK,
        .xclk_freq_hz = 10000000, 
        .ledc_timer = LEDC_TIMER_0, 
        .ledc_channel = LEDC_CHANNEL_0,
        .pixel_format = PIXFORMAT_JPEG,
        .frame_size = FRAMESIZE_QQVGA,
        .jpeg_quality = 30, 
        .fb_count = 1,
        .grab_mode = CAMERA_GRAB_LATEST
    };
    esp_err_t err = esp_camera_init(&config);
    if (err == ESP_OK) {
        ESP_LOGI(TAG, "Camera Initialized");
    } else {
        ESP_LOGE(TAG, "Camera Init Failed with error 0x%x", err);
    }
    return err;
}