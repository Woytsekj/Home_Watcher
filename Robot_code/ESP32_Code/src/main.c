/**
 * @file main.c
 * @author woytsekj (Jonathan Woytsek)
 * @brief MQTT-Controlled Robot with WebRTC Camera Streaming
 */

// Standard libraries
#include <stdio.h>
#include <string.h>
#include <sys/param.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "mqtt_client.h"
#include "driver/uart.h"
#include "driver/gpio.h"

// My headers
#include "secrets.h"
#include "webrtc_camera.h"
#include "wifi_portal.h"

static const char *TAG = "ROBOT_MAIN";

#define ROBOT_PRODUCTION_MODE 1 // For being on the robot aka mutes logging

#define RESET_BUTTON_PIN GPIO_NUM_0
#define TX_PIN (GPIO_NUM_14)
#define RX_PIN (GPIO_NUM_13)
#define UART_NUM UART_NUM_1
#define BUF_SIZE (1024)
#define STATUS_LED_PIN GPIO_NUM_2

esp_mqtt_client_handle_t mqtt_client;

/**
 * @brief Monitors what the Arudino is send back to the ESP32
 * 
 * @param arg 
 */
static void uart_task(void *arg) {
    uint8_t data[BUF_SIZE];
    while (1) {
        // Wait for data from UART
        int len = uart_read_bytes(UART_NUM, data, BUF_SIZE - 1, 20 / portTICK_PERIOD_MS);
        if (len > 0) {
            data[len] = '\0';
            
            // Here to check what the heck the Arudino is sending back to the ESP32
            ESP_LOGW(TAG, "RAW UART RX (%d bytes): '%s'", len, (char*)data);

            while(len > 0 && (data[len-1] == '\r' || data[len-1] == '\n')) {
                data[len-1] = '\0';
                len--;
            }

            // Funny battery logic
            if (strncmp((char*)data, "BATT:", 5) == 0) {
                char* batteryLevel = (char*)data + 5;
                ESP_LOGI(TAG, "Battery Level: %s", batteryLevel);
                esp_mqtt_client_publish(mqtt_client, "robotCommands", batteryLevel, 0, 1, 0);
            } else {
                // More stuff to yell at use for what the Arudino is sending
                ESP_LOGW(TAG, "UNHANDLED UART DATA: '%s'", data);
            }
        }
    }
}


/**
 * @brief Looks for the press of the boot button on the ESP32. If held for 3 seconds. Will clear Wi-Fi creds in the memory
 * 
 */
static void button_monitor_task(void *arg) {
    gpio_set_direction(RESET_BUTTON_PIN, GPIO_MODE_INPUT);
    gpio_set_pull_mode(RESET_BUTTON_PIN, GPIO_PULLUP_ONLY); 

    int hold_time = 0;
    while (1) {
        if (gpio_get_level(RESET_BUTTON_PIN) == 0) { 
            hold_time++;
            if (hold_time >= 30) {
                ESP_LOGW(TAG, "Reset button held! Wiping Wi-Fi credentials and restarting...");
                clear_wifi_creds();
                esp_restart(); 
            }
        } else {
            hold_time = 0; 
        }
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

/**
 * @brief Handles MQTT for both the commands we get from the app and the WebRTC handshake messages.
 * 
 * @param handler_args 
 * @param base 
 * @param event_id 
 * @param event_data 
 */
static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data) {
    esp_mqtt_event_handle_t event = event_data;
    
    switch ((esp_mqtt_event_id_t)event_id) {
        case MQTT_EVENT_CONNECTED:
            ESP_LOGI(TAG, "MQTT Connected!");
            gpio_set_level(STATUS_LED_PIN, 1);
            esp_mqtt_client_subscribe(mqtt_client, "robotCommands", 0);
            esp_mqtt_client_subscribe(mqtt_client, "robotWebRTC/rx", 0); 
            break;

        case MQTT_EVENT_DISCONNECTED:
            ESP_LOGI(TAG, "MQTT Disconnected...");
            gpio_set_level(STATUS_LED_PIN, 0);
            break;
            
        case MQTT_EVENT_DATA:
            {
                char topic[64];
                snprintf(topic, sizeof(topic), "%.*s", event->topic_len, event->topic);
                
                if (strncmp(topic, "robotCommands", 13) == 0) {
                    char message[256];
                    snprintf(message, sizeof(message), "%.*s", event->data_len, event->data);
                    uart_write_bytes(UART_NUM, message, strlen(message));
                    uart_write_bytes(UART_NUM, "\n", 1);
                } 
                else if (strncmp(topic, "robotWebRTC/rx", 14) == 0) {
                    webrtc_handle_signaling_message(event->data, event->data_len);
                }
            }
            break;
        default:
            break;
    }
}

/**
 * @brief Handles the Wi-Fi for the ESP32. Makes sure to set one up if there isn't one in the memory.
 * 
 * @param arg 
 * @param event_base 
 * @param event_id 
 * @param event_data 
 */
static void wifi_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data) {
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        esp_wifi_connect();
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "WiFi Connected! IP: " IPSTR, IP2STR(&event->ip_info.ip));
    }
}


