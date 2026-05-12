# دليل ربط التطبيق بالـ ESP32 / ESP32 Connection Guide

---

## العربية

---

### الخطوة 1 — تجهيز الـ ESP32

1. افتح ملف `sketch_may4a.ino` في **Arduino IDE**
2. عدّل بيانات الـ WiFi في أول الكود:

```cpp
const char* ssid     = "اسم شبكتك";
const char* password = "باسورد شبكتك";
```

3. ارفع الكود على الـ ESP32 بالضغط على زر **Upload**

---

### الخطوة 2 — اعرف الـ IP بتاع الـ ESP32

بعد الرفع، افتح **Serial Monitor** على سرعة **115200 baud** — هيظهرلك الـ IP على الشكل ده:

```
192.168.1.XX
```

> **أو:** شاشة الـ LCD هتعرض الـ IP مباشرة بعد الاتصال بالـ WiFi.

---

### الخطوة 3 — تأكد إن الاتصال شغال

افتح المتصفح على موبايلك أو اللاب، واكتب:

```
http://192.168.1.XX:8080/status
```

لو ظهرلك رد JSON زي ده — الـ ESP32 شغال تمام:

```json
{
  "system": true,
  "gasSensor": true,
  "temperature": 25,
  "humidity": 60,
  "gasDetected": false,
  "door": false,
  "pirDetected": false
}
```

---

### الخطوة 4 — ادخل الـ IP في التطبيق

1. افتح التطبيق على الموبايل
2. روح **Settings** ← **Connection**
3. اكتب الـ IP بتاع الـ ESP32
4. اضغط **Connect**

اللمبة الصغيرة في الشاشة الرئيسية هتبقى **خضرا** وهيكتب "Connected to ESP32"

---

### الخطوة 5 — تأكد إن كل حاجة شغالة

| تجربة | النتيجة المتوقعة |
|-------|----------------|
| اضغط **Door** → ON | السيرفو يتحرك لـ 90° واللمبة الخضرا تضيء |
| اضغط **Door** → OFF | السيرفو يرجع 0° واللمبة الحمرا تضيء |
| شاشة **Stats** | تعرض درجة الحرارة، الغاز، الحركة، حالة الباب |
| **Gas alarm** | لو MQ-2 اكتشف غاز، تيجي notification في التطبيق |
| **Motion alert** | لو PIR اكتشف حركة، تيجي notification في التطبيق |

---

### ملاحظات مهمة

- الموبايل والـ ESP32 لازم يكونوا على **نفس الـ WiFi**
- الـ IP بيتغير لو الراوتر أعاد توزيع العناوين — ثبّته من إعدادات الراوتر عن طريق **DHCP Reservation** أو **Static IP**
- لو الـ WiFi مش متاح، الـ ESP32 بيشتغل تلقائياً على **Bluetooth** باسم `SmartHome_ESP32` — في الحالة دي ربط الـ WiFi من التطبيق مش هيشتغل
- الـ ESP32 والتطبيق بيتواصلوا على **بورت 8080**

---
---

## English

---

### Step 1 — Prepare the ESP32

1. Open `sketch_may4a.ino` in **Arduino IDE**
2. Update the WiFi credentials at the top of the file:

```cpp
const char* ssid     = "YourNetworkName";
const char* password = "YourNetworkPassword";
```

3. Upload the code to the ESP32 by clicking the **Upload** button

---

### Step 2 — Find the ESP32 IP Address

After uploading, open the **Serial Monitor** at **115200 baud** — the IP address will be printed:

```
192.168.1.XX
```

> **Alternatively:** The LCD screen will display the IP address directly after connecting to WiFi.

---

### Step 3 — Verify the Connection

Open a browser on your phone or laptop and navigate to:

```
http://192.168.1.XX:8080/status
```

If you receive a JSON response like the one below, the ESP32 is running correctly:

```json
{
  "system": true,
  "gasSensor": true,
  "temperature": 25,
  "humidity": 60,
  "gasDetected": false,
  "door": false,
  "pirDetected": false
}
```

---

### Step 4 — Enter the IP Address in the App

1. Open the app on your phone
2. Go to **Settings** → **Connection**
3. Enter the ESP32 IP address
4. Tap **Connect**

The small dot on the home screen will turn **green** and display "Connected to ESP32"

---

### Step 5 — Test All Features

| Test | Expected Result |
|------|----------------|
| Tap **Door** → ON | Servo rotates to 90°, green LED turns on |
| Tap **Door** → OFF | Servo returns to 0°, red LED turns on |
| Open **Stats** screen | Displays temperature, gas level, motion, door state |
| **Gas alarm** | If MQ-2 detects gas, an in-app notification is triggered |
| **Motion alert** | If PIR detects motion, an in-app notification is triggered |

---

### Important Notes

- The phone and the ESP32 must be on the **same WiFi network**
- The IP address may change if the router reassigns addresses — fix it via **DHCP Reservation** or a **Static IP** in your router settings
- If WiFi is unavailable, the ESP32 automatically switches to **Bluetooth** mode under the name `SmartHome_ESP32` — WiFi connection from the app will not work in this mode
- The ESP32 and the app communicate over **port 8080**

---

## API Quick Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/status` | GET | Get current state of all devices and sensors |
| `/control` | POST | Send a JSON command to change device state |

**Example commands:**

```json
// Open the door
POST /control
{"door": true}

// Lock the door
POST /control
{"door": false}

// Turn off the entire system
POST /control
{"system": false}

// Turn on gas sensor only
POST /control
{"gasSensor": true}
```
