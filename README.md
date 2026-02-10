# 🎨 Colaid — Wearable-Assisted Color Vision Aid

<p align="center">
  <img src="colaid/assets/colaid_eye.png" alt="Colaid Logo" width="150"/>
</p>

<p align="center">
  <strong>Real-time, hands-free color identification and correction for people with Color Vision Deficiency (CVD)</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.10.3-0175C2?logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/ESP32-Arduino-E7352C?logo=espressif" alt="ESP32"/>
  <img src="https://img.shields.io/badge/Python-Flask-3776AB?logo=python" alt="Flask"/>
  <img src="https://img.shields.io/badge/Firebase-Auth-FFCA28?logo=firebase" alt="Firebase"/>
  <img src="https://img.shields.io/badge/MongoDB-Atlas-47A248?logo=mongodb" alt="MongoDB"/>
</p>

---

## 📖 Overview

**Colaid** is an integrated three-tier assistive technology system that helps individuals with Color Vision Deficiency (CVD) — commonly known as color blindness — identify and correct colors in real time. It combines **smart eyewear hardware**, a **cross-platform mobile application**, and a **cloud backend** into a unified solution.

Approximately 300 million people worldwide live with CVD. Existing solutions are either passive (expensive optical lenses) or screen-dependent (phone filter apps). Colaid bridges this gap with hands-free, intelligent, real-time color assistance.

### Supported CVD Types
- **Protanopia** — Red-blind (missing L-cones)
- **Deuteranopia** — Green-blind (missing M-cones)
- **Tritanopia** — Blue-blind (missing S-cones)

---

## 🏗️ Architecture

```
┌─────────────────────────┐     BLE UART      ┌──────────────────────────────┐
│   SMART EYEWEAR (ESP32) │◄──────────────────►│   FLUTTER MOBILE APP         │
│                         │  CVD Config ↔      │                              │
│  • TCS3200/TCS34725     │  Color Data        │  • Ishihara Test             │
│  • HSV Color Classify   │                    │  • BLE Eyewear Control       │
│  • CVD Confusion Detect │                    │  • Camera + Daltonization    │
│  • Buzzer Alerts        │                    │  • TTS Audio Feedback        │
│  • A2DP Audio (opt.)    │                    │  • Settings & Accessibility  │
└─────────────────────────┘                    └──────────┬───────────────────┘
                                                          │ HTTP REST
                                                          ▼
                                               ┌──────────────────────────────┐
                                               │   FLASK CLOUD BACKEND        │
                                               │                              │
                                               │  • Daltonization API         │
                                               │  • User Auth (Firebase +     │
                                               │    Flask-Login)              │
                                               │  • MongoDB Atlas             │
                                               └──────────────────────────────┘
```

---

## 📁 Repository Structure

```
Colaid/
├── colaid/                     # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart           # App entry point, Firebase init, routing
│   │   ├── pages/              # 16 UI pages
│   │   │   ├── welcome_page.dart
│   │   │   ├── login_page.dart
│   │   │   ├── register_page.dart
│   │   │   ├── home_page.dart
│   │   │   ├── ishihara_test_page.dart
│   │   │   ├── test_result_page.dart
│   │   │   ├── results_history_page.dart
│   │   │   ├── camera_page.dart
│   │   │   ├── camera_preview_page.dart
│   │   │   ├── image_preview_page.dart
│   │   │   ├── live_video_preview_page.dart
│   │   │   ├── eyewear_page.dart
│   │   │   ├── settings_page.dart
│   │   │   ├── legend_page.dart
│   │   │   ├── saved_images_page.dart
│   │   │   └── test_result_history_page.dart
│   │   ├── services/
│   │   │   ├── bluetooth_service.dart   # BLE UART + TTS singleton
│   │   │   └── user_service.dart        # User data persistence
│   │   ├── providers/
│   │   │   └── theme_provider.dart      # App-wide state (theme, CVD, font)
│   │   ├── widgets/
│   │   │   └── before_after_slider.dart # Image comparison slider
│   │   └── utils/
│   │       └── color_utils.dart         # Pixel color name detection
│   ├── assets/                 # Ishihara plates, app icon
│   ├── android/                # Android build config
│   ├── ios/                    # iOS build config
│   └── pubspec.yaml            # Flutter dependencies
│
├── colaid_backend/             # Python Flask backend
│   ├── app.py                  # REST API server
│   ├── daltonize.py            # Brettel/Viénot daltonization engine
│   ├── models.py               # User model (MongoDB + Werkzeug)
│   ├── requirements.txt        # Python dependencies
│   └── uploads/                # Temporary image storage
│
├── colaid_firmware/            # ESP32 Arduino firmware
│   └── colaid_firmware.ino     # Complete firmware (~1,670 lines)
│
└── README.md                   # This file
```

