#include <DHT.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <WebServer.h>
#include <BluetoothSerial.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>

// Library: "Firebase Arduino Client Library for ESP8266 and ESP32" by mobizt
// (Arduino Library Manager: search "Firebase ESP Client").
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"

// ===== PINS =====
#define DHT_PIN    4
#define LDR_DO     14
#define LDR_AO     34
#define MQ2_DO     26
#define MQ2_AO     35
#define BUZZER_PIN 16
#define LED1_PIN   17 //Gas Alarm Led
#define LED2_PIN   25 //LDR LED
#define BTN_PIN    33
#define RFID_SS    5
#define RFID_RST   27
#define LED_GREEN  32
#define LED_RED    13
#define SERVO_PIN  15
#define MQ2_PWR    0   // MOSFET Gate للـ MQ2
#define LCD_PWR    2   // MOSFET Gate للـ LCD

// ===== WIFI =====
const char* ssid     = "Hgz";
const char* password = "7746!@#%*ijygf";

// ===== FIREBASE =====
// Not secret — Firebase's security model is the Realtime Database Rules,
// not hiding this key. Must match the values in the website's .env and the
// Flutter app's lib/firebase_options.dart (same Firebase project).
#define FIREBASE_API_KEY      "AIzaSyDmIOfbe1nA3c3NAFRZwBwK9FykqYkn27M"
#define FIREBASE_DATABASE_URL "https://ecosystem-controller-default-rtdb.firebaseio.com"
// Must match VITE_FIREBASE_DEVICE_ID (website) and kFirebaseDeviceId (app).
const String FIREBASE_DEVICE_ID = "esp32-01";

// ===== CONSTANTS =====
const int          GAS_BASELINE          = 1500;
const unsigned long debounceDelay         = 50;
const unsigned long dhtReadInterval       = 2000;
const unsigned long gasAlarmBlinkInterval = 200;
const unsigned long gasDisplayInterval    = 500;
const unsigned int  buzzerFrequency       = 1000;
const int          MAX_WRONG_ATTEMPTS     = 3;
const unsigned long LOCKOUT_DURATION      = 60000;
const String       ALLOWED_UID           = "03DE1D09";

// ===== SYSTEM STATE =====
bool systemOn    = true;
bool gasSensorOn = true;
bool tempSensorOn= true;
bool ledSensorOn = true;
bool pirSensorOn = true;
bool ldrSensorOn = true;
bool buzzerOn    = true;
bool autoLightOn = true;
bool mq2PwrOn    = true;   // حالة كهربا MQ2
bool lcdPwrOn    = true;   // حالة كهربا LCD

// ===== VARIABLES =====
bool led2On            = false;
bool lastButtonReading = HIGH;
bool stableButtonState = HIGH;
bool lastLdrState      = LOW;
bool gasAlarmActive    = false;
bool gasAlarmOutputOn  = false;
bool isLocked          = true;
int  wrongAttempts     = 0;
bool isLockedOut       = false;
unsigned long lockoutStartTime       = 0;
unsigned long lastDebounceTime       = 0;
unsigned long lastDhtReadTime        = 0;
unsigned long lastGasAlarmToggleTime = 0;
unsigned long lastGasDisplayTime     = 0;
float temperature    = 0;
float humidity       = 0;
bool  hasDhtReading  = false;
bool  gasDetectedFlag= false;
bool  useWifi        = false;

// ===== OBJECTS =====
DHT dht(DHT_PIN, DHT11);
LiquidCrystal_I2C lcd(0x27, 16, 2);
MFRC522 rfid(RFID_SS, RFID_RST);
WebServer server(8080);
BluetoothSerial SerialBT;
Servo doorServo;

FirebaseData   fbdo;         // used for one-off writes (reported status)
FirebaseData   fbdoStream;   // dedicated connection for the desired-state stream
FirebaseAuth   fbAuth;
FirebaseConfig fbConfig;
bool firebaseReady = false;
unsigned long lastFirebasePush = 0;
const unsigned long firebasePushInterval = 2000; // heartbeat, same cadence as app polling

// ===== LCD HELPERS =====
void lcdClearLine(byte row) {
  if (!lcdPwrOn) return;
  lcd.setCursor(0, row);
  lcd.print("                ");
  lcd.setCursor(0, row);
}

void showLockedScreen() {
  if (gasAlarmActive || !lcdPwrOn) return;
  lcd.setCursor(0, 0);
  lcd.print("LOCKED          ");
  lcd.setCursor(0, 1);
  lcd.print("ENTER CODE      ");
}

