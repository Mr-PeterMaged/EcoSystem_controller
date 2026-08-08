import 'package:flutter/material.dart';

const kGreen = Color(0xFF4CAF50);
const kGreenDark = Color(0xFF388E3C);
const kGreenLight = Color(0xFF56C85A);
const kCardLight = Color(0xFFF5F5F5);
const kCardDark = Color(0xFF2A2A2A);
const kTextPrimary = Color(0xFF212121);
const kBgDark = Color(0xFF121212);
const kBgDarkSurface = Color(0xFF1E1E1E);
const kAppBarDark = Color(0xFF1A1A1A);

// Must match VITE_FIREBASE_DEVICE_ID in the website and DEVICE_ID in the
// ESP32 firmware — all three read/write the same Firebase RTDB shadow path.
const kFirebaseDeviceId = 'esp32-01';

const Map<String, String> kDeviceLabels = {
  'system': 'System',
  'gasSensor': 'Gas Sensor',
  'tempSensor': 'Temperature',
  'ledSensor': 'LEDs',
  'pirSensor': 'PIR',
  'ldrSensor': 'LDR',
  'buzzer': 'Buzzer',
  'autoLight': 'Auto Light',
  'door': 'Door',
};

const List<String> kAllDeviceKeys = [
  'system',
  'gasSensor',
  'tempSensor',
  'ledSensor',
  'pirSensor',
  'ldrSensor',
  'buzzer',
  'autoLight',
  'door',
];

// Eco Mode: keeps safety sensors, turns off lights/motion/buzzer
const Map<String, bool> kPowerSaveEco = {
  'gasSensor': true,
  'tempSensor': true,
  'ledSensor': false,
  'pirSensor': false,
  'ldrSensor': false,
  'buzzer': false,
  'autoLight': false,
};

// Deep Save: only gas sensor stays active
const Map<String, bool> kPowerSaveDeep = {
  'gasSensor': true,
  'tempSensor': false,
  'ledSensor': false,
  'pirSensor': false,
  'ldrSensor': false,
  'buzzer': false,
  'autoLight': false,
};

const List<Color> kAccentColorOptions = [
  Color(0xFF4CAF50), // Green (default)
  Color(0xFF2196F3), // Blue
  Color(0xFF9C27B0), // Purple
  Color(0xFFFF5722), // Deep Orange
  Color(0xFF009688), // Teal
  Color(0xFFE91E63), // Pink
  Color(0xFFFF9800), // Amber
  Color(0xFF607D8B), // Blue Grey
];

bool isMotionDetected(Map<String, dynamic> data) =>
    data['motionDetected'] == true ||
    data['pirDetected'] == true ||
    data['motion'] == true;
