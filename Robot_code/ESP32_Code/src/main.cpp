#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include "CameraServer.h"
#include "secrets.h"

const char* ssid = SECRET_SSID;
const char* password = SECRET_PASS;
const char* mqtt_server = SECRET_MQTT_SERVER;
const int mqtt_port = 8883; // port 1883 is the default for unencrypted MQTT, 8883 is the default for encrypted MQTT
const char* mqtt_user = SECRET_MQTT_USER;
const char* mqtt_pass = SECRET_MQTT_PASS;
const char* mqtt_root_ca = ROOT_CA;


// Temp Serial pins for Arduino communication
#define RX_PIN 13 
#define TX_PIN 14 

// Ucomment below to go outisde local network
WiFiClientSecure espClient;
// WiFiClient espClient;
PubSubClient client(espClient);

void callback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }

  // Debug to PC
  Serial.print("MQTT Received: ");
  Serial.println(message);

  // Forward the message
  Serial2.println(message); 
}

void setup() {
  // Initialize USB Serial for debugging on the computer
  Serial.begin(115200);
  
  // Initialize Hardware Serial 2 for talking to Arduino
  Serial2.begin(115200, SERIAL_8N1, RX_PIN, TX_PIN);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) delay(500);

  setupCamera();
  Serial.print("Camera Stream Ready! Go to: http://");
  Serial.println(WiFi.localIP());

  // Uncomment below to go outisde local network
  espClient.setCACert(mqtt_root_ca);
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void reconnect() {
  while (!client.connected()) {
    if (client.connect("robotCommands", mqtt_user, mqtt_pass)) {
      client.subscribe("robotCommands");
    } else {
      delay(5000);
    }
  }
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  if (Serial2.available()) {
    String incoming = Serial2.readStringUntil('\n');
    incoming.trim(); // Remove any trailing newline characters
    if (incoming.startsWith("BATT:")) {
      String batteryLevel = incoming.substring(5); // Get the percentage after "BATT:"
      Serial.print("Battery Level: ");
      Serial.println(batteryLevel);
      client.publish("robotCommands", batteryLevel.c_str());
    } else {
      Serial.print("Unknown Serial2 Message: ");
      Serial.println(incoming);
    }
  }
}