void showUnlockedScreen() {
  if (!lcdPwrOn) return;
  lcd.setCursor(0, 0);
  lcd.print("UNLOCKED!!      ");
  lcd.setCursor(0, 1);
  lcd.print("ACCESS GRANTED  ");
}

void showDeniedScreen() {
  if (!lcdPwrOn) return;
  lcd.setCursor(0, 0);
  lcd.print("ACCESS DENIED!  ");
  lcd.setCursor(0, 1);
  lcd.print("TRY AGAIN       ");
}

void showLockoutScreen(int secondsLeft) {
  if (!lcdPwrOn) return;
  lcd.setCursor(0, 0);
  lcd.print("TOO MANY TRIES! ");
  lcd.setCursor(0, 1);
  lcd.print("WAIT: ");
  lcd.print(secondsLeft);
  lcd.print("s      ");
}

void showDhtState() {
  if (gasAlarmActive || !lcdPwrOn) return;
  lcdClearLine(1);
  if (!hasDhtReading) {
    lcd.print("DHT error");
    return;
  }
  lcd.print("T:");
  lcd.print((int)temperature);
  lcd.print("C H:");
  lcd.print((int)humidity);
  lcd.print("%");
}

void showHomeScreen() {
  if (!lcdPwrOn) return;
  lcd.setCursor(0, 0);
  lcd.print("LED2: ");
  lcd.print(led2On ? "ON " : "OFF");
  lcd.print("         ");
  showDhtState();
}

// ===== JSON STATUS =====
String getStatusJson() {
  StaticJsonDocument<512> doc;
  doc["system"]      = systemOn;
  doc["gasSensor"]   = gasSensorOn;
  doc["tempSensor"]  = tempSensorOn;
  doc["ledSensor"]   = ledSensorOn;
  doc["pirSensor"]   = pirSensorOn;
  doc["ldrSensor"]   = ldrSensorOn;
  doc["buzzer"]      = buzzerOn;
  doc["autoLight"]   = autoLightOn;
  doc["mq2Pwr"]      = mq2PwrOn;
  doc["lcdPwr"]      = lcdPwrOn;
  doc["temperature"] = temperature;
  doc["humidity"]    = humidity;
  doc["gasDetected"] = gasDetectedFlag;
  doc["led2"]        = led2On;
  doc["locked"]      = isLocked;
  doc["gasPercent"]  = constrain(map(analogRead(MQ2_AO), GAS_BASELINE, 4095, 0, 100), 0, 100);

  String json;
  serializeJson(doc, json);
  return json;
}

// ===== SHARED CONTROL APPLICATION =====
// Applies a control command from any source (local HTTP, Bluetooth, or a
// Firebase `desired` update) to the actual system state/pins. Used to be
// duplicated between handleControl() and handleBluetooth(); now shared so
// Firebase behaves identically to the other two paths.
void applyControlFromJson(JsonDocument &doc) {
  if (doc.containsKey("system"))     systemOn     = doc["system"];
  if (doc.containsKey("gasSensor"))  gasSensorOn  = doc["gasSensor"];
  if (doc.containsKey("tempSensor")) tempSensorOn = doc["tempSensor"];
  if (doc.containsKey("ledSensor"))  ledSensorOn  = doc["ledSensor"];
  if (doc.containsKey("pirSensor"))  pirSensorOn  = doc["pirSensor"];
  if (doc.containsKey("ldrSensor"))  ldrSensorOn  = doc["ldrSensor"];
  if (doc.containsKey("buzzer"))     buzzerOn     = doc["buzzer"];
  if (doc.containsKey("autoLight"))  autoLightOn  = doc["autoLight"];
  if (doc.containsKey("led2"))       led2On       = doc["led2"];

  // MOSFET Control
  if (doc.containsKey("mq2Pwr")) {
    mq2PwrOn = doc["mq2Pwr"];
    digitalWrite(MQ2_PWR, mq2PwrOn ? HIGH : LOW);
  }
  if (doc.containsKey("lcdPwr")) {
    lcdPwrOn = doc["lcdPwr"];
    digitalWrite(LCD_PWR, lcdPwrOn ? HIGH : LOW);
    if (lcdPwrOn) {
      delay(100);
      lcd.init();
      lcd.backlight();
      if (isLocked) showLockedScreen();
      else showHomeScreen();
    }
  }

  if (!systemOn) {
    gasSensorOn  = false;
    tempSensorOn = false;
    ledSensorOn  = false;
    pirSensorOn  = false;
    ldrSensorOn  = false;
    buzzerOn     = false;
    autoLightOn  = false;
    mq2PwrOn     = false;
    lcdPwrOn     = false;
    digitalWrite(LED1_PIN,   LOW);
    digitalWrite(LED2_PIN,   LOW);
    digitalWrite(BUZZER_PIN, LOW);
    digitalWrite(MQ2_PWR,    LOW);
    digitalWrite(LCD_PWR,    LOW);
  }
}

