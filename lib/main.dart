import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

String formatPrayerTime(String time24) {
  final parsedTime = DateFormat('HH:mm').parse(time24);
  return DateFormat('h:mm a').format(parsedTime);
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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
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

      final position = await getCurrentLocation();

      final today = DateFormat('dd-MM-yyyy').format(DateTime.now());

      final uri = Uri.https('api.aladhan.com', '/v1/timings/$today', {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'method': '1',
      });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch prayer times');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      setState(() {
        timings = json['data']['timings'];
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
                        separatorBuilder: (_, __) => const Divider(height: 1),
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