---

## ✨ Key Features

### 🔬 Color Vision Diagnosis
- Built-in **Ishihara screening test** (12 randomized plates from a 17-plate bank)
- Automated CVD type classification (protanopia / deuteranopia / tritanopia / normal)
- Test result history with persistent local storage

### 👓 Real-Time Color Detection (Smart Eyewear)
- Continuous color sensing via **TCS3200 / TCS34725** sensor
- Full 360° HSV color wheel classification into **30+ named colors**
- CVD-specific confusion zone detection with **3-level severity scoring**
- **Stability filtering** (7-reading buffer, 4+ match threshold) to eliminate false positives
- **Severity-graded buzzer alerts** (2,200 Hz mild / 2,800 Hz moderate / 3,500 Hz severe)

### 🔊 Audio Feedback
- **Text-to-Speech** color announcements via FlutterTTS
  - `CONFUSED:Red` → *"Warning. Red. This color may be hard to distinguish."*
  - `VISIBLE:Green` → *"Green"*
- Auto-routes to **TWS Bluetooth earphones** for discreet hands-free feedback
- Connection/disconnection melodies and disconnect alarm
- Optional **A2DP direct tone streaming** from ESP32 to TWS

### 📸 Camera-Based Image Daltonization
- Capture photo, record video, or upload from gallery
- Server-side **Brettel/Viénot daltonization** with gamma-linearized correction
- Interactive **before/after comparison slider**
- **Tap-to-identify** any pixel's color with TTS readout
- Save enhanced images to device gallery

### 📱 BLE Eyewear Management
- One-tap BLE scanning and connection
- Bidirectional data exchange (CVD config → eyewear; color data → phone)
- Multi-connection support (up to 3 simultaneous clients)

### 🔐 User Authentication
- **Firebase Auth** with Google Sign-In
- **Flask backend** email/password registration with PBKDF2 hashing
- Guest login, password reset, account deletion
- Session persistence across app restarts

### ♿ Accessibility & Personalization
- Dark mode and **high contrast mode**
- Adjustable font size (Small / Medium / Large)
- Manual CVD type override
- Per-user persistent preferences via SharedPreferences

---

## 🛠️ Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Mobile App** | Flutter / Dart | SDK ^3.10.3 |
| **State Management** | Provider | ^6.0.5 |
| **BLE** | flutter_blue_plus | ^2.1.0 |
| **TTS** | flutter_tts | ^4.2.3 |
| **Auth (Client)** | Firebase Auth + Google Sign-In | ^6.1.2 / ^7.2.0 |
| **Backend** | Flask + Gunicorn | Latest |
| **Image Processing** | OpenCV + NumPy | opencv-python / <2.0.0 |
| **Database** | MongoDB Atlas | PyMongo ^4.6 |
| **Auth (Server)** | Flask-Login + Werkzeug | Latest |
| **Microcontroller** | ESP32 (Arduino framework) | Dual-core 240 MHz |
| **Color Sensor** | TCS3200 / TCS34725 (Adafruit) | I2C / GPIO |
| **BLE Protocol** | Nordic UART Service (NUS) | BLE 4.2 |
| **Audio Streaming** | ESP32-A2DP (optional) | A2DP Source |

---

## 🚀 Getting Started

### Prerequisites

- **Flutter** SDK ≥ 3.10.3
- **Python** 3.8+
- **Arduino IDE** with ESP32 board package
- **MongoDB Atlas** account (free tier works)
- **Firebase** project configured via `flutterfire configure`

### 1. Clone the Repository

```bash
git clone https://github.com/aswinrp777/Colaid.git
cd Colaid
```

### 2. Flutter Mobile App

```bash
cd colaid

# Create a .env file with your backend URL
echo "API_URL=http://YOUR_IP:5000" > .env

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### 3. Flask Backend

```bash
cd colaid_backend

# Create virtual environment
python -m venv venv
source venv/bin/activate        # Linux/macOS
# venv\Scripts\activate         # Windows

# Install dependencies
pip install -r requirements.txt

# Create a .env file
echo "MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/colaid" > .env
echo "SECRET_KEY=your-secret-key" >> .env

# Run the server
python app.py
```

The backend will start at `http://0.0.0.0:5000`.

### 4. ESP32 Firmware

1. Open `colaid_firmware/colaid_firmware.ino` in **Arduino IDE**
2. Install required libraries via Library Manager:
   - `Adafruit TCS34725`
   - `ESP32 BLE Arduino` (built-in with ESP32 board package)
   - `ESP32-A2DP` by Phil Schatzmann (optional, for TWS audio)
3. Select board: **ESP32 Dev Module**
4. Configure sensor type at line: `#define SENSOR_TYPE 2` (1 = TCS34725 I2C, 2 = TCS3200)
5. Upload to ESP32

