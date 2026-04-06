#include "wifi_portal.h"
#include "esp_wifi.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "esp_http_server.h"
#include "cJSON.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <sys/param.h>

static const char *TAG = "WIFI_PORTAL";

/**
 * @brief HTML content for the Wi-Fi setup page (made with Gemini AI to make it look passable)
 * 
 */
static const char* setup_html = 
    "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'>"
    "<style>body{font-family:sans-serif; background:#121212; color:white; display:flex; flex-direction:column; align-items:center; padding-top:50px;} "
    "input, button{padding:10px; margin:10px; width:250px; font-size:16px;}</style></head><body>"
    "<h2>HomeWatcher Wi-Fi Setup</h2>"
    "<input id='ssid' type='text' placeholder='Wi-Fi Network Name (SSID)'>"
    "<input id='pass' type='password' placeholder='Wi-Fi Password'>"
    "<button onclick='save()'>Save & Connect</button>"
    "<script>"
    "function save() {"
    "  fetch('/save', {"
    "    method: 'POST',"
    "    headers: {'Content-Type': 'application/json'},"
    "    body: JSON.stringify({ssid: document.getElementById('ssid').value, pass: document.getElementById('pass').value})"
    "  }).then(() => {"
    "    alert('Credentials saved! HomeWatcher is restarting.');"
    "  });"
    "}"
    "</script></body></html>";


/**
 * @brief Checks if Wi-Fi credentials have been saved in NVS
 * 
 * @return true 
 * @return false 
 */
    bool has_saved_wifi_creds(void) {
    nvs_handle_t my_handle;
    esp_err_t err = nvs_open("storage", NVS_READONLY, &my_handle);
    if (err != ESP_OK) return false;
    
    size_t required_size;
    err = nvs_get_str(my_handle, "ssid", NULL, &required_size);
    nvs_close(my_handle);
    return (err == ESP_OK);
}

/**
 * @brief Retrieves saved Wi-Fi credentials from NVS
 * 
 * @param ssid 
 * @param pass 
 */
void get_saved_wifi_creds(char *ssid, char *pass) {
    nvs_handle_t my_handle;
    if (nvs_open("storage", NVS_READONLY, &my_handle) == ESP_OK) {
        size_t size = 32; nvs_get_str(my_handle, "ssid", ssid, &size);
        size = 64; nvs_get_str(my_handle, "pass", pass, &size);
        nvs_close(my_handle);
    }
}


/**
 * @brief Clears saved Wi-Fi credentials from NVS
 * 
 */
void clear_wifi_creds(void) {
    nvs_handle_t my_handle;
    if (nvs_open("storage", NVS_READWRITE, &my_handle) == ESP_OK) {
        nvs_erase_key(my_handle, "ssid");
        nvs_erase_key(my_handle, "pass");
        nvs_commit(my_handle);
        nvs_close(my_handle);
        ESP_LOGI(TAG, "Wi-Fi credentials erased from NVS.");
    }
}

/**
 * @brief HTTP GET handler for the root page, serves the Wi-Fi setup HTML
 * 
 * @param req 
 * @return esp_err_t 
 */
static esp_err_t index_get_handler(httpd_req_t *req) {
    httpd_resp_set_type(req, "text/html");
    return httpd_resp_send(req, setup_html, HTTPD_RESP_USE_STRLEN);
}

/**
 * @brief Reboot the system after the response
 * 
 * @param arg 
 */
static void reboot_task(void *arg) {
    vTaskDelay(pdMS_TO_TICKS(2000)); // TimeBuffer
    esp_restart();
}


/**
 * @brief HTTP POST handler for saving Wi-Fi credentials sent from the web page, stores them in NVS, and then reboots the system to connect to the new Wi-Fi network
 * 
 * @param req 
 * @return esp_err_t 
 */
static esp_err_t save_post_handler(httpd_req_t *req) {
    char buf[200];
    int ret = httpd_req_recv(req, buf, MIN(req->content_len, sizeof(buf) - 1));
    if (ret <= 0) return ESP_FAIL;
    buf[ret] = '\0';

    cJSON *json = cJSON_Parse(buf);
    if (json) {
        nvs_handle_t my_handle;
        if (nvs_open("storage", NVS_READWRITE, &my_handle) == ESP_OK) {
            nvs_set_str(my_handle, "ssid", cJSON_GetObjectItem(json, "ssid")->valuestring);
            nvs_set_str(my_handle, "pass", cJSON_GetObjectItem(json, "pass")->valuestring);
            nvs_commit(my_handle);
            nvs_close(my_handle);
            ESP_LOGI(TAG, "New credentials saved!");
        }
        cJSON_Delete(json);
    }
    
    httpd_resp_sendstr(req, "OK");
    xTaskCreate(reboot_task, "reboot_task", 2048, NULL, 5, NULL); // Restart robot after saving creds
    return ESP_OK;
}

/**
 * @brief Starts the Wi-Fi setup and make the robot start in AP mode and grab creds
 * 
 */
void start_wifi_setup_portal(void) {
    ESP_LOGI(TAG, "Starting AP Mode for Wi-Fi Setup...");
    
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_ap();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    wifi_config_t wifi_config = {
        .ap = {
            .ssid = "HomeWatcher_Setup",
            .ssid_len = strlen("HomeWatcher_Setup"),
            .channel = 1,
            .password = "", // Open network for easy connection
            .max_connection = 4,
            .authmode = WIFI_AUTH_OPEN
        },
    };

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_LOGI(TAG, "Connect to 'HomeWatcher_Setup' and navigate to http://192.168.4.1");

    // Webserver setup to get inital creds for wifi
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    httpd_handle_t server = NULL;
    if (httpd_start(&server, &config) == ESP_OK) {
        httpd_uri_t uri_get = { .uri = "/", .method = HTTP_GET, .handler = index_get_handler, .user_ctx = NULL };
        httpd_uri_t uri_post = { .uri = "/save", .method = HTTP_POST, .handler = save_post_handler, .user_ctx = NULL };
        httpd_register_uri_handler(server, &uri_get);
        httpd_register_uri_handler(server, &uri_post);
    }
}