/**
 * @brief All my initialization garbage sits here
 */
void app_main(void) {
    #if ROBOT_PRODUCTION_MODE
    esp_log_level_set("*", ESP_LOG_NONE); 
    #else
    esp_log_level_set("*", ESP_LOG_INFO);
    #endif

    //Initialize NVS (Required for both the portal and normal Wi-Fi)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
      ESP_ERROR_CHECK(nvs_flash_erase());
      nvs_flash_init();
    }

    gpio_set_direction(STATUS_LED_PIN, GPIO_MODE_OUTPUT);
    gpio_set_level(STATUS_LED_PIN, 0);

    //Start the physical reset button monitor (Always runs)
    xTaskCreate(button_monitor_task, "btn_task", 2048, NULL, 5, NULL);

    //Setup Mode vs. Normal Operation Gatekeeper
    if (!has_saved_wifi_creds()) {
        ESP_LOGI(TAG, "No Wi-Fi credentials found. Entering Setup Mode.");
        start_wifi_setup_portal();
        
        // EXIT HERE: Prevents UART, Camera, and MQTT from launching
        return; 
    }

    ESP_LOGI(TAG, "Credentials found! Booting normally...");

    //Initialize UART hardware and background task
    uart_config_t uart_config = {
        .baud_rate = 115200, .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE, .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE, .source_clk = UART_SCLK_DEFAULT,
    };
    ESP_ERROR_CHECK(uart_driver_install(UART_NUM, BUF_SIZE * 2, 0, 0, NULL, 0));
    ESP_ERROR_CHECK(uart_param_config(UART_NUM, &uart_config));
    ESP_ERROR_CHECK(uart_set_pin(UART_NUM, TX_PIN, RX_PIN, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE));
    xTaskCreatePinnedToCore(uart_task, "uart_task", 4096, NULL, 4, NULL, 0);

    //Initialize WiFi Station Mode using saved NVS credentials
    char saved_ssid[32] = {0};
    char saved_pass[64] = {0};
    get_saved_wifi_creds(saved_ssid, saved_pass);

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();
    
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL, NULL);
    esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL, NULL);

    wifi_config_t wifi_config = {0}; 
    strncpy((char *)wifi_config.sta.ssid, saved_ssid, sizeof(wifi_config.sta.ssid) - 1);
    strncpy((char *)wifi_config.sta.password, saved_pass, sizeof(wifi_config.sta.password) - 1);
    
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    init_camera();

    char mqtt_uri[128];

#ifdef USE_AWS_IOT
    // Well it's on the name. It is for use when we use AWS
    snprintf(mqtt_uri, sizeof(mqtt_uri), "mqtts://%s", SECRET_MQTT_SERVER); 
    
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = mqtt_uri,
        .broker.address.port = SECRET_MQTT_PORT,
        .broker.verification.certificate = (const char *)ROOT_CA,
        .credentials.username = SECRET_MQTT_USER,
        .credentials.authentication.password = SECRET_MQTT_PASS,
        .buffer.size = 4096,
        .buffer.out_size = 4096,
    };
    ESP_LOGI(TAG, "Configured for Secure AWS IoT MQTT");

#else
    // For local Testing
    snprintf(mqtt_uri, sizeof(mqtt_uri), "mqtt://%s", SECRET_MQTT_SERVER); 
    
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = mqtt_uri,
        .broker.address.port = SECRET_MQTT_PORT,
        .credentials.username = SECRET_MQTT_USER,
        .credentials.authentication.password = SECRET_MQTT_PASS,
        .buffer.size = 4096,
        .buffer.out_size = 4096,
    };
    ESP_LOGI(TAG, "Configured for Local Unencrypted MQTT");
#endif

    mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(mqtt_client);

    webrtc_init(mqtt_client);
}