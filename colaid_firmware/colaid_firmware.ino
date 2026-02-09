#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Wire.h>
#include "Adafruit_TCS34725.h" // Install this library if using TCS34725
#include <math.h>

// --- A2DP Audio Source (for TWS speakers like Lenscart Phonic) ---
// Requires: "ESP32-A2DP" library by pschatzmann
// Install via Arduino Library Manager: Search "ESP32 A2DP" by Phil Schatzmann
// NOTE: A2DP_ENABLED must be defined before the conditional include
#define A2DP_ENABLED false
#if A2DP_ENABLED
#include "BluetoothA2DPSource.h"
#endif

/*
  Colaid Eyewear - ESP32 Firmware
  
  Features:
  - BLE UART Server to receive CVD Type from Phone (via Ishihara test).
  - TCS3200 / TCS34725 Color Sensor Reading.
  - COMPREHENSIVE HSV-based CVD detection covering FULL color wheel.
  - Buzzer Feedback for ALL indistinguishable colors based on CVD type.
  - Send "Detected Color Name" back to Phone for Audio Feedback.

  CVD Types - Full Color Wheel Detection (HSV-based):
  
  PROTANOPIA (Red-blind) - Missing L-cones (long wavelength/red):
  - Primary confusion: Red ↔ Green ↔ Brown ↔ Olive
  - Hue range affected: 0°-150° (reds, oranges, yellows, yellow-greens, greens)
  - Also confused: Pink ↔ Gray, Purple ↔ Blue (desaturated reds)
  - Low saturation colors appear gray
  - Reds appear darker than normal
  
  DEUTERANOPIA (Green-blind) - Missing M-cones (medium wavelength/green):
  - Primary confusion: Green ↔ Red ↔ Brown ↔ Olive  
  - Hue range affected: 0°-150° (same as protanopia)
  - Also confused: Pink ↔ Gray, Purple ↔ Blue
  - Similar to protanopia but reds not as dark
  
  TRITANOPIA (Blue-blind) - Missing S-cones (short wavelength/blue):
  - Primary confusion: Blue ↔ Green, Yellow ↔ Pink
  - Hue range affected: 50°-100° (yellows/greens) AND 180°-290° (cyans/blues/purples)
  - Also confused: Purple ↔ Red, Orange ↔ Pink, Cyan ↔ White

  Wiring (Adjust pins as needed):
  - Buzzer: GPIO 4
  - TCS3200: S0=18, S1=19, S2=21, S3=22, OUT=23
  OR
  - TCS34725: I2C SDA=21, SCL=22
*/

// --- LED & PIN DEFINITIONS ---
#define BUZZER_PIN 4
#define LED_PIN 2   // Onboard Blue LED

// --- BUZZER PWM SETTINGS (for louder, sharper sound) ---
#define BUZZER_RESOLUTION 8   // 8-bit resolution (0-255)
#define BUZZER_FREQ_HIGH 3500 // High frequency for sharp beep (Hz)
#define BUZZER_FREQ_MED 2800  // Medium frequency
#define BUZZER_FREQ_LOW 2200  // Lower frequency for mild alerts

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

// --- HSV COLOR STRUCTURE (must be defined before functions) ---
typedef struct {
  float h;  // Hue: 0-360 degrees
  float s;  // Saturation: 0-100%
  float v;  // Value/Brightness: 0-100%
} HSV;

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic;

// --- MULTI-CONNECTION SUPPORT ---
// ESP32 supports up to MAX_CONNECTIONS simultaneous BLE clients
#define MAX_CONNECTIONS 3  // ESP32 default max (can increase to ~9 in sdkconfig)
uint16_t connectedCount = 0;       // Current number of connected devices
uint16_t oldConnectedCount = 0;    // Previous count for edge detection
String cvdType = "none"; // Default: None

// Global settings
bool audioEnabled = false; // Default off until app syncs
unsigned long lastAudioTime = 0;
String lastDetectedColor = "";
String lastVisibleColor = "";  // Track last visible (distinguishable) color
bool isSensorWorking = false; // Flag to track sensor health

// --- MULTICOLOR & STABILITY TRACKING ---
#define COLOR_HISTORY_SIZE 7       // Number of readings to track (increased for better accuracy)
#define STABILITY_THRESHOLD 4       // Need this many same readings for stable color
#define VISIBLE_CONFIRM_ENABLED true  // Enable confirmation beep for visible colors
#define NUM_SAMPLES 5               // Number of sensor samples to average
#define SAMPLE_DELAY_MS 10          // Delay between samples

String colorHistory[COLOR_HISTORY_SIZE];
int historyIndex = 0;
unsigned long lastColorChangeTime = 0;
bool colorIsStable = false;
int stableColorCount = 0;

// --- DISCONNECT ALARM ---
bool disconnectedUnexpectedly = false;  // Set true on any disconnect
unsigned long disconnectTime = 0;       // When disconnect happened
unsigned long lastDisconnectBeep = 0;   // Last time alarm beeped
#define DISCONNECT_ALARM_INTERVAL 3000  // Beep every 3 seconds
#define DISCONNECT_ALARM_DURATION 20000 // Keep alarming for 20 seconds

// --- A2DP AUDIO SOURCE (TWS Connection) ---
// Set to true ONLY if you want ESP32 to connect to TWS for beep tones.
// Set to false (DEFAULT) when the PHONE connects to TWS for spoken color names.
// Most TWS earphones only accept ONE audio source at a time.
// When false: Phone pairs with TWS → Phone TTS speaks color names through earphones
// When true:  ESP32 pairs with TWS → ESP32 plays beep tones through earphones (no speech)
// (A2DP_ENABLED is defined near the top of the file, before the #include guard)

// Target TWS device name - change this to match your device
// Uses case-insensitive partial matching (e.g. "Lenscart" matches "Lenscart Phonic")
#define TARGET_TWS_NAME "Lenscart"       // Primary name to search for
#define TARGET_TWS_NAME_ALT "Phonic"     // Alternate name to search for

#if A2DP_ENABLED
BluetoothA2DPSource a2dp_source;
#endif
bool twsConnected = false;               // Track TWS connection status
unsigned long lastTwsReconnectAttempt = 0;
#define TWS_RECONNECT_INTERVAL 10000     // Retry connection every 10 seconds

// --- A2DP TONE GENERATION ---
// Generates sine wave audio to play alert tones through TWS speakers
#define A2DP_SAMPLE_RATE 44100
volatile bool a2dpPlayTone = false;
volatile int a2dpToneFreq = 0;
volatile int a2dpToneDurationSamples = 0;
volatile int a2dpToneSamplesPlayed = 0;
float a2dpTonePhase = 0.0;

// Queue for multiple tones (melodies)
#define TONE_QUEUE_SIZE 8
struct ToneRequest {
  int frequency;
  int durationMs;
  int pauseAfterMs;
};
ToneRequest toneQueue[TONE_QUEUE_SIZE];
volatile int toneQueueHead = 0;
volatile int toneQueueTail = 0;
volatile int a2dpPauseSamples = 0;
volatile int a2dpPausePlayed = 0;