// ===== WIFI SERVER HANDLERS =====
void handleStatus() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", getStatusJson());
}

void handleControl() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  if (!server.hasArg("plain")) {
    server.send(400, "text/plain", "No body");
    return;
  }

  StaticJsonDocument<256> doc;
  deserializeJson(doc, server.arg("plain"));
  applyControlFromJson(doc);

  server.send(200, "application/json", getStatusJson());
  pushReportedToFirebase();
}

// ===== BLUETOOTH HANDLER =====
void handleBluetooth() {
  if (!SerialBT.available()) return;

  String cmd = SerialBT.readStringUntil('\n');
  cmd.trim();

  StaticJsonDocument<256> doc;
  deserializeJson(doc, cmd);
  applyControlFromJson(doc);

  SerialBT.println(getStatusJson());
  pushReportedToFirebase();
}

// ===== FIREBASE SYNC =====
// Mirrors the same status this device already serves over local HTTP
// (/status, /control) into Firebase Realtime Database, so the website and
// the phone app stay in sync with each other and with this device from
// anywhere with internet — not just this Wi-Fi network. See the website's
// README.md for the full /devices/{id}/state/reported|desired design.
void pushReportedToFirebase() {
  if (!firebaseReady || !Firebase.ready()) return;

  FirebaseJson json;
  json.set("system",      systemOn);
  json.set("gasSensor",   gasSensorOn);
  json.set("tempSensor",  tempSensorOn);
  json.set("ledSensor",   ledSensorOn);
  json.set("pirSensor",   pirSensorOn);
  json.set("ldrSensor",   ldrSensorOn);
  json.set("buzzer",      buzzerOn);
  json.set("autoLight",   autoLightOn);
  json.set("mq2Pwr",      mq2PwrOn);
  json.set("lcdPwr",      lcdPwrOn);
  json.set("temperature", temperature);
  json.set("humidity",    humidity);
  json.set("gasDetected", gasDetectedFlag);
  json.set("led2",        led2On);
  json.set("locked",      isLocked);
  json.set("gasPercent",  constrain(map(analogRead(MQ2_AO), GAS_BASELINE, 4095, 0, 100), 0, 100));
  json.set("online",      true);
  json.set("lastSeen",    (double)millis()); // device-local epoch stand-in; freshness is what matters, not wall-clock time

  String path = "/devices/" + FIREBASE_DEVICE_ID + "/state/reported";
  Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json);
  lastFirebasePush = millis();
}

// Applies a change written to /devices/{id}/state/desired by the app or the
// website. `desired` updates are partial (only the changed keys), so this
// reuses the same applyControlFromJson() the HTTP/Bluetooth paths use.
void firebaseStreamCallback(FirebaseStream data) {
  if (data.dataType() != "json") return;

  FirebaseJson *json = data.jsonObjectPtr();
  String jsonStr;
  json->toString(jsonStr);

  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, jsonStr) != DeserializationError::Ok) return;

  applyControlFromJson(doc);
  pushReportedToFirebase();
}

void firebaseStreamTimeoutCallback(bool timeout) {
  if (timeout) {
    Serial.println("Firebase stream timeout, resuming...");
  }
  if (!fbdoStream.httpConnected()) {
    Serial.printf(
      "Firebase stream error: %s\n",
      fbdoStream.errorReason().c_str()
    );
  }
}

void initFirebase() {
  fbConfig.api_key = FIREBASE_API_KEY;
  fbConfig.database_url = FIREBASE_DATABASE_URL;
  fbConfig.token_status_callback = tokenStatusCallback; // from addons/TokenHelper.h

  // Anonymous sign-in: empty email/password. Requires "Anonymous" enabled
  // under Firebase Console > Authentication > Sign-in method.
  if (Firebase.signUp(&fbConfig, &fbAuth, "", "")) {
    firebaseReady = true;
  } else {
    Serial.printf("Firebase anonymous sign-in failed: %s\n", fbConfig.signer.signupError.message.c_str());
    firebaseReady = false;
    return;
  }

  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);

  String desiredPath = "/devices/" + FIREBASE_DEVICE_ID + "/state/desired";
  if (!Firebase.RTDB.beginStream(&fbdoStream, desiredPath.c_str())) {
    Serial.printf("Firebase beginStream failed: %s\n", fbdoStream.errorReason().c_str());
  }
  Firebase.RTDB.setStreamCallback(&fbdoStream, firebaseStreamCallback, firebaseStreamTimeoutCallback);
}

