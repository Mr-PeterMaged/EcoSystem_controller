import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/weather_models.dart';
import '../services/weather_api_service.dart';
import '../services/weather_notification_service.dart';
import '../services/weather_voice_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  // ── Weather data ────────────────────────────────────────────────────────────
  WCurrentWeatherData _current = WCurrentWeatherData.sample('Cairo', 30, 25, 35);

  List<WFiveDayData> _forecast = [
    WFiveDayData(dateTime: '13-09', temp: 28),
    WFiveDayData(dateTime: '13-12', temp: 31),
    WFiveDayData(dateTime: '13-15', temp: 33),
    WFiveDayData(dateTime: '14-09', temp: 27),
    WFiveDayData(dateTime: '14-12', temp: 30),
    WFiveDayData(dateTime: '15-09', temp: 29),
    WFiveDayData(dateTime: '16-09', temp: 26),
    WFiveDayData(dateTime: '17-09', temp: 28),
  ];

  List<WCurrentWeatherData> _cities = [
    WCurrentWeatherData.sample('Zagazig', 28, 24, 31),
    WCurrentWeatherData.sample('Cairo', 30, 25, 34),
    WCurrentWeatherData.sample('Alexandria', 25, 22, 28),
    WCurrentWeatherData.sample('Ismailia', 29, 24, 33),
    WCurrentWeatherData.sample('Fayoum', 31, 24, 35),
  ];

  // ── Search & location ───────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _city = 'Cairo';
  bool _isDetecting = false;
  String? _locationError;

  // ── Weather settings ────────────────────────────────────────────────────────
  bool _voiceEnabled = true;
  bool _notificationsEnabled = true;
  String _homeCity = '';

  @override
  void initState() {
    super.initState();
    WeatherNotificationService.init();
    _loadSettings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    WeatherVoiceService.stop();
    super.dispose();
  }

  // ── Settings persistence ────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final homeCity = prefs.getString('weather_home_city') ?? '';
    if (!mounted) return;
    setState(() {
      _voiceEnabled = prefs.getBool('weather_voice_enabled') ?? true;
      _notificationsEnabled =
          prefs.getBool('weather_notifications_enabled') ?? true;
      _homeCity = homeCity;
      if (homeCity.isNotEmpty) _city = homeCity;
      _searchCtrl.text = _city;
    });
    _refresh();
    _loadTopCities();
  }

  Future<void> _saveVoice(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('weather_voice_enabled', val);
  }

  Future<void> _saveNotifications(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('weather_notifications_enabled', val);
  }

  Future<void> _saveHomeCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_home_city', city.trim());
  }

  // ── Data fetching ───────────────────────────────────────────────────────────

  void _refresh() {
    _fetchCurrent();
    _fetchForecast();
  }

  Future<void> _fetchCurrent() async {
    final data = await WeatherApiService.getCurrentWeather(_city);
    if (data != null && mounted) {
      setState(() => _current = data);
      await _onWeatherReady(data);
    }
  }

  Future<void> _fetchForecast() async {
    final data = await WeatherApiService.getForecast(_city);
    if (data.isNotEmpty && mounted) {
      setState(() => _forecast = data);
    }
  }

  void _loadTopCities() {
    const cities = ['Zagazig', 'Cairo', 'Alexandria', 'Ismailia', 'Fayoum'];
    var fresh = false;
    for (final c in cities) {
      WeatherApiService.getCurrentWeather(c).then((data) {
        if (data != null && mounted) {
          setState(() {
            if (!fresh) {
              _cities = [];
              fresh = true;
            }
            _cities = [..._cities, data];
          });
        }
      });
    }
  }

  // ── Voice + notifications on weather load ───────────────────────────────────

  Future<void> _onWeatherReady(WCurrentWeatherData data) async {
    final cityName = data.name ?? _city;
    final condition = data.weather?.isNotEmpty == true
        ? (data.weather!.first.description ?? 'clear')
        : 'clear';
    final tempK = data.main?.temp;
    final tempC = tempK != null ? tempK - 273.15 : null;

    if (_voiceEnabled) {
      final greet = WeatherVoiceService.greeting();
      final tempStr = tempC != null ? '${tempC.round()} degrees Celsius' : '';
      await WeatherVoiceService.speak(
          '$greet! The weather in $cityName is $condition. $tempStr.');
    }

    if (_notificationsEnabled && tempC != null) {
      await WeatherNotificationService.scheduleDailyMorning(
        city: cityName,
        condition: condition,
        tempC: tempC,
      );
    }
  }

  // ── GPS location detection ──────────────────────────────────────────────────

  Future<void> _detectLocation() async {
    setState(() {
      _isDetecting = true;
      _locationError = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationError = 'Location permission denied.';
              _isDetecting = false;
            });
          }
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationError =
                'Location permanently denied — enable in device settings.';
            _isDetecting = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      _city = '${pos.latitude},${pos.longitude}';
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _locationError = 'Location error: $e');
    }
    if (mounted) setState(() => _isDetecting = false);
  }

  // ── Settings bottom sheet ───────────────────────────────────────────────────

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WeatherSettingsSheet(
        voiceEnabled: _voiceEnabled,
        notificationsEnabled: _notificationsEnabled,
        homeCity: _homeCity,
        onVoiceToggle: (val) {
          setState(() => _voiceEnabled = val);
          _saveVoice(val);
        },
        onNotificationsToggle: (val) async {
          if (val) {
            await WeatherNotificationService.requestPermission();
          } else {
            await WeatherNotificationService.cancelAll();
          }
          setState(() => _notificationsEnabled = val);
          _saveNotifications(val);
        },
        onHomeCitySet: (city) {
          setState(() {
            _homeCity = city.trim();
          });
          _saveHomeCity(city);
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _kelvinToC(double? k) {
    if (k == null) return '--°C';
    return '${(k - 273.15).round()}°C';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final description = _current.weather?.isNotEmpty == true
        ? (_current.weather!.first.description ?? 'scattered clouds')
        : 'scattered clouds';

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WeatherHeader(
              city: (_current.name ?? _city).toUpperCase(),
              description: description,
              date: DateFormat().add_MMMMEEEEd().format(DateTime.now()),
              temp: _kelvinToC(_current.main?.temp),
              minTemp: _kelvinToC(_current.main?.tempMin),
              maxTemp: _kelvinToC(_current.main?.tempMax),
              windSpeed: _current.wind?.speed?.toStringAsFixed(1) ?? '--',
              humidity: _current.main?.humidity?.toString() ?? '--',
              pressure: _current.main?.pressure?.toString() ?? '--',
              isDetecting: _isDetecting,
              searchCtrl: _searchCtrl,
              onCityChanged: (v) => _city = v,
              onSearch: (_) => _refresh(),
              onDetectLocation: _detectLocation,
              onOpenSettings: _openSettings,
              onBack: () => Navigator.pop(context),
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _locationError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 22, 15, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OTHER CITIES',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _CityList(cities: _cities),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FORECAST — NEXT 5 DAYS',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const Icon(Icons.next_plan_outlined),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ForecastChart(data: _forecast),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _WeatherHeader extends StatelessWidget {
  final String city;
  final String description;
  final String date;
  final String temp;
  final String minTemp;
  final String maxTemp;
  final String windSpeed;
  final String humidity;
  final String pressure;
  final bool isDetecting;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onSearch;
  final VoidCallback onDetectLocation;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  const _WeatherHeader({
    required this.city,
    required this.description,
    required this.date,
    required this.temp,
    required this.minTemp,
    required this.maxTemp,
    required this.windSpeed,
    required this.humidity,
    required this.pressure,
    required this.isDetecting,
    required this.searchCtrl,
    required this.onCityChanged,
    required this.onSearch,
    required this.onDetectLocation,
    required this.onOpenSettings,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 480,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: 'Weather Settings',
                  onPressed: onOpenSettings,
                ),
                const Text(
                  'WEATHER',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  tooltip: 'Back to Home',
                  onPressed: onBack,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Search bar + GPS button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: onCityChanged,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSearch,
                    decoration: InputDecoration(
                      hintText: 'SEARCH CITY',
                      hintStyle: const TextStyle(color: Colors.white60),
                      suffixIcon:
                          const Icon(Icons.search, color: Colors.white),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.white38),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDetectLocation,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: isDetecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.my_location,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Current weather card
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      city,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                description,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                temp,
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium,
                              ),
                              Text(
                                'min: $minTemp / max: $maxTemp',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          children: [
                            SizedBox(
                              width: 86,
                              height: 86,
                              child:
                                  Lottie.asset('lib/assets/cloudy.json'),
                            ),
                            _chip(Icons.air, '$windSpeed m/s', context),
                            const SizedBox(height: 3),
                            _chip(Icons.water_drop_outlined,
                                '$humidity%', context),
                            const SizedBox(height: 3),
                            _chip(Icons.compress,
                                '${pressure}hPa', context),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _chip(
      IconData icon, String label, BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

// ── Horizontal city list ──────────────────────────────────────────────────────

class _CityList extends StatelessWidget {
  final List<WCurrentWeatherData> cities;
  const _CityList({required this.cities});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) => const SizedBox(width: 5),
        itemCount: cities.length,
        itemBuilder: (context, index) {
          final data = cities[index];
          final tempC = data.main?.temp != null
              ? '${(data.main!.temp! - 273.15).round()}°C'
              : '--';
          final desc = data.weather?.isNotEmpty == true
              ? (data.weather!.first.description ?? '')
              : '';
          final labelColor =
              Theme.of(context).colorScheme.onSurfaceVariant;
          return SizedBox(
            width: 140,
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(data.name ?? '',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: labelColor)),
                  Text(tempC,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: labelColor)),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: Lottie.asset('lib/assets/cloudy.json'),
                  ),
                  Text(desc,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: labelColor)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 5-day forecast chart ──────────────────────────────────────────────────────

class _ForecastChart extends StatelessWidget {
  final List<WFiveDayData> data;
  const _ForecastChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 240,
      child: Card(
        elevation: 5,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: SfCartesianChart(
          primaryXAxis: const CategoryAxis(),
          series: <CartesianSeries<WFiveDayData, String>>[
            SplineSeries<WFiveDayData, String>(
              dataSource: data,
              xValueMapper: (WFiveDayData f, _) => f.dateTime ?? '',
              yValueMapper: (WFiveDayData f, _) => f.temp ?? 0,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings bottom sheet ─────────────────────────────────────────────────────

class _WeatherSettingsSheet extends StatefulWidget {
  final bool voiceEnabled;
  final bool notificationsEnabled;
  final String homeCity;
  final ValueChanged<bool> onVoiceToggle;
  final ValueChanged<bool> onNotificationsToggle;
  final ValueChanged<String> onHomeCitySet;

  const _WeatherSettingsSheet({
    required this.voiceEnabled,
    required this.notificationsEnabled,
    required this.homeCity,
    required this.onVoiceToggle,
    required this.onNotificationsToggle,
    required this.onHomeCitySet,
  });

  @override
  State<_WeatherSettingsSheet> createState() =>
      _WeatherSettingsSheetState();
}

class _WeatherSettingsSheetState extends State<_WeatherSettingsSheet> {
  late bool _voice;
  late bool _notifications;
  late String _homeCity;

  @override
  void initState() {
    super.initState();
    _voice = widget.voiceEnabled;
    _notifications = widget.notificationsEnabled;
    _homeCity = widget.homeCity;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Weather Settings',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure voice, notifications, and home city',
              style: TextStyle(
                  fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // ── Appearance ──────────────────────────────────────────
            _sectionHeader('VOICE & SOUND', context),
            _settingsTile(
              context,
              icon: _voice
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              iconColor: _voice ? colors.primary : colors.onSurfaceVariant,
              title: 'Voice Announcements',
              subtitle: _voice
                  ? 'Speaks weather when it loads'
                  : 'Voice is off',
              trailing: Switch(
                value: _voice,
                activeThumbColor: colors.primary,
                onChanged: (val) {
                  setState(() => _voice = val);
                  widget.onVoiceToggle(val);
                },
              ),
            ),
            const SizedBox(height: 8),
            _actionTile(
              context,
              icon: Icons.record_voice_over_outlined,
              iconColor: const Color(0xFF10B981),
              title: 'Test Voice',
              subtitle: 'Tap to hear the voice assistant speak',
              buttonLabel: 'TEST',
              buttonColor: const Color(0xFF10B981),
              onTap: () async {
                final greet = WeatherVoiceService.greeting();
                await WeatherVoiceService.speak(
                    '$greet! Voice is working perfectly!');
              },
            ),
            const SizedBox(height: 20),

            // ── Notifications ───────────────────────────────────────
            _sectionHeader('NOTIFICATIONS', context),
            _settingsTile(
              context,
              icon: _notifications
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              iconColor: _notifications
                  ? const Color(0xFFF59E0B)
                  : colors.onSurfaceVariant,
              title: 'Daily Weather Notifications',
              subtitle: _notifications
                  ? 'Weather update every morning at 8:00 AM'
                  : 'Notifications are off',
              trailing: Switch(
                value: _notifications,
                activeThumbColor: const Color(0xFFF59E0B),
                onChanged: (val) async {
                  setState(() => _notifications = val);
                  widget.onNotificationsToggle(val);
                },
              ),
            ),
            const SizedBox(height: 8),
            _actionTile(
              context,
              icon: Icons.send_outlined,
              iconColor: const Color(0xFFF59E0B),
              title: 'Test Notification',
              subtitle: 'Sends a sample weather notification now',
              buttonLabel: 'SEND',
              buttonColor: const Color(0xFFF59E0B),
              onTap: () async {
                final granted =
                    await WeatherNotificationService.requestPermission();
                if (!granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please allow notifications in device settings.')),
                  );
                  return;
                }
                await WeatherNotificationService.showNow(
                  city: 'Cairo',
                  condition: 'Clear skies',
                  tempC: 28,
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Location ────────────────────────────────────────────
            _sectionHeader('LOCATION', context),
            _settingsTile(
              context,
              icon: Icons.home_outlined,
              iconColor: colors.primary,
              title: 'Home City',
              subtitle: _homeCity.isEmpty
                  ? 'Not set — tap to configure'
                  : _homeCity,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCityDialog(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCityDialog(BuildContext context) {
    final ctrl = TextEditingController(text: _homeCity);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Home City'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'e.g. Cairo',
            prefixIcon: Icon(Icons.location_city),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              widget.onHomeCitySet(ctrl.text);
              setState(() => _homeCity = ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static Widget _sectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  static Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13)),
        trailing: trailing,
      ),
    );
  }

  static Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13)),
        trailing: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: buttonColor,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
          ),
          child: Text(buttonLabel),
        ),
      ),
    );
  }
}