// Enqueue a tone to play through A2DP
void enqueueTone(int freq, int durationMs, int pauseAfterMs = 0) {
  int next = (toneQueueHead + 1) % TONE_QUEUE_SIZE;
  if (next != toneQueueTail) {  // Don't overflow
    toneQueue[toneQueueHead].frequency = freq;
    toneQueue[toneQueueHead].durationMs = durationMs;
    toneQueue[toneQueueHead].pauseAfterMs = pauseAfterMs;
    toneQueueHead = next;
  }
}

// Start next tone from queue
void startNextTone() {
  if (toneQueueTail != toneQueueHead) {
    ToneRequest t = toneQueue[toneQueueTail];
    toneQueueTail = (toneQueueTail + 1) % TONE_QUEUE_SIZE;
    a2dpToneFreq = t.frequency;
    a2dpToneDurationSamples = (A2DP_SAMPLE_RATE * t.durationMs) / 1000;
    a2dpToneSamplesPlayed = 0;
    a2dpPauseSamples = (A2DP_SAMPLE_RATE * t.pauseAfterMs) / 1000;
    a2dpPausePlayed = 0;
    a2dpTonePhase = 0.0;
    a2dpPlayTone = true;
  }
}

#if A2DP_ENABLED
// A2DP audio data callback - called by Bluetooth stack to get audio frames
// Generates sine wave tones or silence
int32_t a2dp_audio_callback(Frame *frame, int32_t frameCount) {
  for (int i = 0; i < frameCount; i++) {
    if (a2dpPlayTone && a2dpToneSamplesPlayed < a2dpToneDurationSamples) {
      // Generate sine wave at requested frequency
      float sample = sin(2.0 * PI * a2dpTonePhase) * 28000.0;  // ~85% volume
      int16_t s = (int16_t)sample;
      frame[i].channel1 = s;
      frame[i].channel2 = s;
      a2dpTonePhase += (float)a2dpToneFreq / A2DP_SAMPLE_RATE;
      if (a2dpTonePhase >= 1.0) a2dpTonePhase -= 1.0;
      a2dpToneSamplesPlayed++;
    } else if (a2dpPlayTone && a2dpPausePlayed < a2dpPauseSamples) {
      // Silence gap between tones in a melody
      frame[i].channel1 = 0;
      frame[i].channel2 = 0;
      a2dpPausePlayed++;
    } else {
      // Tone finished - try next in queue or go silent
      frame[i].channel1 = 0;
      frame[i].channel2 = 0;
      if (a2dpPlayTone) {
        a2dpPlayTone = false;
        startNextTone();  // Start next queued tone if any
      }
    }
  }
  return frameCount;
}

// Device name filter - only connect to target TWS device
// Returns true if the discovered device name matches our target
bool tws_device_filter(const char* ssid, esp_bd_addr_t address, int rssi) {
  if (ssid == nullptr || strlen(ssid) == 0) return false;
  
  String name = String(ssid);
  name.toLowerCase();
  
  String target1 = String(TARGET_TWS_NAME);
  target1.toLowerCase();
  String target2 = String(TARGET_TWS_NAME_ALT);
  target2.toLowerCase();
  
  bool match = (name.indexOf(target1) >= 0) || (name.indexOf(target2) >= 0);
  
  if (match) {
    Serial.print("[A2DP] Found target TWS: ");
    Serial.print(ssid);
    Serial.print(" (RSSI: ");
    Serial.print(rssi);
    Serial.println(")");
  } else {
    Serial.print("[A2DP] Skipping device: ");
    Serial.println(ssid);
  }
  
  return match;
}
#endif  // A2DP_ENABLED

// --- SENSOR CALIBRATION ---
// Calibration values for white balance (adjust based on your sensor under white light)
// Default values assume sensor sees ~equal RGB under white
float calR = 1.0;   // Red calibration multiplier
float calG = 1.0;   // Green calibration multiplier  
float calB = 1.0;   // Blue calibration multiplier

// TCS3200 calibration (pulse width min/max for black/white)
#define TCS3200_R_MIN 25
#define TCS3200_R_MAX 180
#define TCS3200_G_MIN 30
#define TCS3200_G_MAX 200
#define TCS3200_B_MIN 25
#define TCS3200_B_MAX 170

// --- GAMMA CORRECTION ---
// Converts linear sensor values to perceptual (sRGB-like) values
// Gamma = 2.2 is standard for human perception
float gammaCorrect(float value) {
  return pow(value / 255.0f, 1.0f / 2.2f) * 255.0f;
}

// LED State Variables
unsigned long lastBlinkTime = 0;

// --- SHARP BEEP FUNCTION ---
// Uses PWM tone generation for louder, sharper sound
// Also sends tone to TWS via A2DP if connected
// frequency: Hz (higher = sharper), duration: ms
void sharpBeep(int frequency, int duration) {
  // Local buzzer
  ledcWriteTone(BUZZER_PIN, frequency);
  
  // Also play through TWS speakers via A2DP (only if A2DP mode is enabled)
  #if A2DP_ENABLED
  if (twsConnected) {
    enqueueTone(frequency, duration);
  }
  #endif
  
  delay(duration);
  ledcWriteTone(BUZZER_PIN, 0);  // Stop tone
}

// Beep with severity-based frequency
// Severity 3 = highest pitch (most urgent)
// Severity 2 = medium pitch
// Severity 1 = lower pitch
void alertBeep(int severity) {
  int freq;
  int duration;
  
  switch(severity) {
    case 3:  // Severe - loud, high-pitched, longer
      freq = BUZZER_FREQ_HIGH;
      duration = 180;
      break;
    case 2:  // Moderate
      freq = BUZZER_FREQ_MED;
      duration = 150;
      break;
    default: // Mild
      freq = BUZZER_FREQ_LOW;
      duration = 120;
      break;
  }
  
  sharpBeep(freq, duration);
}

// Quick acknowledgment beep
void ackBeep() {
  sharpBeep(BUZZER_FREQ_HIGH, 50);
}

// Visible color confirmation - single low gentle beep
// Indicates the user CAN see this color correctly
void visibleConfirmBeep() {
  sharpBeep(1200, 80);  // Low, short, gentle tone
}

// Double chirp for multicolor scene
void multicolorChirp() {
  sharpBeep(1500, 40);
  delay(30);
  sharpBeep(1800, 40);
}

// --- BLUETOOTH CONNECTION SOUNDS ---

// Connection success melody - ascending happy tune
// Plays when app successfully connects to eyewear
void connectionBeep() {
  // Ascending 3-note melody (Do-Mi-Sol)
  sharpBeep(1047, 100);  // C5
  delay(50);
  sharpBeep(1319, 100);  // E5
  delay(50);
  sharpBeep(1568, 150);  // G5 (longer final note)
  delay(30);
  // Final confirmation chirp
  sharpBeep(2093, 80);   // C6 (high)
}

