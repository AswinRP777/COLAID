#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Wire.h>
#include "Adafruit_TCS34725.h" // Install this library if using TCS34725
#include <math.h>

/*
  Colaid Eyewear - ESP32 Firmware
  
  Features:
  - BLE UART Server to receive CVD Type from Phone.
  - TCS3200 / TCS34725 Color Sensor Reading.
  - Buzzer Feedback for problematic colors.
  - Send "Detected Color Name" back to Phone for Audio Feedback.

  Wiring (Adjust pins as needed):
  - Buzzer: GPIO 4
  - TCS3200: S0=18, S1=19, S2=21, S3=22, OUT=23
  OR
  - TCS34725: I2C SDA=21, SCL=22
*/

// --- LED & PIN DEFINITIONS ---
#define BUZZER_PIN 4
#define LED_PIN 2   // Onboard Blue LED

// Select Sensor Type: 0 = MOCK (No hardware), 1 = TCS34725 (I2C), 2 = TCS3200
#define SENSOR_TYPE 0 

// --- TCS3200 Pins ---
#define S0 18
#define S1 19
#define S2 21
#define S3 22
#define SENSOR_OUT 23

// --- BLE UUIDs ---
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E" // Phone writes to this
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E" // Phone reads from this

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;
String cvdType = "none"; // Default: None

// Global settings
bool audioEnabled = false; // Default off until app syncs
unsigned long lastAudioTime = 0;
String lastDetectedColor = "";
bool isSensorWorking = false; // Flag to track sensor health

// LED State Variables
unsigned long lastBlinkTime = 0;
bool ledState = LOW;

// Sensor Object
Adafruit_TCS34725 tcs = Adafruit_TCS34725(TCS34725_INTEGRATIONTIME_50MS, TCS34725_GAIN_4X);

// --- COLOR PALETTE ---
struct ColorRef {
  String name;
  int r, g, b;
};

// Expanded Palette for better detection
// Adjust these RGB values based on calibration of your specific sensor!
const ColorRef validColors[] = {
  {"Red", 255, 0, 0},
  {"Green", 0, 255, 0},
  {"Blue", 0, 0, 255},
  {"Yellow", 255, 255, 0},
  {"Cyan", 0, 255, 255},
  {"Magenta", 255, 0, 255},
  {"Orange", 255, 165, 0},
  {"Purple", 128, 0, 128},
  {"Pink", 255, 192, 203},
  {"Brown", 165, 42, 42},
  {"White", 255, 255, 255},
  {"Gray", 128, 128, 128},
  {"Black", 0, 0, 0}
};
const int colorCount = sizeof(validColors) / sizeof(validColors[0]);

// Function to find the closest color
String getColorName(int r, int g, int b) {
  String closestColor = "Unknown";
  double minDistance = 999999.0;

  for (int i = 0; i < colorCount; i++) {
    double dist = sqrt(pow(r - validColors[i].r, 2) + 
                       pow(g - validColors[i].g, 2) + 
                       pow(b - validColors[i].b, 2));
    
    if (dist < minDistance) {
      minDistance = dist;
      closestColor = validColors[i].name;
    }
  }
  return closestColor;
}


// --- BLE CALLBACKS ---
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device Disconnected");
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue();
      
      if (rxValue.length() > 0) {
        String data = "";
        for (int i = 0; i < rxValue.length(); i++) {
          data += rxValue[i];
        }
        data.trim();

        // Handle Audio Commands
        if (data == "AUDIO_ON") {
           audioEnabled = true;
           Serial.println("Audio Enabled");
        } else if (data == "AUDIO_OFF") {
           audioEnabled = false;
           Serial.println("Audio Disabled");
        }
        // Handle CVD Types
        else if (data == "protanopia") cvdType = "protanopia";
        else if (data == "deuteranopia") cvdType = "deuteranopia";
        else if (data == "tritanopia") cvdType = "tritanopia";
        else if (data == "none") cvdType = "none";
        
        // Legacy Support
        else {
          if (data == "P") cvdType = "protanopia";
          else if (data == "D") cvdType = "deuteranopia"; 
          else if (data == "T") cvdType = "tritanopia";
          else if (data == "N") cvdType = "none";
        }
        
        Serial.print("Received Data: "); Serial.println(data);
        Serial.print("CVD Type set to: "); Serial.println(cvdType);
        
        // Acknowledge via Buzzer (Short blip)
        digitalWrite(BUZZER_PIN, HIGH);
        delay(50);
        digitalWrite(BUZZER_PIN, LOW);
      }
    }
};


void setup() {
  Serial.begin(115200);

  // Buffer Config
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  
  // LED Setup
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Sensor Setup
  if (SENSOR_TYPE == 0) {
    // MOCK MODE
    Serial.println("MOCK SENSOR MODE ENABLED");
    isSensorWorking = true; 
  } else if (SENSOR_TYPE == 1) {
    if (tcs.begin()) {
      Serial.println("Found sensor");
      isSensorWorking = true;
    } else {
      Serial.println("No TCS34725 found ... check your connections");
      // Do NOT halt here, allow BLE to start so we can debug/flash
      isSensorWorking = false;
    }
  } else if (SENSOR_TYPE == 2) {
    // TCS3200 setup
    pinMode(S0, OUTPUT); pinMode(S1, OUTPUT);
    pinMode(S2, OUTPUT); pinMode(S3, OUTPUT);
    pinMode(SENSOR_OUT, INPUT);
    // Set frequency scaling to 20%
    digitalWrite(S0, HIGH); digitalWrite(S1, LOW); 
    isSensorWorking = true;
  }

  // BLE Setup
  BLEDevice::init("Colaid");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  pTxCharacteristic = pService->createCharacteristic(
                    CHARACTERISTIC_UUID_TX,
                    BLECharacteristic::PROPERTY_NOTIFY
                  );
  pTxCharacteristic->addDescriptor(new BLE2902());
  
  BLECharacteristic * pRxCharacteristic = pService->createCharacteristic(
                       CHARACTERISTIC_UUID_RX,
                       BLECharacteristic::PROPERTY_WRITE
                     );
  pRxCharacteristic->setCallbacks(new MyCallbacks());
  
  pService->start();
  
  // Start Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("Waiting for BLE connection...");
}