// ===== BEEP =====
void beep() {
  if (!buzzerOn) return;
  tone(BUZZER_PIN, buzzerFrequency);
  delay(200);
  noTone(BUZZER_PIN);
  digitalWrite(BUZZER_PIN, LOW);
}

// ===== SET LED2 =====
void setLed2(bool state) {
  led2On = state;
  digitalWrite(LED2_PIN, led2On ? HIGH : LOW);
}

// ===== UPDATE DHT =====
void updateDhtState() {
  if (!tempSensorOn) return;
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!isnan(t) && !isnan(h)) {
    temperature  = t;
    humidity     = h;
    hasDhtReading= true;
  }
}

// ===== RFID =====
void checkRfid() {
  if (isLockedOut) {
    unsigned long elapsed = millis() - lockoutStartTime;
    if (elapsed >= LOCKOUT_DURATION) {
      isLockedOut   = false;
      wrongAttempts = 0;
      showLockedScreen();
    } else {
      int secondsLeft = (LOCKOUT_DURATION - elapsed) / 1000;
      showLockoutScreen(secondsLeft);
    }
    return;
  }

  if (!rfid.PICC_IsNewCardPresent()) return;
  if (!rfid.PICC_ReadCardSerial()) return;

  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();

  beep();

  if (uid == ALLOWED_UID && isLocked) {
    wrongAttempts = 0;
    isLocked      = false;
    digitalWrite(LED_RED,   LOW);
    digitalWrite(LED_GREEN, HIGH);
    doorServo.write(90);
    showUnlockedScreen();
    delay(2000);
    showHomeScreen();

  } else {
    wrongAttempts++;
    isLocked = true;
    digitalWrite(LED_GREEN, LOW);
    digitalWrite(LED_RED,   HIGH);
    doorServo.write(0);

    if (uid == ALLOWED_UID) {
      showLockedScreen();
    } else {
      showDeniedScreen();
      beep();
      delay(200);
      beep();
      delay(2000);
      if (wrongAttempts >= MAX_WRONG_ATTEMPTS) {
        isLockedOut      = true;
        lockoutStartTime = millis();
      } else {
        showLockedScreen();
      }
    }
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

// ===== GAS ALARM =====
void updateGasAlarm() {
  if (!gasSensorOn || !mq2PwrOn) {
    gasDetectedFlag = false;
    digitalWrite(LED1_PIN, LOW);
    noTone(BUZZER_PIN);
    return;
  }

  int gasValue   = analogRead(MQ2_AO);
  int doValue    = digitalRead(MQ2_DO);
  int gasPercent = map(gasValue, GAS_BASELINE, 4095, 0, 100);
  gasPercent     = constrain(gasPercent, 0, 100);

  bool sensorDisconnected = (doValue == LOW) && (gasValue < 200);
  bool gasHigh = (gasValue > GAS_BASELINE) && (gasPercent >= 20);

  gasDetectedFlag = gasHigh;

  if (sensorDisconnected) {
    gasAlarmActive = true;
    if (millis() - lastGasDisplayTime >= gasDisplayInterval) {
      lastGasDisplayTime = millis();
      if (lcdPwrOn) {
        lcd.setCursor(0, 0);
        lcd.print("ERROR!!!        ");
        lcd.setCursor(0, 1);
        lcd.print("MQ2 IS OFF      ");
      }
    }
    if (millis() - lastGasAlarmToggleTime >= gasAlarmBlinkInterval) {
      lastGasAlarmToggleTime = millis();
      gasAlarmOutputOn = !gasAlarmOutputOn;
      digitalWrite(LED1_PIN, gasAlarmOutputOn ? HIGH : LOW);
      if (gasAlarmOutputOn && buzzerOn) tone(BUZZER_PIN, buzzerFrequency);
      else { noTone(BUZZER_PIN); digitalWrite(BUZZER_PIN, LOW); }
    }
    return;
  }

  if (gasHigh) {
    gasAlarmActive = true;
    if (millis() - lastGasDisplayTime >= gasDisplayInterval) {
      lastGasDisplayTime = millis();
      if (lcdPwrOn) {
        lcdClearLine(1);
        lcd.print("GAS:");
        lcd.print(gasPercent);
        lcd.print("% DANGER!  ");
      }
    }
    if (millis() - lastGasAlarmToggleTime >= gasAlarmBlinkInterval) {
      lastGasAlarmToggleTime = millis();
      gasAlarmOutputOn = !gasAlarmOutputOn;
      digitalWrite(LED1_PIN, gasAlarmOutputOn ? HIGH : LOW);
      if (gasAlarmOutputOn && buzzerOn) tone(BUZZER_PIN, buzzerFrequency);
      else { noTone(BUZZER_PIN); digitalWrite(BUZZER_PIN, LOW); }
    }
    return;
  }

  if (gasAlarmActive) {
    gasAlarmActive = false;
    if (isLocked) showLockedScreen();
    else showHomeScreen();
  }

  gasAlarmOutputOn = false;
  digitalWrite(LED1_PIN, LOW);
  noTone(BUZZER_PIN);
  digitalWrite(BUZZER_PIN, LOW);
}

// ===== LDR =====
void updateNightLight() {
  if (!ldrSensorOn || !autoLightOn || gasAlarmActive) return;
  bool isNight = (digitalRead(LDR_DO) == HIGH);
  if (isNight != lastLdrState) {
    lastLdrState = isNight;
    setLed2(isNight);
    if (!isLocked && lcdPwrOn) {
      lcd.setCursor(0, 0);
      lcd.print("LED2: ");
      lcd.print(led2On ? "ON " : "OFF");
      lcd.print("         ");
    }
  }
}

// ===== SETUP =====
void setup() {
  Serial.begin(115200);

  pinMode(LDR_DO,     INPUT);
  pinMode(MQ2_DO,     INPUT);
  pinMode(BTN_PIN,    INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED1_PIN,   OUTPUT);
  pinMode(LED2_PIN,   OUTPUT);
  pinMode(LED_GREEN,  OUTPUT);
  pinMode(LED_RED,    OUTPUT);
  pinMode(MQ2_PWR,    OUTPUT);
  pinMode(LCD_PWR,    OUTPUT);

  digitalWrite(LED1_PIN,   LOW);
  digitalWrite(LED2_PIN,   LOW);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_GREEN,  LOW);
  digitalWrite(LED_RED,    HIGH);
  digitalWrite(MQ2_PWR,    HIGH);  // MQ2 شغال من الأول
  digitalWrite(LCD_PWR,    HIGH);  // LCD شغال من الأول

  dht.begin();
  SPI.begin();
  rfid.PCD_Init();

  doorServo.attach(SERVO_PIN);
  doorServo.write(0);

  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Hello Sir!      ");
  lcd.setCursor(0, 1);
  lcd.print("Welcome Home    ");
  delay(3000);
  lcd.clear();

  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi ");
  WiFi.begin(ssid, password);
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 20) {
    delay(500);
    tries++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    useWifi = true;
    lcd.setCursor(0, 0);
    lcd.print("WiFi Connected! ");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP().toString());
    Serial.println(WiFi.localIP());
    server.on("/status",  HTTP_GET,  handleStatus);
    server.on("/control", HTTP_POST, handleControl);
    server.begin();

    initFirebase();
  } else {
    useWifi = false;
    SerialBT.begin("SmartHome_ESP32");
    lcd.setCursor(0, 0);
    lcd.print("No WiFi!        ");
    lcd.setCursor(0, 1);
    lcd.print("BT Mode ON      ");
    Serial.println("Bluetooth Mode");
  }

  delay(2000);
  lcd.clear();
  showLockedScreen();

  lastDhtReadTime = millis();
  lastLdrState    = (digitalRead(LDR_DO) == HIGH);
}