// Disconnection warning melody - descending sad tune
// Plays when app disconnects from eyewear
void disconnectionBeep() {
  // Descending 3-note melody (Sol-Mi-Do)
  sharpBeep(1568, 100);  // G5
  delay(50);
  sharpBeep(1319, 100);  // E5
  delay(50);
  sharpBeep(1047, 200);  // C5 (longer, lower final note)
}

// --- COLOR STABILITY FUNCTIONS ---
// Add color to history and check stability
bool updateColorHistory(String color) {
  colorHistory[historyIndex] = color;
  historyIndex = (historyIndex + 1) % COLOR_HISTORY_SIZE;
  
  // Count how many recent readings match current color
  int matchCount = 0;
  for (int i = 0; i < COLOR_HISTORY_SIZE; i++) {
    if (colorHistory[i] == color) matchCount++;
  }
  
  colorIsStable = (matchCount >= STABILITY_THRESHOLD);
  stableColorCount = matchCount;
  return colorIsStable;
}

// Check if two colors are similar (within same hue family)
bool areColorsSimilar(String c1, String c2) {
  if (c1 == c2) return true;
  
  // Similar color families - expanded for better grouping
  // Red family
  if ((c1 == "Red" || c1 == "Red-Orange" || c1 == "Dark Red" || c1 == "Crimson") && 
      (c2 == "Red" || c2 == "Red-Orange" || c2 == "Dark Red" || c2 == "Crimson")) return true;
  
  // Green family
  if ((c1 == "Green" || c1 == "Dark Green" || c1 == "Lime" || c1 == "Forest Green") && 
      (c2 == "Green" || c2 == "Dark Green" || c2 == "Lime" || c2 == "Forest Green")) return true;
  
  // Blue family
  if ((c1 == "Blue" || c1 == "Light Blue" || c1 == "Navy" || c1 == "Sky Blue" || c1 == "Royal Blue") && 
      (c2 == "Blue" || c2 == "Light Blue" || c2 == "Navy" || c2 == "Sky Blue" || c2 == "Royal Blue")) return true;
  
  // Gray family
  if ((c1 == "Gray" || c1 == "Light Gray" || c1 == "Dark Gray" || c1 == "Silver") && 
      (c2 == "Gray" || c2 == "Light Gray" || c2 == "Dark Gray" || c2 == "Silver")) return true;
  
  // Yellow family
  if ((c1 == "Yellow" || c1 == "Yellow-Orange" || c1 == "Yellow-Green" || c1 == "Gold") && 
      (c2 == "Yellow" || c2 == "Yellow-Orange" || c2 == "Yellow-Green" || c2 == "Gold")) return true;
  
  // Orange family
  if ((c1 == "Orange" || c1 == "Red-Orange" || c1 == "Yellow-Orange" || c1 == "Tangerine") && 
      (c2 == "Orange" || c2 == "Red-Orange" || c2 == "Yellow-Orange" || c2 == "Tangerine")) return true;
  
  // Purple family
  if ((c1 == "Purple" || c1 == "Violet" || c1 == "Magenta" || c1 == "Blue-Violet" || c1 == "Lavender") && 
      (c2 == "Purple" || c2 == "Violet" || c2 == "Magenta" || c2 == "Blue-Violet" || c2 == "Lavender")) return true;
  
  // Cyan/Teal family
  if ((c1 == "Cyan" || c1 == "Teal" || c1 == "Aqua" || c1 == "Turquoise") && 
      (c2 == "Cyan" || c2 == "Teal" || c2 == "Aqua" || c2 == "Turquoise")) return true;
  
  // Pink family  
  if ((c1 == "Pink" || c1 == "Light Pink" || c1 == "Hot Pink" || c1 == "Rose") && 
      (c2 == "Pink" || c2 == "Light Pink" || c2 == "Hot Pink" || c2 == "Rose")) return true;
  
  // Brown family
  if ((c1 == "Brown" || c1 == "Dark Brown" || c1 == "Tan" || c1 == "Olive") && 
      (c2 == "Brown" || c2 == "Dark Brown" || c2 == "Tan" || c2 == "Olive")) return true;
  
  return false;
}

bool ledState = LOW;

// Sensor Object
Adafruit_TCS34725 tcs = Adafruit_TCS34725(TCS34725_INTEGRATIONTIME_50MS, TCS34725_GAIN_4X);

// --- RGB TO HSV CONVERSION ---
// Converts RGB (0-255) to HSV (H: 0-360, S: 0-100, V: 0-100)
HSV rgbToHSV(int r, int g, int b) {
  HSV hsv;
  float rf = r / 255.0f;
  float gf = g / 255.0f;
  float bf = b / 255.0f;
  
  float maxVal = max(max(rf, gf), bf);
  float minVal = min(min(rf, gf), bf);
  float delta = maxVal - minVal;
  
  // Value
  hsv.v = maxVal * 100.0f;
  
  // Saturation
  if (maxVal == 0) {
    hsv.s = 0;
  } else {
    hsv.s = (delta / maxVal) * 100.0f;
  }
  
  // Hue
  if (delta == 0) {
    hsv.h = 0;  // Achromatic (gray)
  } else if (maxVal == rf) {
    hsv.h = 60.0f * fmod(((gf - bf) / delta), 6.0f);
  } else if (maxVal == gf) {
    hsv.h = 60.0f * (((bf - rf) / delta) + 2.0f);
  } else {
    hsv.h = 60.0f * (((rf - gf) / delta) + 4.0f);
  }
  
  if (hsv.h < 0) hsv.h += 360.0f;
  
  return hsv;
}

// --- COMPREHENSIVE CVD CONFUSION DETECTION ---
// These functions check if a color (in HSV) falls within the confusion zones
// for each CVD type across the ENTIRE color wheel

/*
 * PROTANOPIA Detection (Red-blind)
 * 
 * Confusion zones on the color wheel:
 * 1. RED-GREEN AXIS (Primary confusion line):
 *    - Hue 0-40° (Red, Red-Orange) - SEVERE
 *    - Hue 40-60° (Orange, Yellow-Orange) - MODERATE  
 *    - Hue 60-90° (Yellow, Yellow-Green) - MODERATE
 *    - Hue 90-150° (Green, Yellow-Green) - SEVERE
 *    - Hue 330-360° (Magenta-Red, Deep Red) - SEVERE
 *    
 * 2. PURPLE-BLUE confusion (reduced red component):
 *    - Hue 240-330° (Blue to Purple to Magenta) with medium saturation
 *    
 * 3. PINK-GRAY confusion (desaturated reds):
 *    - Hue 300-360° or 0-30° with LOW saturation (< 40%)
 *    
 * 4. LOW SATURATION = More confusion (colors appear washed out)
 */
