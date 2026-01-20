import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'controls.dart'; 
import 'notification.dart';
import 'settings.dart'; 
import 'edit_profile.dart';

// ============================================
// TOP LEVEL CONFIGURATION
// ============================================
const int SENSOR_UPDATE_INTERVAL_SECONDS = 10;
const int HISTORY_DURATION_MINUTES = 30;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardContent(),
    const ControlsScreen(),
    const NotificationsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF2962FF),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "HOME"),
            BottomNavigationBarItem(icon: Icon(Icons.tune), label: "CONTROLS"),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined), label: "ALERTS"),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined), label: "SETTINGS"),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// DASHBOARD CONTENT
// ==========================================================
class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User data
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  String _deviceId = "N/A";
  String _memberSince = "Loading...";
  String? _userProfileUrl;
  bool _isLoadingUser = true;
  String? _currentDeviceConnected;
  
  // Profile Completion Check
  bool _isProfileIncomplete = false;

  // Weather data
  String _currentCity = "Locating...";
  
  // Sensor data
  double _sensorHumidity = 0;
  double _sensorTemperature = 0;
  double _sensorLight = 0;
  double _sensorRainIntensity = 4095; // Default to max (Dry)
  
  // Calculated rainfall confidence
  double _rainConfidence = 0;

  // Time-series history (client-side, last 30 minutes)
  final List<SensorDataPoint> _humidityHistory = [];
  final List<SensorDataPoint> _tempHistory = [];
  final List<SensorDataPoint> _lightHistory = [];
  final List<SensorDataPoint> _rainHistory = [];
  final List<SensorDataPoint> _rainConfidenceHistory = [];
  final List<double> _weatherHistory = [];

  Timer? _sensorUpdateTimer;
  StreamSubscription<DocumentSnapshot>? _sensorSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchWeather();
    _startSensorUpdates();
  }

  @override
  void dispose() {
    _sensorUpdateTimer?.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  // --- Helper to Get Initials ---
  String _getInitials(String name) {
    if (name.isEmpty || name == "Loading...") return "";
    List<String> nameParts = name.trim().split(RegExp(r'\s+')); 
    if (nameParts.isEmpty) return "U";
    
    String first = nameParts[0].isNotEmpty ? nameParts[0][0] : "";
    String last = nameParts.length > 1 && nameParts[1].isNotEmpty ? nameParts[1][0] : "";
    
    String initials = (first + last).toUpperCase();
    return initials.isEmpty ? "U" : initials;
  }

  void _startSensorUpdates() {
    // Start periodic updates
    _sensorUpdateTimer = Timer.periodic(
      Duration(seconds: SENSOR_UPDATE_INTERVAL_SECONDS),
      (_) => _fetchSensorData(),
    );
    // Fetch immediately
    _fetchSensorData();
  }

  Future<void> _fetchUserData() async {
    try {
      setState(() => _isLoadingUser = true);

      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _userName = "Guest";
            _userEmail = "Not logged in";
            _deviceId = "N/A";
            _memberSince = "N/A";
            _isLoadingUser = false;
          });
        }
        return;
      }

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        _currentDeviceConnected = userData['currentDeviceConnected'] as String?;
        
        if (_currentDeviceConnected == null || _currentDeviceConnected!.isEmpty) {
          if (userData.containsKey('devices') && userData['devices'] is List) {
            List devices = userData['devices'] as List;
            if (devices.isNotEmpty) {
              _currentDeviceConnected = devices[0].toString();
            }
          }
        }

        String? displayName = userData['displayName'];
        String? firstName = userData['firstName'];
        String? lastName = userData['lastName'];
        String? contactNumber = userData['contactNumber'];
        String email = userData['email'] ?? currentUser.email ?? 'No email';
        String? photoUrl = userData['photoUrl'];
        Timestamp? createdAt = userData['createdAt'];

        bool isNameMissing = (firstName == null || firstName.isEmpty) && (lastName == null || lastName.isEmpty);
        bool isPhoneMissing = contactNumber == null || contactNumber.isEmpty;
        bool profileIncomplete = isNameMissing || isPhoneMissing;

        String finalDisplayName;
        if (displayName != null && displayName.isNotEmpty) {
          finalDisplayName = displayName;
        } else if (firstName != null && lastName != null) {
          finalDisplayName = '$firstName $lastName';
        } else if (firstName != null) {
          finalDisplayName = firstName;
        } else {
          finalDisplayName = 'User';
        }

        String memberSince = "N/A";
        if (createdAt != null) {
          DateTime date = createdAt.toDate();
          memberSince = "${_getMonthName(date.month)} ${date.year}";
        }

        String deviceId = "LD-${currentUser.uid.substring(0, 8).toUpperCase()}";

        if (mounted) {
          setState(() {
            _userName = finalDisplayName;
            _userEmail = email;
            _deviceId = deviceId;
            _memberSince = memberSince;
            _userProfileUrl = photoUrl;
            _isLoadingUser = false;
            _isProfileIncomplete = profileIncomplete; 
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userName = currentUser.displayName ?? 'User';
            _userEmail = currentUser.email ?? 'No email';
            _deviceId = "LD-${currentUser.uid.substring(0, 8).toUpperCase()}";
            _memberSince = "Recently";
            _userProfileUrl = currentUser.photoURL;
            _isLoadingUser = false;
            _isProfileIncomplete = true; 
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = "Error loading data";
          _userEmail = "Please try again";
          _deviceId = "N/A";
          _memberSince = "N/A";
          _isLoadingUser = false;
        });
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Future<void> _fetchSensorData() async {
    if (_currentDeviceConnected == null || _currentDeviceConnected!.isEmpty) {
      debugPrint("No device connected for current user");
      return;
    }

    try {
      DocumentSnapshot sensorDoc = await _firestore
          .collection('device_sensors')
          .doc(_currentDeviceConnected)
          .get();

      if (sensorDoc.exists) {
        Map<String, dynamic> sensorData = sensorDoc.data() as Map<String, dynamic>;
        
        double humidity = (sensorData['humidity'] ?? 0).toDouble();
        double temperature = (sensorData['temperature'] ?? 0).toDouble();
        double light = (sensorData['light'] ?? 0).toDouble();
        double rainIntensity = (sensorData['rainAO'] ?? 0).toDouble();

        double rainConfidence = _calculateRainfallConfidence(
          humidity: humidity,
          temperature: temperature,
          light: light,
          rainIntensity: rainIntensity,
        );

        DateTime now = DateTime.now();
        
        if (mounted) {
          setState(() {
            _sensorHumidity = humidity;
            _sensorTemperature = temperature;
            _sensorLight = light;
            _sensorRainIntensity = rainIntensity;
            _rainConfidence = rainConfidence;

            _addToHistory(_humidityHistory, humidity, now);
            _addToHistory(_tempHistory, temperature, now);
            _addToHistory(_lightHistory, light, now);
            _addToHistory(_rainHistory, rainIntensity, now);
            _addToHistory(_rainConfidenceHistory, rainConfidence, now);
            
            _cleanupOldHistory();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching sensor data: $e');
    }
  }

  double _calculateRainfallConfidence({
    required double humidity,
    required double temperature,
    required double light,
    required double rainIntensity,
  }) {
    const double humidityWeight = 0.35;      
    const double temperatureWeight = 0.35;   
    const double lightWeight = 0.20;         
    const double rainIntensityWeight = 0.10; 

    double humidityScore = ((humidity - 60) / 40).clamp(0, 1) * 100;
    double tempScore = (1 - ((temperature - 15) / 10).clamp(0, 1)) * 100;
    double lightScore = (1 - (light / 4000).clamp(0, 1)) * 100;
    double rainScore = ((4095 - rainIntensity) / 4095) * 100;

    double confidence = (
      (humidityScore * humidityWeight) +
      (tempScore * temperatureWeight) +
      (lightScore * lightWeight) +
      (rainScore * rainIntensityWeight)
    );

    return confidence.clamp(0, 100);
  }

  void _addToHistory(List<SensorDataPoint> history, double value, DateTime timestamp) {
    history.add(SensorDataPoint(value: value, timestamp: timestamp));
  }

  void _cleanupOldHistory() {
    DateTime cutoff = DateTime.now().subtract(Duration(minutes: HISTORY_DURATION_MINUTES));
    
    _humidityHistory.removeWhere((point) => point.timestamp.isBefore(cutoff));
    _tempHistory.removeWhere((point) => point.timestamp.isBefore(cutoff));
    _lightHistory.removeWhere((point) => point.timestamp.isBefore(cutoff));
    _rainHistory.removeWhere((point) => point.timestamp.isBefore(cutoff));
    _rainConfidenceHistory.removeWhere((point) => point.timestamp.isBefore(cutoff));
  }

  Future<Map<String, dynamic>> _fetchWeather() async {
    try {
      final locationResponse = await http.get(Uri.parse('http://ip-api.com/json'));
      double lat = 14.65;
      double long = 120.98;

      if (locationResponse.statusCode == 200) {
        final locData = json.decode(locationResponse.body);
        lat = locData['lat'];
        long = locData['lon'];
        if (mounted) setState(() => _currentCity = locData['city'] ?? "Unknown City");
      }

      final String url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$long&current_weather=true';
      final weatherResponse = await http.get(Uri.parse(url));

      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);
        final currentWeather = data['current_weather'];
        final int code = currentWeather['weathercode'];
        final weatherInfo = _getWeatherInfoFromCode(code);

        if (mounted) {
          setState(() {
            _weatherHistory.add(currentWeather['temperature']);
            if (_weatherHistory.length > 6) _weatherHistory.removeAt(0);
          });
        }

        return {
          "temp": "${currentWeather['temperature'].round()}°",
          "condition": weatherInfo['condition'],
          "description": weatherInfo['description'],
          "icon": weatherInfo['icon'],
        };
      } else {
        throw Exception('Failed');
      }
    } catch (e) {
      return {"temp": "--", "condition": "Offline", "description": "Check internet", "icon": Icons.wifi_off};
    }
  }

  Map<String, dynamic> _getWeatherInfoFromCode(int code) {
    if (code == 0) return {"condition": "Clear", "description": "Sunny skies", "icon": Icons.wb_sunny};
    if (code >= 1 && code <= 3) return {"condition": "Cloudy", "description": "Partly cloudy", "icon": Icons.cloud};
    if (code >= 51 && code <= 67) return {"condition": "Rainy", "description": "Rain detected", "icon": Icons.water_drop};
    if (code >= 95) return {"condition": "Storm", "description": "Thunderstorms", "icon": Icons.thunderstorm};
    return {"condition": "Rainy", "description": "Showers", "icon": Icons.grain};
  }

  void _showAccountModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Account",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _isLoadingUser
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Color(0xFF2962FF),
                                  backgroundImage: _userProfileUrl != null 
                                      ? NetworkImage(_userProfileUrl!) 
                                      : null,
                                  child: _userProfileUrl == null 
                                      ? Text(
                                          _getInitials(_userName),
                                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 255, 255)),
                                        )
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                  ),
                                  child: const Icon(Icons.edit, size: 16, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Text(_userName, 
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                            const SizedBox(height: 4),
                            Text(_userEmail, 
                                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            
                            const SizedBox(height: 32),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text("Account Information", 
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                            ),
                            const SizedBox(height: 12),
                            
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FB),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  _buildInfoRow(Icons.email_outlined, "EMAIL", _userEmail),
                                  const Divider(height: 30),
                                  _buildInfoRow(Icons.phone_android, "USER ID", _deviceId),
                                  const Divider(height: 30),
                                  _buildInfoRow(Icons.calendar_today_outlined, "MEMBER SINCE", _memberSince),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () { 
                                  Navigator.pop(context); 
                                  Navigator.push(
                                    context, 
                                    MaterialPageRoute(builder: (context) => const EditProfileScreen())
                                  ).then((_) => _fetchUserData()); 
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2962FF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("EDIT PROFILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await _auth.signOut();
                                  if (mounted) {
                                    Navigator.pop(context);
                                  }
                                }, 
                                icon: const Icon(Icons.logout, size: 20, color: Colors.black87),
                                label: const Text("SIGN OUT", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: const Color(0xFFF5F6FA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.grey[700], size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                value, 
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E2339)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )
      ],
    );
  }

  void _showDetailModal(String title, String value, List<SensorDataPoint> historyData, String statusMsg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Recent History (Last 30 min)", style: TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 20),
                            historyData.isEmpty
                                ? SizedBox(height: 100, width: double.infinity, child: Center(child: Text("Waiting for sensor data...", style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic))))
                                : SizedBox(height: 150, width: double.infinity, child: CustomPaint(painter: TimeSeriesChartPainter(data: historyData, color: const Color(0xFF2962FF)))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      const SizedBox(height: 8),
                      Text(
                          value == "0.0" || value == "0" || _currentDeviceConnected == null ? "Connect your Smart Rack sensors to see real-time status." : statusMsg,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF5A6175), height: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double padding = size.width * 0.05;

    // --- Updated Logic: Dry = "No Rain", Wet = Status ---
    String getRainStatus() {
      if (_sensorRainIntensity > 3500) return "No Rain";
      if (_sensorRainIntensity > 2000) return "Drizzle";
      if (_sensorRainIntensity > 1000) return "Rain";
      return "Heavy Rain";
    }

    // --- Updated Logic: Is it raining? ---
    bool isRaining = _sensorRainIntensity <= 3500;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("My Laundry", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                    SizedBox(height: 4),
                    Text("System Dashboard", style: TextStyle(fontSize: 14, color: Color(0xFF5A6175), fontWeight: FontWeight.w500)),
                  ],
                ),
                GestureDetector(
                  onTap: _showAccountModal, 
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFF2962FF),
                    backgroundImage: _userProfileUrl != null ? NetworkImage(_userProfileUrl!) : null,
                    // Top Right Corner Initials Logic
                    child: _userProfileUrl == null 
                        ? Text(_getInitials(_userName), style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 255, 255))) 
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Incomplete Profile Notice ---
            if (_isProfileIncomplete && !_isLoadingUser)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  ).then((_) => _fetchUserData());
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Complete your profile",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            Text(
                              "Add your name and contact info.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange.shade800),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 24),

            // Weather Card
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchWeather(),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {"temp": "--", "condition": "Loading...", "description": "...", "icon": Icons.wb_sunny};
                return GestureDetector(
                  onTap: () => _showDetailModal("Weather", data['temp'], [], "Current weather is optimal."),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF448AFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on, color: Colors.white, size: 12), const SizedBox(width: 4), Text(_currentCity, style: const TextStyle(color: Colors.white, fontSize: 12))]),
                              ),
                              const SizedBox(height: 12),
                              Text(data['condition'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(data['description'], style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4)),
                              const SizedBox(height: 10),
                              Text(data['temp'], style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Icon(data['icon'], size: 60, color: Colors.yellowAccent),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Sensor Cards Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                _buildSensorCard(
                  title: "Humidity", 
                  value: "${_sensorHumidity.toStringAsFixed(1)}%", 
                  icon: Icons.water_drop_outlined, 
                  color: Colors.green, 
                  bgColor: const Color(0xFFE8F5E9), 
                  onTap: () => _showDetailModal("Humidity", "${_sensorHumidity.toStringAsFixed(1)}%", _humidityHistory, "Humidity is optimal for drying.")
                ),
                _buildSensorCard(
                  title: "Temperature", 
                  value: "${_sensorTemperature.toStringAsFixed(1)}°C", 
                  icon: Icons.thermostat, 
                  color: Colors.blue, 
                  bgColor: const Color(0xFFE3F2FD), 
                  onTap: () => _showDetailModal("Temperature", "${_sensorTemperature.toStringAsFixed(1)}°C", _tempHistory, "Temperature is good for drying.")
                ),
                // --- UPDATED RAIN SENSOR CARD ---
                _buildSensorCard(
                  title: "Rain Sensor", 
                  value: getRainStatus(), 
                  subtitle: isRaining ? "Alert" : null, // Show Alert only if raining
                  icon: Icons.cloud_outlined, 
                  color: isRaining ? Colors.orange : Colors.green, 
                  bgColor: const Color(0xFFE8F5E9), 
                  onTap: () => _showDetailModal("Rain Sensor", getRainStatus(), _rainHistory, "Current rain intensity: ${_sensorRainIntensity.toStringAsFixed(0)}")
                ),
                _buildCircleProgressCard(
                  title: "Rain Chance", 
                  percentage: _rainConfidence.toInt(), 
                  icon: Icons.thunderstorm_outlined, 
                  onTap: () => _showDetailModal("Rain Chance", "${_rainConfidence.toInt()}%", _rainConfidenceHistory, "Calculated based on humidity, temperature, light, and rain sensor.")
                ),
                _buildSensorCard(
                  title: "Ambient Light", 
                  value: "${_sensorLight.toStringAsFixed(0)} lux", 
                  icon: Icons.wb_sunny_outlined, 
                  color: Colors.orange, 
                  bgColor: const Color(0xFFFFF3E0), 
                  onTap: () => _showDetailModal("Ambient Light", "${_sensorLight.toStringAsFixed(0)} lux", _lightHistory, "Good sunlight for drying.")
                ),
                // --- LOAD WEIGHT REMOVED FROM HERE ---
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required String title, 
    required String value, 
    String? subtitle, 
    required IconData icon, 
    required Color color, 
    required Color bgColor, 
    bool showChip = false, 
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Container(
                  padding: const EdgeInsets.all(8), 
                  decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), 
                  child: Icon(icon, color: color, size: 20)
                ), 
                if (showChip) 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(10)
                    ), 
                    child: const Text("Drying...", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold))
                  )
              ]
            ),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 4), 
              Text(subtitle, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold))
            ],
            const Spacer(),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleProgressCard({
    required String title, 
    required int percentage, 
    required IconData icon, 
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            const Spacer(),
            Center(
              child: Stack(
                alignment: Alignment.center, 
                children: [
                  SizedBox(
                    height: 70, 
                    width: 70, 
                    child: CircularProgressIndicator(
                      value: percentage / 100, 
                      strokeWidth: 6, 
                      backgroundColor: Colors.grey[100], 
                      color: const Color(0xFF1E2339)
                    )
                  ), 
                  Text("$percentage%", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                ]
              )
            ),
            const Spacer(),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// SENSOR DATA POINT CLASS
// ==========================================================
class SensorDataPoint {
  final double value;
  final DateTime timestamp;

  SensorDataPoint({required this.value, required this.timestamp});
}

// ==========================================================
// TIME SERIES CHART PAINTER
// ==========================================================
class TimeSeriesChartPainter extends CustomPainter {
  final List<SensorDataPoint> data;
  final Color color;
  
  TimeSeriesChartPainter({required this.data, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Find min and max values
    double maxVal = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    double minVal = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    
    if (maxVal == minVal) { 
      maxVal += 1; 
      minVal -= 1; 
    }
    
    final double spacing = size.width / (data.length - 1);
    final double range = maxVal - minVal;
    final path = Path();
    
    for (int i = 0; i < data.length; i++) {
      final double x = i * spacing;
      final double y = size.height - ((data[i].value - minVal) / range) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
    
    canvas.drawPath(path, paint);
    
    // Draw gradient fill under the line
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, gradientPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}