#### Wiring (TCS3200)
| ESP32 Pin | Sensor Pin |
|-----------|-----------|
| GPIO 18 | S0 |
| GPIO 19 | S1 |
| GPIO 21 | S2 |
| GPIO 22 | S3 |
| GPIO 23 | OUT |
| GPIO 4 | Buzzer (+) |
| GPIO 2 | Onboard LED |

#### Wiring (TCS34725 — I2C)
| ESP32 Pin | Sensor Pin |
|-----------|-----------|
| GPIO 21 | SDA |
| GPIO 22 | SCL |
| GPIO 4 | Buzzer (+) |

---

## 📡 Communication Protocol

### BLE UART Service

| UUID | Direction | Purpose |
|------|-----------|---------|
| `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | — | Service UUID |
| `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` | Phone → ESP32 | Write CVD type, commands |
| `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` | ESP32 → Phone | Notify color data |

### Message Format

**ESP32 → Phone:**
| Prefix | Example | Meaning |
|--------|---------|---------|
| `CONFUSED:` | `CONFUSED:Red` | Color the user cannot distinguish |
| `VISIBLE:` | `VISIBLE:Blue` | Color the user can see correctly |
| `TWS:` | `TWS:CONNECTED` | TWS earphone status update |

**Phone → ESP32:**
| Command | Description |
|---------|-------------|
| `P` / `D` / `T` / `N` | Set CVD type (Protan/Deutan/Tritan/Normal) |
| `AUDIO_ON` / `AUDIO_OFF` | Toggle buzzer alerts |
| `TWS_STATUS` | Request TWS connection status |
| `TWS_VOL:0-127` | Set TWS volume |
| `TWS_DISCONNECT` | Disconnect from TWS |
| `TWS_RECONNECT` | Reconnect to TWS |
| `TWS_TEST` | Play test tone through TWS |

### REST API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Health check |
| `GET` | `/mongo-test` | MongoDB connectivity test |
| `POST` | `/daltonize` | Upload image + defect type → returns corrected PNG |
| `POST` | `/register` | Create new account (username + password) |
| `POST` | `/login` | Authenticate user |
| `POST` | `/logout` | End session |
| `POST` | `/reset-password` | Change password (authenticated) |
| `POST` | `/delete-account` | Delete account (authenticated) |
| `POST` | `/guest-login` | Login as guest user |

---

## 🔬 How Daltonization Works

1. **Input:** BGR image from OpenCV
2. **Linearize:** Convert sRGB to linear light (γ = 2.4 decode)
3. **Simulate:** Multiply by CVD simulation matrix (Brettel/Viénot model)
4. **Error:** Compute difference between original and simulated image
5. **Correct:** Redistribute lost channel info into perceivable channels:
   - Protanopia: Red error → Green (0.7×) + Blue (1.0×)
   - Deuteranopia: Green error → Red (1.0×) + Blue (0.7×)
   - Tritanopia: Blue error → Red (0.7×) + Green (1.0×)
6. **Apply:** Add correction × 1.5 to original linearized image
7. **Output:** De-linearize back to sRGB and return as PNG

---

## 🔊 Buzzer Alert Patterns

| Pattern | Frequency | Duration | Meaning |
|---------|-----------|----------|---------|
| Single high beep | 3,500 Hz | 180 ms | Severe confusion (e.g., red for protanope) |
| Single medium beep | 2,800 Hz | 150 ms | Moderate confusion (e.g., orange) |
| Single low beep | 2,200 Hz | 120 ms | Mild confusion (e.g., cyan-blue) |
| Gentle short beep | 1,200 Hz | 80 ms | Visible color confirmation |
| Ascending melody | C5→E5→G5→C6 | 480 ms | BLE connected |
| Descending melody | G5→E5→C5 | 450 ms | BLE disconnected |
| Periodic beep | Every 3s | 20s total | Unexpected disconnect alarm |
| Double chirp | 1,500→1,800 Hz | 110 ms | Multicolor scene detected |

---

## 📱 App Screenshots

| Welcome | Home | Ishihara Test | Eyewear |
|---------|------|---------------|---------|
| Login & onboarding | Dashboard with quick actions | 12-plate color vision screening | BLE scan & connect |

| Camera | Daltonize | Settings | Legend |
|--------|-----------|----------|--------|
| Photo/Video/Upload | Before/After slider | Theme, font, CVD type | Color transformation map |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## 📄 License

This project is developed as an academic/research project. See [LICENSE](LICENSE) for details.

---

## 👥 Team

**Colaid** — Making the world more colorful for everyone.

---

<p align="center">
  Built with ❤️ using Flutter, ESP32, and Flask
</p>