bool isProtanopiaConfused(HSV hsv, int* severity) {
  float h = hsv.h;
  float s = hsv.s;
  float v = hsv.v;
  
  // Very dark colors (black) - not typically confused
  if (v < 8) {
    *severity = 0;
    return false;
  }
  
  // Pure white/very light gray - distinguishable as neutral
  if (s < 5 && v > 85) {
    *severity = 0;
    return false;
  }
  
  // === INDIVIDUAL COLOR CHECKS - NO GROUPING ===
  
  // RED (0-10°)
  if (h >= 0 && h <= 10 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // RED-ORANGE (10-20°)
  if (h > 10 && h <= 20 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // ORANGE (20-35°)
  if (h > 20 && h <= 35 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // ORANGE-YELLOW (35-45°)
  if (h > 35 && h <= 45 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // YELLOW (45-60°)
  if (h > 45 && h <= 60 && s >= 8) {
    *severity = 2;
    return true;
  }
  
  // YELLOW-GREEN (60-80°)
  if (h > 60 && h <= 80 && s >= 8) {
    *severity = 2;
    return true;
  }
  
  // CHARTREUSE (80-100°)
  if (h > 80 && h <= 100 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // GREEN (100-130°)
  if (h > 100 && h <= 130 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // GREEN-CYAN (130-160°)
  if (h > 130 && h <= 160 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // CYAN (160-180°)
  if (h > 160 && h <= 180 && s >= 12) {
    *severity = 2;
    return true;
  }
  
  // CYAN-BLUE (180-200°)
  if (h > 180 && h <= 200 && s >= 15) {
    *severity = 1;
    return true;
  }
  
  // BLUE (200-240°) - Less affected
  // (no detection for pure blue in protanopia)
  
  // BLUE-VIOLET (240-260°)
  if (h > 240 && h <= 260 && s >= 12) {
    *severity = 1;
    return true;
  }
  
  // VIOLET (260-280°)
  if (h > 260 && h <= 280 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // PURPLE (280-300°)
  if (h > 280 && h <= 300 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // MAGENTA (300-320°)
  if (h > 300 && h <= 320 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // MAGENTA-RED (320-340°)
  if (h > 320 && h <= 340 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // DEEP RED (340-360°)
  if (h > 340 && h <= 360 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // === BROWN (dark orange/red with low value) ===
  if (h >= 15 && h <= 45 && s >= 15 && v >= 15 && v <= 55) {
    *severity = 3;
    return true;
  }
  
  // === OLIVE (dark yellow-green) ===
  if (h >= 50 && h <= 85 && s >= 10 && v >= 15 && v <= 50) {
    *severity = 3;
    return true;
  }
  
  *severity = 0;
  return false;
}

/*
 * DEUTERANOPIA Detection (Green-blind)
 * 
 * Very similar to Protanopia but with slight differences:
 * - Same Red-Green confusion axis
 * - Slightly different perception of yellows
 * - Reds don't appear as dark as in protanopia
 * 
 * Confusion zones:
 * 1. RED-GREEN AXIS: Hue 0-160° (covers more of the green spectrum)
 * 2. PURPLE-BLUE confusion: Similar to protanopia
 * 3. PINK-GRAY confusion: Similar but slightly less severe
 * 4. BROWN-GREEN confusion: Very prominent
 */
bool isDeuteranopiaConfused(HSV hsv, int* severity) {
  float h = hsv.h;
  float s = hsv.s;
  float v = hsv.v;
  
  // Very dark colors (black) - not typically confused
  if (v < 8) {
    *severity = 0;
    return false;
  }
  
  // Pure white/very light gray - distinguishable as neutral
  if (s < 5 && v > 85) {
    *severity = 0;
    return false;
  }
  
  // === INDIVIDUAL COLOR CHECKS - NO GROUPING ===
  
  // RED (0-10°)
  if (h >= 0 && h <= 10 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // RED-ORANGE (10-20°)
  if (h > 10 && h <= 20 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // ORANGE (20-35°)
  if (h > 20 && h <= 35 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // ORANGE-YELLOW (35-45°)
  if (h > 35 && h <= 45 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // YELLOW (45-60°)
  if (h > 45 && h <= 60 && s >= 8) {
    *severity = 2;
    return true;
  }
  
  // YELLOW-GREEN (60-80°)
  if (h > 60 && h <= 80 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // CHARTREUSE (80-100°)
  if (h > 80 && h <= 100 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // GREEN (100-130°)
  if (h > 100 && h <= 130 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // GREEN-CYAN (130-160°)
  if (h > 130 && h <= 160 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // TEAL (160-175°)
  if (h > 160 && h <= 175 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // CYAN (175-195°)
  if (h > 175 && h <= 195 && s >= 12) {
    *severity = 2;
    return true;
  }
  
  // CYAN-BLUE (195-210°)
  if (h > 195 && h <= 210 && s >= 15) {
    *severity = 1;
    return true;
  }
  
  // BLUE (210-240°) - Less affected
  // (minimal confusion for pure blue in deuteranopia)
  
  // BLUE-VIOLET (240-260°)
  if (h > 240 && h <= 260 && s >= 12) {
    *severity = 1;
    return true;
  }
  
  // VIOLET (260-280°)
  if (h > 260 && h <= 280 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // PURPLE (280-300°)
  if (h > 280 && h <= 300 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // MAGENTA (300-320°)
  if (h > 300 && h <= 320 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // MAGENTA-RED (320-340°)
  if (h > 320 && h <= 340 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // DEEP RED (340-360°)
  if (h > 340 && h <= 360 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // === BROWN (dark orange/red with low value) ===
  if (h >= 15 && h <= 45 && s >= 15 && v >= 15 && v <= 55) {
    *severity = 3;
    return true;
  }
  
  // === OLIVE (dark yellow-green) ===
  if (h >= 50 && h <= 85 && s >= 10 && v >= 15 && v <= 50) {
    *severity = 3;
    return true;
  }
  
  *severity = 0;
  return false;
}

/*
 * TRITANOPIA Detection (Blue-blind)
 * 
 * Completely different confusion axis - Blue-Yellow instead of Red-Green
 * 
 * Confusion zones:
 * 1. BLUE-GREEN confusion:
 *    - Hue 170-270° (Cyan, Blue, Blue-Violet)
 *    
 * 2. YELLOW-PINK/LIGHT confusion:
 *    - Hue 45-90° (Yellow, Yellow-Green)
 *    
 * 3. PURPLE-RED confusion (blue component not seen):
 *    - Hue 270-330° (Violet, Purple, Magenta)
 *    
 * 4. ORANGE-PINK confusion
 * 5. CYAN-WHITE confusion (low saturation blues/cyans)
 */
bool isTritanopiaConfused(HSV hsv, int* severity) {
  float h = hsv.h;
  float s = hsv.s;
  float v = hsv.v;
  
  // Very dark colors (black) - not typically confused
  if (v < 8) {
    *severity = 0;
    return false;
  }
  
  // Pure white/very light gray - distinguishable (except cyans)
  if (s < 5 && v > 85) {
    *severity = 0;
    return false;
  }
  
  // === INDIVIDUAL COLOR CHECKS - NO GROUPING ===
  
  // RED (0-10°) - Not affected in tritanopia
  // (reds are distinguishable)
  
  // RED-ORANGE (10-20°)
  if (h > 10 && h <= 20 && s >= 15) {
    *severity = 1;
    return true;
  }
  
  // ORANGE (20-35°)
  if (h > 20 && h <= 35 && s >= 12) {
    *severity = 2;
    return true;
  }
  
  // ORANGE-YELLOW (35-45°)
  if (h > 35 && h <= 45 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // YELLOW (45-60°)
  if (h > 45 && h <= 60 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // YELLOW-GREEN (60-80°)
  if (h > 60 && h <= 80 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // CHARTREUSE (80-100°)
  if (h > 80 && h <= 100 && s >= 10) {
    *severity = 2;
    return true;
  }
  
  // GREEN (100-130°) - Less affected
  if (h > 100 && h <= 130 && s >= 15) {
    *severity = 1;
    return true;
  }
  
  // GREEN-CYAN (130-160°)
  if (h > 130 && h <= 160 && s >= 12) {
    *severity = 2;
    return true;
  }
  
  // TEAL (160-175°)
  if (h > 160 && h <= 175 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // CYAN (175-195°)
  if (h > 175 && h <= 195 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // CYAN-BLUE (195-210°)
  if (h > 195 && h <= 210 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // BLUE (210-240°)
  if (h > 210 && h <= 240 && s >= 8) {
    *severity = 3;
    return true;
  }
  
  // BLUE-VIOLET (240-260°)
  if (h > 240 && h <= 260 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // VIOLET (260-280°)
  if (h > 260 && h <= 280 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // PURPLE (280-300°)
  if (h > 280 && h <= 300 && s >= 10) {
    *severity = 3;
    return true;
  }
  
  // MAGENTA (300-320°)
  if (h > 300 && h <= 320 && s >= 12) {
    *severity = 2;
    return true;
  }
  
  // MAGENTA-RED (320-340°)
  if (h > 320 && h <= 340 && s >= 12) {
    *severity = 2;
    return true;
  }
  
  // DEEP RED (340-360°)
  if (h > 340 && h <= 360 && s >= 15) {
    *severity = 1;
    return true;
  }
  
  // === NAVY (dark blue) ===
  if (h >= 200 && h <= 260 && s >= 10 && v >= 10 && v <= 45) {
    *severity = 3;
    return true;
  }
  
  *severity = 0;
  return false;
}

// --- ENHANCED COLOR NAME LOOKUP (for feedback) ---
// Maps HSV to a descriptive color name with saturation/value modifiers
// More accurate naming based on perceptual color science
String getColorNameFromHSV(HSV hsv) {
  float h = hsv.h;
  float s = hsv.s;
  float v = hsv.v;
  
  // === ACHROMATIC COLORS (very low saturation) ===
  if (s < 8) {
    if (v < 10) return "Black";
    if (v < 25) return "Dark Gray";
    if (v < 45) return "Gray";
    if (v < 65) return "Medium Gray";
    if (v < 85) return "Light Gray";
    return "White";
  }
  
  // === VERY DARK COLORS (low value) ===
  if (v < 12) return "Black";
  
  // === NEAR-NEUTRAL (low saturation) with hue tint ===
  if (s < 20 && v >= 12) {
    if (v < 35) {
      // Dark neutrals with tint
      if ((h < 30 || h >= 330)) return "Dark Brown";
      if (h < 60) return "Dark Olive";
      if (h < 150) return "Dark Olive";
      if (h < 210) return "Dark Slate";
      if (h < 270) return "Dark Slate";
      return "Dark Mauve";
    }
    // Light neutrals with tint
    if ((h < 30 || h >= 330)) return "Beige";
    if (h < 60) return "Cream";
    if (h < 150) return "Sage";
    if (h < 210) return "Pale Blue";
    if (h < 270) return "Lavender";
    return "Blush";
  }
  
  // === WASHED OUT COLORS (medium-low saturation) ===
  String prefix = "";
  if (s < 35) prefix = "Pale ";
  else if (s < 55) prefix = "";
  else if (s > 85) prefix = "Vivid ";
  
  // Value modifiers
  String vMod = "";
  if (v < 30) vMod = "Dark ";
  else if (v < 50) vMod = "Deep ";
  else if (v > 85) vMod = "Bright ";
  
  // === CHROMATIC COLORS by hue range ===
  String baseName = "";
  
  // RED RANGE (345-360, 0-10)
  if (h >= 345 || h < 10) {
    if (v < 40) baseName = "Dark Red";
    else if (s < 40) baseName = "Rose";
    else baseName = "Red";
  }
  // RED-ORANGE (10-25)
  else if (h < 25) {
    if (v < 40 && s > 40) baseName = "Brown";
    else baseName = "Red-Orange";
  }
  // ORANGE (25-40)
  else if (h < 40) {
    if (v < 50 && s > 30) baseName = "Brown";
    else if (v < 40) baseName = "Dark Orange";
    else baseName = "Orange";
  }
  // YELLOW-ORANGE / GOLD (40-50)
  else if (h < 50) {
    if (v < 50) baseName = "Olive";
    else if (s > 70) baseName = "Gold";
    else baseName = "Yellow-Orange";
  }
  // YELLOW (50-65)
  else if (h < 65) {
    if (v < 50) baseName = "Olive";
    else baseName = "Yellow";
  }
  // YELLOW-GREEN / LIME (65-85)
  else if (h < 85) {
    if (v < 40) baseName = "Dark Olive";
    else if (s > 60) baseName = "Lime";
    else baseName = "Yellow-Green";
  }
  // GREEN (85-150)
  else if (h < 150) {
    if (v < 30) baseName = "Dark Green";
    else if (v < 50) baseName = "Forest Green";
    else if (s < 50) baseName = "Sage";
    else baseName = "Green";
  }
  // TEAL / CYAN-GREEN (150-175)
  else if (h < 175) {
    if (v < 40) baseName = "Dark Teal";
    else baseName = "Teal";
  }
  // CYAN (175-200)
  else if (h < 200) {
    if (v < 40) baseName = "Dark Cyan";
    else if (s < 50) baseName = "Pale Cyan";
    else baseName = "Cyan";
  }
  // SKY BLUE / LIGHT BLUE (200-225)
  else if (h < 225) {
    if (v < 40) baseName = "Steel Blue";
    else if (s < 50) baseName = "Powder Blue";
    else baseName = "Sky Blue";
  }
  // BLUE (225-260)
  else if (h < 260) {
    if (v < 30) baseName = "Navy";
    else if (v < 50) baseName = "Dark Blue";
    else if (s < 50) baseName = "Periwinkle";
    else baseName = "Blue";
  }
  // BLUE-VIOLET / INDIGO (260-285)
  else if (h < 285) {
    if (v < 40) baseName = "Indigo";
    else baseName = "Blue-Violet";
  }
  // PURPLE / VIOLET (285-320)
  else if (h < 320) {
    if (v < 40) baseName = "Dark Purple";
    else if (s < 40) baseName = "Lavender";
    else baseName = "Purple";
  }
  // MAGENTA / PINK (320-345)
  else {
    if (s < 35) baseName = "Pink";
    else if (v < 50) baseName = "Magenta";
    else if (s > 70) baseName = "Hot Pink";
    else baseName = "Magenta";
  }
  
  // Combine modifiers (avoid redundant combinations)
  if (baseName.startsWith("Dark") || baseName.startsWith("Pale") || 
      baseName.startsWith("Bright") || baseName.startsWith("Deep")) {
    return baseName;  // Already has modifier
  }
  
  // For very saturated dark colors, prefer "Dark X" over "Deep X"
  if (v < 30) return "Dark " + baseName;
  if (v < 50 && s > 50) return "Deep " + baseName;
  if (s > 80 && v > 70) return "Vivid " + baseName;
  if (s < 40 && v > 60) return "Pale " + baseName;
  
  return baseName;
}


// --- BLE CALLBACKS (Multi-Connection) ---
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      connectedCount++;
      disconnectedUnexpectedly = false;  // Clear alarm on any reconnect
      Serial.print("Device Connected (total: ");
      Serial.print(connectedCount);
      Serial.println(")");
      
      // Play connection success melody
      connectionBeep();
      
      // Keep advertising so more devices can connect (up to MAX_CONNECTIONS)
      if (connectedCount < MAX_CONNECTIONS) {
        BLEDevice::startAdvertising();
        Serial.println("Still advertising for more connections...");
      }
    };

    void onDisconnect(BLEServer* pServer) {
      if (connectedCount > 0) connectedCount--;
      Serial.print("Device Disconnected (remaining: ");
      Serial.print(connectedCount);
      Serial.println(")");
      
      // Only alarm if ALL devices disconnected
      if (connectedCount == 0) {
        disconnectedUnexpectedly = true;
        disconnectTime = millis();
        lastDisconnectBeep = 0;
        Serial.println("All devices disconnected - alarm active");
        disconnectionBeep();
      }
      
      // Always restart advertising when a slot frees up
      BLEDevice::startAdvertising();
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
        // --- TWS CONTROL COMMANDS (from App) ---
        else if (data == "TWS_STATUS") {
           // App requests current TWS connection status
           String status = twsConnected ? "TWS:CONNECTED" : "TWS:DISCONNECTED";
           pTxCharacteristic->setValue(status.c_str());
           pTxCharacteristic->notify();
           Serial.print("[TWS CMD] Status request -> "); Serial.println(status);
        }
        else if (data.startsWith("TWS_VOL:")) {
           // App sets TWS volume (0-127)
           int vol = data.substring(8).toInt();
           vol = constrain(vol, 0, 127);
           #if A2DP_ENABLED
           a2dp_source.set_volume(vol);
           #endif
           Serial.print("[TWS CMD] Volume set to: "); Serial.println(vol);
           // Confirm back to app
           String msg = "TWS:VOL:" + String(vol);
           pTxCharacteristic->setValue(msg.c_str());
           pTxCharacteristic->notify();
        }
        else if (data == "TWS_DISCONNECT") {
           // App requests TWS disconnect
           if (twsConnected) {
             #if A2DP_ENABLED
             a2dp_source.disconnect();
             #endif
             Serial.println("[TWS CMD] Disconnect requested");
             pTxCharacteristic->setValue("TWS:DISCONNECTING");
             pTxCharacteristic->notify();
           }
        }
        else if (data == "TWS_RECONNECT") {
           // App requests TWS reconnect
           if (!twsConnected) {
             Serial.println("[TWS CMD] Reconnect requested");
             #if A2DP_ENABLED
             a2dp_source.start(a2dp_audio_callback, tws_device_filter);
             #endif
             pTxCharacteristic->setValue("TWS:SCANNING");
             pTxCharacteristic->notify();
           }
        }
        else if (data == "TWS_TEST") {
           // App requests a test tone on TWS
           if (twsConnected) {
             enqueueTone(1047, 150, 50);  // C5
             enqueueTone(1319, 150, 50);  // E5
             enqueueTone(1568, 200);       // G5
             Serial.println("[TWS CMD] Test tone playing");
             pTxCharacteristic->setValue("TWS:TEST_PLAYING");
             pTxCharacteristic->notify();
           } else {
             pTxCharacteristic->setValue("TWS:NOT_CONNECTED");
             pTxCharacteristic->notify();
           }
        }
        // Handle Calibration Command
        else if (data == "CALIBRATE" || data == "CAL") {
           // White balance calibration - point sensor at white surface
           Serial.println("Calibrating white balance...");
           
           // Read current values
           uint32_t rSum = 0, gSum = 0, bSum = 0;
           int calSamples = 10;
           
           for (int i = 0; i < calSamples; i++) {
             if (SENSOR_TYPE == 1) {
               uint16_t r_temp, g_temp, b_temp, c_temp;
               tcs.getRawData(&r_temp, &g_temp, &b_temp, &c_temp);
               rSum += r_temp;
               gSum += g_temp;
               bSum += b_temp;
             } else {
               digitalWrite(S2, LOW); digitalWrite(S3, LOW);
               rSum += pulseIn(SENSOR_OUT, LOW, 50000);
               digitalWrite(S2, HIGH); digitalWrite(S3, HIGH);
               gSum += pulseIn(SENSOR_OUT, LOW, 50000);
               digitalWrite(S2, LOW); digitalWrite(S3, HIGH);
               bSum += pulseIn(SENSOR_OUT, LOW, 50000);
             }
             delay(20);
           }
           
           float rAvg = rSum / (float)calSamples;
           float gAvg = gSum / (float)calSamples;
           float bAvg = bSum / (float)calSamples;
           
           // Calculate calibration multipliers to equalize RGB
           float maxAvg = max(max(rAvg, gAvg), bAvg);
           if (maxAvg > 0) {
             calR = maxAvg / rAvg;
             calG = maxAvg / gAvg;
             calB = maxAvg / bAvg;
           }
           
           Serial.print("Calibration: R="); Serial.print(calR, 3);
           Serial.print(" G="); Serial.print(calG, 3);
           Serial.print(" B="); Serial.println(calB, 3);
           
           // Confirmation beeps
           sharpBeep(1500, 100);
           delay(100);
           sharpBeep(2000, 100);
           delay(100);
           sharpBeep(2500, 150);
        }
        // Handle CVD Types
        else if (data == "protanopia") cvdType = "protanopia";
        else if (data == "deuteranopia") cvdType = "deuteranopia";
        else if (data == "tritanopia") cvdType = "tritanopia";
        else if (data == "none") cvdType = "none";

        // Handle Sensitivity Adjustment
        else if (data.startsWith("SENS:")) {
           // Adjust detection sensitivity (1-10 scale)
           // Lower = more sensitive (more alerts), Higher = less sensitive
           // Not implemented in this version but reserved for future
           Serial.println("Sensitivity adjustment not yet implemented");
        }
        
        // Legacy Support
        else {
          if (data == "P") cvdType = "protanopia";
          else if (data == "D") cvdType = "deuteranopia"; 
          else if (data == "T") cvdType = "tritanopia";
          else if (data == "N") cvdType = "none";
        }
        
        Serial.print("Received Data: "); Serial.println(data);
        Serial.print("CVD Type set to: "); Serial.println(cvdType);
        
        // Acknowledge via Buzzer (Sharp blip)
        ackBeep();
      }
    }
};


void setup() {
  Serial.begin(115200);

  // Buzzer PWM Setup for louder, sharper sound (ESP32 Core 3.x API)
  ledcAttach(BUZZER_PIN, BUZZER_FREQ_HIGH, BUZZER_RESOLUTION);
  ledcWrite(BUZZER_PIN, 0);  // Start silent
  
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

  // --- A2DP SOURCE SETUP (Classic Bluetooth - connect to TWS speakers) ---
  #if A2DP_ENABLED
  Serial.println("[A2DP] A2DP ENABLED - ESP32 will connect to TWS for beep tones");
  Serial.println("[A2DP] Note: Phone should NOT connect to TWS when A2DP is enabled");
  Serial.print("[A2DP] Looking for devices matching: ");
  Serial.print(TARGET_TWS_NAME);
  Serial.print(" or ");
  Serial.println(TARGET_TWS_NAME_ALT);
  
  a2dp_source.set_volume(100);
  a2dp_source.set_auto_reconnect(true);
  a2dp_source.start(a2dp_audio_callback, tws_device_filter);
  delay(1000);
  
  twsConnected = a2dp_source.is_connected();
  if (twsConnected) {
    Serial.println("[A2DP] TWS connected!");
  } else {
    Serial.println("[A2DP] TWS not found yet - will keep scanning...");
  }
  #else
  Serial.println("[A2DP] A2DP DISABLED - Pair TWS with PHONE for spoken color names");
  Serial.println("[A2DP] Phone TTS will announce colors through TWS earphones");
  #endif

  // --- BLE SETUP (for phone communication) ---
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
  
  // Start BLE Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("Waiting for BLE connection from phone...");
  Serial.println("=== Colaid Ready (BLE + A2DP Dual Mode) ===");
}

void loop() {
  unsigned long currentMillis = millis();

  // --- LED STATUS LIGHT LOGIC ---
  // LED blink speed: solid=all slots full, slow=partial, fast=none connected
  long blinkInterval;
  if (connectedCount >= MAX_CONNECTIONS) blinkInterval = 0;       // Solid ON when full
  else if (connectedCount > 0)          blinkInterval = 2000;    // Slow blink when partially connected
  else                                  blinkInterval = 200;     // Fast blink when no connections

  if (blinkInterval == 0) {
    digitalWrite(LED_PIN, HIGH);  // Solid on
  } else if (currentMillis - lastBlinkTime >= blinkInterval) {
    lastBlinkTime = currentMillis;
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState);
  }

  if (connectedCount > 0) {
    uint16_t r, g, b, c;
    String detectedColor = "Unknown";
    bool sensorSuccess = false;
    bool problem = false;
    int severity = 0;

    // 1. READ COLOR WITH MULTI-SAMPLE AVERAGING
    if (isSensorWorking) {
      if (SENSOR_TYPE == 1) {
         // TCS34725 (I2C) - Multi-sample averaging
         uint32_t rSum = 0, gSum = 0, bSum = 0, cSum = 0;
         for (int i = 0; i < NUM_SAMPLES; i++) {
           uint16_t r_temp, g_temp, b_temp, c_temp;
           tcs.getRawData(&r_temp, &g_temp, &b_temp, &c_temp);
           rSum += r_temp;
           gSum += g_temp;
           bSum += b_temp;
           cSum += c_temp;
           delay(SAMPLE_DELAY_MS);
         }
         r = rSum / NUM_SAMPLES;
         g = gSum / NUM_SAMPLES;
         b = bSum / NUM_SAMPLES;
         c = cSum / NUM_SAMPLES;
         
         // Normalize to 0-255 range with calibration
         if (c > 0) {
           float scale = 255.0f / (float)c;
           r = constrain((int)(r * scale * calR), 0, 255);
           g = constrain((int)(g * scale * calG), 0, 255);
           b = constrain((int)(b * scale * calB), 0, 255);
         }
         sensorSuccess = true;
         
      } else if (SENSOR_TYPE == 2) {
         // TCS3200 - Multi-sample averaging with calibrated mapping
         uint32_t rSum = 0, gSum = 0, bSum = 0, cSum = 0;
         
         for (int i = 0; i < NUM_SAMPLES; i++) {
           digitalWrite(S2, LOW); digitalWrite(S3, LOW);
           rSum += pulseIn(SENSOR_OUT, LOW, 50000);  // 50ms timeout
           digitalWrite(S2, HIGH); digitalWrite(S3, HIGH);
           gSum += pulseIn(SENSOR_OUT, LOW, 50000);
           digitalWrite(S2, LOW); digitalWrite(S3, HIGH);
           bSum += pulseIn(SENSOR_OUT, LOW, 50000);
           digitalWrite(S2, HIGH); digitalWrite(S3, LOW);
           cSum += pulseIn(SENSOR_OUT, LOW, 50000);
           delay(SAMPLE_DELAY_MS);
         }
         
         uint32_t r_pulse = rSum / NUM_SAMPLES;
         uint32_t g_pulse = gSum / NUM_SAMPLES;
         uint32_t b_pulse = bSum / NUM_SAMPLES;
         c = cSum / NUM_SAMPLES;
  
         if (r_pulse == 0) r_pulse = 1; 
         if (g_pulse == 0) g_pulse = 1; 
         if (b_pulse == 0) b_pulse = 1;
         
         // Calibrated mapping with individual channel calibration
         r = map(constrain(r_pulse, TCS3200_R_MIN, TCS3200_R_MAX), TCS3200_R_MIN, TCS3200_R_MAX, 255, 0);
         g = map(constrain(g_pulse, TCS3200_G_MIN, TCS3200_G_MAX), TCS3200_G_MIN, TCS3200_G_MAX, 255, 0);
         b = map(constrain(b_pulse, TCS3200_B_MIN, TCS3200_B_MAX), TCS3200_B_MIN, TCS3200_B_MAX, 255, 0);
         
         // Apply calibration multipliers
         r = constrain((int)(r * calR), 0, 255);
         g = constrain((int)(g * calG), 0, 255);
         b = constrain((int)(b * calB), 0, 255);
         
         // Apply gamma correction for perceptual accuracy
         r = (int)gammaCorrect(r);
         g = (int)gammaCorrect(g);
         b = (int)gammaCorrect(b);
         
         sensorSuccess = true;
      }
    }

    // 2. VALIDATE & PROCESS COLOR - with improved light level check
    // Minimum light level for accurate color detection
    // TCS34725: c > 50 for good accuracy, TCS3200: c > 15
    int minLightLevel = (SENSOR_TYPE == 1) ? 50 : 15;
    
    if (sensorSuccess && c > minLightLevel) { 
        // Convert RGB to HSV for comprehensive color wheel analysis
        HSV hsv = rgbToHSV(r, g, b);
        detectedColor = getColorNameFromHSV(hsv);
        
        // 3. CVD CHECK - Use HSV-based FULL COLOR WHEEL detection
        // This covers ALL ranges of colors (not just predefined names)
        // Detection is based on scientific CVD confusion axes
        
        if (cvdType == "protanopia") {
          // Protanopia: Red-Green confusion axis
          // Covers entire red-green spectrum including all intermediate hues
          problem = isProtanopiaConfused(hsv, &severity);
        } 
        else if (cvdType == "deuteranopia") {
          // Deuteranopia: Similar to protanopia but with different perception
          // Covers wider green range and different yellows
          problem = isDeuteranopiaConfused(hsv, &severity);
        } 
        else if (cvdType == "tritanopia") {
          // Tritanopia: Blue-Yellow confusion axis
          // Completely different from red-green CVD types
          problem = isTritanopiaConfused(hsv, &severity);
        }
        
        // Debug: Print HSV values for calibration
        Serial.print("RGB("); Serial.print(r); Serial.print(",");
        Serial.print(g); Serial.print(","); Serial.print(b); Serial.print(") -> HSV(");
        Serial.print(hsv.h, 1); Serial.print(","); 
        Serial.print(hsv.s, 1); Serial.print(","); 
        Serial.print(hsv.v, 1); Serial.print(") = ");
        Serial.print(detectedColor);
        if (problem) {
          Serial.print(" [ALERT Sev:"); Serial.print(severity); Serial.print("]");
        }
        Serial.println();
        
        // 4. FEEDBACK LOGIC with MULTICOLOR SUPPORT
        // - Problem colors: Alert beeps based on severity
        // - Visible colors: Optional confirmation chirp
        // - Uses stability tracking to avoid flickering alerts
        
        // Update color history for stability
        bool isStable = updateColorHistory(detectedColor);
        bool isNewColor = !areColorsSimilar(detectedColor, lastDetectedColor);
        unsigned long now = millis();
        
        if (problem && isNewColor && isStable) {
           // INDISTINGUISHABLE COLOR DETECTED
           // Buzzer Feedback - Sharp PWM beeps based on severity
           // Higher severity = more beeps + higher pitch
           for (int beep = 0; beep < severity; beep++) {
             alertBeep(severity);  // Sharp PWM tone
             if (beep < severity - 1) {
               delay(80);  // Short gap between beeps
             }
           }
           
           // Send to Phone with CONFUSED marker
           if (audioEnabled) {
               String message = "CONFUSED:" + detectedColor;
               pTxCharacteristic->setValue(message.c_str());
               pTxCharacteristic->notify();
           }
           
           // Debug output
           Serial.print("[CONFUSED] "); Serial.print(detectedColor);
           Serial.print(" (Sev:"); Serial.print(severity); 
           Serial.print(", Stable:"); Serial.print(stableColorCount); Serial.println(")");
           
           lastDetectedColor = detectedColor;
           lastColorChangeTime = now;
           delay(600);  // Debounce delay
           
        } else if (!problem && isNewColor && isStable) {
           // VISIBLE/DISTINGUISHABLE COLOR - User can see this correctly
           
           // Optional confirmation beep for visible colors
           if (VISIBLE_CONFIRM_ENABLED && (now - lastColorChangeTime > 1500)) {
             visibleConfirmBeep();
           }
           
           // Send to Phone with VISIBLE marker
           if (audioEnabled) {
               String message = "VISIBLE:" + detectedColor;
               pTxCharacteristic->setValue(message.c_str());
               pTxCharacteristic->notify();
           }
           
           // Debug output  
           Serial.print("[VISIBLE] "); Serial.println(detectedColor);
           
           lastDetectedColor = detectedColor;
           lastVisibleColor = detectedColor;
           lastColorChangeTime = now;
           delay(300);  // Shorter delay for visible colors
        }
    }
  }

  // Reconnecting - detect transitions in connection count
  if (connectedCount == 0 && oldConnectedCount > 0) {
      delay(500);
      pServer->startAdvertising();
      Serial.println("Advertising started (all disconnected)");
  }
  oldConnectedCount = connectedCount;
  
  // === DISCONNECT ALARM - repeating beep while ALL devices disconnected ===
  if (disconnectedUnexpectedly && connectedCount == 0) {
    unsigned long elapsed = millis() - disconnectTime;
    if (elapsed < DISCONNECT_ALARM_DURATION) {
      // Beep every DISCONNECT_ALARM_INTERVAL ms
      if (millis() - lastDisconnectBeep >= DISCONNECT_ALARM_INTERVAL) {
        lastDisconnectBeep = millis();
        disconnectionBeep();
        Serial.println("Disconnect alarm beep");
      }
    } else {
      // Stop alarming after duration expires
      disconnectedUnexpectedly = false;
      Serial.println("Disconnect alarm ended - still advertising");
    }
  }

  // === A2DP TWS CONNECTION MONITORING ===
  // Track TWS connection state and attempt reconnection if lost
  #if A2DP_ENABLED
  bool currentTwsState = a2dp_source.is_connected();
  #else
  bool currentTwsState = false;
  #endif
  
  if (currentTwsState && !twsConnected) {
    // TWS just connected
    twsConnected = true;
    Serial.println("[A2DP] TWS speakers connected!");
    // Play a confirmation tone through TWS
    enqueueTone(1047, 100, 50);  // C5
    enqueueTone(1319, 100, 50);  // E5
    enqueueTone(1568, 150);       // G5
    // Notify phone app about TWS connection
    if (connectedCount > 0) {
      pTxCharacteristic->setValue("TWS:CONNECTED");
      pTxCharacteristic->notify();
    }
  } else if (!currentTwsState && twsConnected) {
    // TWS just disconnected
    twsConnected = false;
    Serial.println("[A2DP] TWS speakers disconnected!");
    // Notify phone app about TWS disconnection
    if (connectedCount > 0) {
      pTxCharacteristic->setValue("TWS:DISCONNECTED");
      pTxCharacteristic->notify();
    }
  }
  
  // Periodically retry TWS connection if not connected
  if (!twsConnected && (millis() - lastTwsReconnectAttempt > TWS_RECONNECT_INTERVAL)) {
    lastTwsReconnectAttempt = millis();
    Serial.println("[A2DP] Retrying TWS connection...");
    // A2DP auto-reconnect handles this, but we log the attempt
  }
}
