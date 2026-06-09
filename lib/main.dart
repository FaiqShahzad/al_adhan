import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const defaultCalculationMethod = 1;
const defaultSchool = 0;
const calculationMethodPreferenceKey = 'calculation_method';
const schoolPreferenceKey = 'school';

class CalculationMethod {
  const CalculationMethod(this.id, this.name);

  final int id;
  final String name;
}

class PrayerSettings {
  const PrayerSettings({required this.method, required this.school});

  final int method;
  final int school;
}

const calculationMethods = [
  CalculationMethod(0, 'Jafari / Shia Ithna-Ashari'),
  CalculationMethod(1, 'University of Islamic Sciences, Karachi'),
  CalculationMethod(2, 'Islamic Society of North America'),
  CalculationMethod(3, 'Muslim World League'),
  CalculationMethod(4, 'Umm Al-Qura University, Makkah'),
  CalculationMethod(5, 'Egyptian General Authority of Survey'),
  CalculationMethod(7, 'Institute of Geophysics, University of Tehran'),
  CalculationMethod(8, 'Gulf Region'),
  CalculationMethod(9, 'Kuwait'),
  CalculationMethod(10, 'Qatar'),
  CalculationMethod(11, 'Majlis Ugama Islam Singapura, Singapore'),
  CalculationMethod(12, 'Union Organization islamic de France'),
  CalculationMethod(13, 'Diyanet Isleri Baskanligi, Turkey'),
  CalculationMethod(14, 'Spiritual Administration of Muslims of Russia'),
  CalculationMethod(15, 'Moonsighting Committee Worldwide'),
  CalculationMethod(16, 'Dubai'),
  CalculationMethod(17, 'Jabatan Kemajuan Islam Malaysia (JAKIM)'),
  CalculationMethod(18, 'Tunisia'),
  CalculationMethod(19, 'Algeria'),
  CalculationMethod(20, 'KEMENAG - Kementerian Agama Republik Indonesia'),
  CalculationMethod(21, 'Morocco'),
  CalculationMethod(22, 'Comunidade Islamica de Lisboa'),
  CalculationMethod(23, 'Ministry of Awqaf, Jordan'),
  CalculationMethod(99, 'Custom'),
];

Future<PrayerSettings> loadPrayerSettings(SharedPreferences prefs) async {
  return PrayerSettings(
    method:
        prefs.getInt(calculationMethodPreferenceKey) ??
        defaultCalculationMethod,
    school: prefs.getInt(schoolPreferenceKey) ?? defaultSchool,
  );
}

Future<void> savePrayerSettings(
  SharedPreferences prefs,
  PrayerSettings settings,
) async {
  await Future.wait([
    prefs.setInt(calculationMethodPreferenceKey, settings.method),
    prefs.setInt(schoolPreferenceKey, settings.school),
  ]);
}

String formatPrayerTime(String time24) {
  final parsedTime = DateFormat('HH:mm').parse(time24);
  return DateFormat('h:mm a').format(parsedTime);
}

String buildPrayerTimesCacheKey({
  required String date,
  required double latitude,
  required double longitude,
  required String method,
  required String school,
}) {
  final roundedLatitude = latitude.toStringAsFixed(3);
  final roundedLongitude = longitude.toStringAsFixed(3);

  return 'prayer_times_${date}_${roundedLatitude}_${roundedLongitude}_method_${method}_school_$school';
}

void main() {
  runApp(const PrayerTimesApp());
}

class PrayerTimesApp extends StatelessWidget {
  const PrayerTimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prayer Times',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const PrayerTimesScreen(),
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  bool isLoading = true;
  String? error;
  Map<String, dynamic>? timings;
  String? date;
  String? timezone;
  int selectedMethod = defaultCalculationMethod;
  int selectedSchool = defaultSchool;

  @override
  void initState() {
    super.initState();
    loadPrayerTimes();
  }

  Future<void> loadPrayerTimes() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final settings = await loadPrayerSettings(prefs);

      final position = await getCurrentLocation();

      final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final method = settings.method.toString();
      final school = settings.school.toString();

      final cacheKey = buildPrayerTimesCacheKey(
        date: today,
        latitude: position.latitude,
        longitude: position.longitude,
        method: method,
        school: school,
      );

      final cachedResponse = prefs.getString(cacheKey);

      if (cachedResponse != null) {
        final json = jsonDecode(cachedResponse) as Map<String, dynamic>;

        setState(() {
          selectedMethod = settings.method;
          selectedSchool = settings.school;
          timings = Map<String, dynamic>.from(json['data']['timings']);
          date = json['data']['date']['readable'];
          timezone = json['data']['meta']['timezone'];
          isLoading = false;
        });

        return;
      }

      final uri = Uri.https('api.aladhan.com', '/v1/timings/$today', {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'method': method,
        'school': school,
      });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch prayer times');
      }

      await prefs.setString(cacheKey, response.body);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      setState(() {
        selectedMethod = settings.method;
        selectedSchool = settings.school;
        timings = Map<String, dynamic>.from(json['data']['timings']);
        date = json['data']['date']['readable'];
        timezone = json['data']['meta']['timezone'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }

  Future<void> openOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final currentSettings = await loadPrayerSettings(prefs);

    if (!mounted) {
      return;
    }

    final settings = await Navigator.of(context).push<PrayerSettings>(
      MaterialPageRoute(
        builder: (context) => OptionsScreen(
          initialMethod: currentSettings.method,
          initialSchool: currentSettings.school,
        ),
      ),
    );

    if (!mounted || settings == null) {
      return;
    }

    final changed =
        settings.method != currentSettings.method ||
        settings.school != currentSettings.school;

    setState(() {
      selectedMethod = settings.method;
      selectedSchool = settings.school;
    });

    if (changed) {
      await loadPrayerTimes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: loadPrayerTimes,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(onPressed: openOptions, icon: const Icon(Icons.settings)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: loadPrayerTimes,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date ?? '',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timezone ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView.separated(
                        itemCount: prayers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final name = prayers[index];
                          final rawTime = timings?[name] ?? '-';
                          final time = rawTime == '-'
                              ? '-'
                              : formatPrayerTime(rawTime);

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(name),
                            trailing: Text(
                              time,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({
    super.key,
    required this.initialMethod,
    required this.initialSchool,
  });

  final int initialMethod;
  final int initialSchool;

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  late int method;
  late int school;

  @override
  void initState() {
    super.initState();
    method = widget.initialMethod;
    school = widget.initialSchool;
  }

  Future<void> saveOptions() async {
    final settings = PrayerSettings(method: method, school: school);
    final prefs = await SharedPreferences.getInstance();
    await savePrayerSettings(prefs, settings);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Options'),
        actions: [
          TextButton(onPressed: saveOptions, child: const Text('Save')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'School'),
              isExpanded: true,
              initialValue: school,
              onChanged: (value) => setState(() => school = value!),
              items: const [
                DropdownMenuItem(value: 0, child: Text('0 - Shafi')),
                DropdownMenuItem(value: 1, child: Text('1 - Hanafi')),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Method'),
              isExpanded: true,
              initialValue: method,
              onChanged: (value) => setState(() => method = value!),
              items: [
                for (final calculationMethod in calculationMethods)
                  DropdownMenuItem(
                    value: calculationMethod.id,
                    child: Text(
                      '${calculationMethod.id} - ${calculationMethod.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            if (method == 15) ...[
              const SizedBox(height: 12),
              Text(
                'Moonsighting Committee Worldwide may require a shafaq parameter.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (method == 99) ...[
              const SizedBox(height: 12),
              Text(
                'Custom calculation requires additional parameters.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