void loop() {
  unsigned long currentMillis = millis();

  // --- LED STATUS LIGHT LOGIC ---
  long blinkInterval = deviceConnected ? 2000 : 200; // Slow (2000ms) if connected, Fast (200ms) if not

  if (currentMillis - lastBlinkTime >= blinkInterval) {
    lastBlinkTime = currentMillis;
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState);
  }

  if (deviceConnected) {
    uint16_t r, g, b, c;
    String detectedColor = "Unknown";
    bool sensorSuccess = false;

    // 1. READ COLOR
    if (isSensorWorking) {
      if (SENSOR_TYPE == 0) {
         // MOCK DATA
         unsigned long now = millis();
         int step = (now / 4000) % 5;
         if (step == 0) { r=200; g=50; b=50; c=300; }     
         else if (step == 1) { r=50; g=200; b=50; c=300; } 
         else if (step == 2) { r=50; g=50; b=200; c=300; } 
         else if (step == 3) { r=200; g=200; b=50; c=450; } 
         else { r=150; g=150; b=150; c=450; } 
         sensorSuccess = true;
      } else if (SENSOR_TYPE == 1) {
         tcs.getRawData(&r, &g, &b, &c);
         sensorSuccess = true;
      } else {
         // TCS3200 logic
         digitalWrite(S2, LOW); digitalWrite(S3, LOW);
         uint32_t r_pulse = pulseIn(SENSOR_OUT, LOW);
         digitalWrite(S2, HIGH); digitalWrite(S3, HIGH);
         uint32_t g_pulse = pulseIn(SENSOR_OUT, LOW);
         digitalWrite(S2, LOW); digitalWrite(S3, HIGH);
         uint32_t b_pulse = pulseIn(SENSOR_OUT, LOW);
         digitalWrite(S2, HIGH); digitalWrite(S3, LOW);
         c = pulseIn(SENSOR_OUT, LOW);
  
         if (r_pulse == 0) r_pulse = 1; 
         if (g_pulse == 0) g_pulse = 1; 
         if (b_pulse == 0) b_pulse = 1;
         
         r = map(r_pulse, 20, 200, 255, 0); 
         g = map(g_pulse, 20, 200, 255, 0);
         b = map(b_pulse, 20, 200, 255, 0);
         
         r = constrain(r, 0, 255);
         g = constrain(g, 0, 255);
         b = constrain(b, 0, 255);
         sensorSuccess = true;
      }
    }

    // 2. MAP LOGIC - Only if sensor read successful and decent light level
    // For MOCK mode (TYPE 0), we ignore 'c' > 10 check or ensure mock 'c' is high enough
    if (sensorSuccess && (SENSOR_TYPE == 0 || c > 10)) { 
        detectedColor = getColorName(r, g, b);
    }

    // 3. CVD CHECK - Identify PROBLEM colors
    bool problem = false;
    
    if (cvdType == "protanopia" || cvdType == "deuteranopia") {
       if (detectedColor == "Red" || 
           detectedColor == "Green" || 
           detectedColor == "Brown" || 
           detectedColor == "Orange" || 
           detectedColor == "Pink" || 
           detectedColor == "Purple") {
          problem = true;
       }
    } else if (cvdType == "tritanopia") {
       if (detectedColor == "Blue" || 
           detectedColor == "Yellow" || 
           detectedColor == "Green" ||
           detectedColor == "Purple" ||
           detectedColor == "Orange" || 
           detectedColor == "Brown" || 
           detectedColor == "Pink") {
          problem = true;
       }
    }

    // 4. FEEDBACK LOGIC (Strict)
    // ONLY provide feedback if it is a PROBLEM color AND Audio is enabled
    if (problem && detectedColor != lastDetectedColor) {
       
       // Buzzer Feedback 
       digitalWrite(BUZZER_PIN, HIGH);
       delay(200);
       digitalWrite(BUZZER_PIN, LOW);
       
       // Send to Phone ONLY if Audio is Enabled
       if (audioEnabled) {
           pTxCharacteristic->setValue(detectedColor.c_str());
           pTxCharacteristic->notify();
       }
       
       lastDetectedColor = detectedColor;
       delay(1000); 
    } else if (!problem) {
       // If NOT a problem color, reset state so we can detect a problem color again later
       if (lastDetectedColor != "") {
           lastDetectedColor = ""; 
       }
    }
  }

  // Reconnecting
  if (!deviceConnected && oldDeviceConnected) {
      delay(500);
      pServer->startAdvertising();
      Serial.println("Advertising started");
      oldDeviceConnected = deviceConnected;
  }
  
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }
}
