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
  - Buzzer Feedback for ALL non-distinguishable colors based on CVD type.
  - Send "Detected Color Name" back to Phone for Audio Feedback.
  - Comprehensive CVD confusion pair detection.

  CVD Types and Confused Colors:
  - Protanopia (Red-blind): Red↔Green, Red↔Brown, Orange↔Yellow, Pink↔Gray, Purple↔Blue
  - Deuteranopia (Green-blind): Green↔Red, Green↔Brown, Orange↔Yellow, Pink↔Gray, Purple↔Blue  
  - Tritanopia (Blue-blind): Blue↔Green, Yellow↔Pink, Purple↔Red, Orange↔Pink, Cyan↔White

  Wiring (Adjust pins as needed):
  - Buzzer: GPIO 4
  - TCS3200: S0=18, S1=19, S2=21, S3=22, OUT=23
  OR
  - TCS34725: I2C SDA=21, SCL=22
*/

// --- LED & PIN DEFINITIONS ---
#define BUZZER_PIN 4
#define LED_PIN 2   // Onboard Blue LED

// Select Sensor Type: 1 = TCS34725 (I2C), 2 = TCS3200
#define SENSOR_TYPE 2

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
  {"Black", 0, 0, 0},
  {"Lime", 0, 128, 0},
  {"Teal", 0, 128, 128},
  {"Olive", 128, 128, 0},
  {"Maroon", 128, 0, 0},
  {"Navy", 0, 0, 128}
};
const int colorCount = sizeof(validColors) / sizeof(validColors[0]);

// --- CVD CONFUSION PAIRS ---
// These define which colors are confused with each other for each CVD type
// Each pair represents colors that appear similar to someone with that CVD type

// Protanopia (Red-blind) - Reduced sensitivity to red light
// Confuses colors along the red-green axis
const String protanopiaConfused[] = {
  "Red", "Green", "Brown", "Orange", "Olive", "Maroon", "Lime",  // Red-Green confusion group
  "Pink", "Gray", "White",  // Pink appears grayish
  "Purple", "Blue", "Navy",  // Purple appears bluish
  "Cyan", "White"  // Saturated colors appear washed out
};
const int protanopiaConfusedCount = 14;

// Deuteranopia (Green-blind) - Reduced sensitivity to green light
// Very similar to protanopia but slightly different perception
const String deuteranopiaConfused[] = {
  "Red", "Green", "Brown", "Orange", "Olive", "Maroon", "Lime",  // Red-Green confusion group
  "Pink", "Gray", "White",  // Pink appears grayish
  "Purple", "Blue", "Navy",  // Purple appears bluish
  "Yellow", "Lime"  // Yellow-green confusion
};
const int deuteranopiaConfusedCount = 14;

// Tritanopia (Blue-blind) - Reduced sensitivity to blue light
// Confuses colors along the blue-yellow axis
const String tritanopiaConfused[] = {
  "Blue", "Green", "Teal", "Cyan",  // Blue-Green confusion
  "Yellow", "Pink", "Orange", "White",  // Yellow appears pinkish/light
  "Purple", "Red", "Maroon", "Magenta",  // Purple appears reddish
  "Navy", "Black", "Gray"  // Dark blues appear very dark
};
const int tritanopiaConfusedCount = 15;

// Severity levels for different confusion types
// 1 = mild confusion, 2 = moderate, 3 = severe
int getConfusionSeverity(String color, String cvd) {
  // Severe confusions (most problematic)
  if (cvd == "protanopia" || cvd == "deuteranopia") {
    if (color == "Red" || color == "Green") return 3;
    if (color == "Brown" || color == "Olive") return 3;
    if (color == "Orange" || color == "Maroon") return 2;
    if (color == "Pink" || color == "Purple") return 2;
    if (color == "Lime") return 2;
  }
  if (cvd == "tritanopia") {
    if (color == "Blue" || color == "Yellow") return 3;
    if (color == "Purple" || color == "Cyan") return 3;
    if (color == "Green" || color == "Teal") return 2;
    if (color == "Pink" || color == "Orange") return 2;
    if (color == "Navy" || color == "Magenta") return 2;
  }
  return 1; // Default mild
}

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
  if (SENSOR_TYPE == 1) {
    // TCS34725 (I2C) setup
    if (tcs.begin()) {
      Serial.println("TCS34725 sensor found");
      isSensorWorking = true;
    } else {
      Serial.println("No TCS34725 found ... check your connections");
      isSensorWorking = false;
    }
  } else if (SENSOR_TYPE == 2) {
    // TCS3200 setup
    pinMode(S0, OUTPUT); pinMode(S1, OUTPUT);
    pinMode(S2, OUTPUT); pinMode(S3, OUTPUT);
    pinMode(SENSOR_OUT, INPUT);
    // Set frequency scaling to 20%
    digitalWrite(S0, HIGH); digitalWrite(S1, LOW);
    Serial.println("TCS3200 sensor initialized");
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
      if (SENSOR_TYPE == 1) {
         // TCS34725 (I2C)
         tcs.getRawData(&r, &g, &b, &c);
         sensorSuccess = true;
      } else if (SENSOR_TYPE == 2) {
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
    if (sensorSuccess && c > 10) { 
        detectedColor = getColorName(r, g, b);
    }

    // 3. CVD CHECK - Identify PROBLEM colors using comprehensive confusion arrays
    bool problem = false;
    int severity = 0;
    
    if (cvdType == "protanopia") {
      // Check against protanopia confusion colors
      for (int i = 0; i < protanopiaConfusedCount; i++) {
        if (detectedColor == protanopiaConfused[i]) {
          problem = true;
          severity = getConfusionSeverity(detectedColor, cvdType);
          break;
        }
      }
    } else if (cvdType == "deuteranopia") {
      // Check against deuteranopia confusion colors
      for (int i = 0; i < deuteranopiaConfusedCount; i++) {
        if (detectedColor == deuteranopiaConfused[i]) {
          problem = true;
          severity = getConfusionSeverity(detectedColor, cvdType);
          break;
        }
      }
    } else if (cvdType == "tritanopia") {
      // Check against tritanopia confusion colors
      for (int i = 0; i < tritanopiaConfusedCount; i++) {
        if (detectedColor == tritanopiaConfused[i]) {
          problem = true;
          severity = getConfusionSeverity(detectedColor, cvdType);
          break;
        }
      }
    }

    // 4. FEEDBACK LOGIC with SEVERITY-BASED BEEPS
    // Provides different beep patterns based on how severe the color confusion is
    // Severity 3 = 3 beeps (severe confusion like Red/Green)
    // Severity 2 = 2 beeps (moderate confusion like Pink/Gray)
    // Severity 1 = 1 beep (mild confusion)
    if (problem && detectedColor != lastDetectedColor) {
       
       // Buzzer Feedback - Number of beeps based on severity
       for (int beep = 0; beep < severity; beep++) {
         digitalWrite(BUZZER_PIN, HIGH);
         delay(150);  // Beep duration
         digitalWrite(BUZZER_PIN, LOW);
         if (beep < severity - 1) {
           delay(100);  // Gap between beeps
         }
       }
       
       // Send to Phone ONLY if Audio is Enabled
       if (audioEnabled) {
           // Send color name with severity indicator
           String message = detectedColor;
           pTxCharacteristic->setValue(message.c_str());
           pTxCharacteristic->notify();
       }
       
       // Debug output
       Serial.print("CVD Alert: "); Serial.print(detectedColor);
       Serial.print(" (Severity: "); Serial.print(severity); Serial.println(")");
       
       lastDetectedColor = detectedColor;
       delay(800);  // Debounce delay
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