// ===== LOOP =====
void loop() {
  if (!systemOn) {
    delay(100);
    if (useWifi) server.handleClient();
    else handleBluetooth();
    if (millis() - lastFirebasePush >= firebasePushInterval) pushReportedToFirebase();
    return;
  }

  bool buttonReading = digitalRead(BTN_PIN);

  if (useWifi) server.handleClient();
  else handleBluetooth();

  if (millis() - lastFirebasePush >= firebasePushInterval) pushReportedToFirebase();

  checkRfid();
  updateGasAlarm();
  updateNightLight();

  if (buttonReading != lastButtonReading) lastDebounceTime = millis();
  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (buttonReading != stableButtonState) {
      stableButtonState = buttonReading;
      if (stableButtonState == LOW) {
        setLed2(!led2On);
        if (!isLocked && !gasAlarmActive && lcdPwrOn) {
          lcd.setCursor(0, 0);
          lcd.print("LED2: ");
          lcd.print(led2On ? "ON " : "OFF");
          lcd.print("         ");
        }
      }
    }
  }
  lastButtonReading = buttonReading;

  if (millis() - lastDhtReadTime >= dhtReadInterval) {
    lastDhtReadTime = millis();
    updateDhtState();
    if (!isLocked && !gasAlarmActive && lcdPwrOn) showDhtState();
  }
}