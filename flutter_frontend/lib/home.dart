import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'controls.dart'; 
import 'notification.dart';
import 'settings.dart'; 
import 'edit_profile.dart';

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
                icon: Icon(Icons.notifications_outlined), label: "NOTIFICATIONS"),
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
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. USER DATA VARIABLES ---
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  String _deviceId = "N/A";
  String _memberSince = "Loading...";
  String? _userProfileUrl;
  bool _isLoadingUser = true;

  // --- 2. SENSOR & WEATHER VARIABLES ---
  String _currentCity = "Locating...";
  final String _sensorHumidity = "-- %";
  final String _sensorTemperature = "-- °C";
  final String _sensorRainStatus = "--";
  final String _sensorLight = "-- lux";
  final String _sensorWeight = "-- kg";
  final double _rainChance = 0;

  // History Lists
  final List<double> _humidityHistory = [];
  final List<double> _tempHistory = [];
  final List<double> _rainHistory = [];
  final List<double> _rainChanceHistory = [];
  final List<double> _lightHistory = [];
  final List<double> _weightHistory = [];
  final List<double> _weatherHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData(); 
    _fetchWeather();
    _fetchSensorData();
  }

  // --- NEW: Helper to extract initials from name ---
  String _getInitials(String name) {
    if (name.isEmpty || name == "Loading...") return "";
    List<String> nameParts = name.trim().split(RegExp(r'\s+')); // Split by whitespace
    if (nameParts.isEmpty) return "U";
    
    String first = nameParts[0].isNotEmpty ? nameParts[0][0] : "";
    String last = nameParts.length > 1 && nameParts[1].isNotEmpty ? nameParts[1][0] : "";
    
    String initials = (first + last).toUpperCase();
    return initials.isEmpty ? "U" : initials;
  }

  // --- 3. FETCH USER DATA FROM FIRESTORE ---
  Future<void> _fetchUserData() async {
    try {
      setState(() => _isLoadingUser = true);

      // Get current user from Firebase Auth
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

      // Fetch user document from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        // Extract data with fallbacks
        String? displayName = userData['displayName'];
        String? firstName = userData['firstName'];
        String? lastName = userData['lastName'];
        String email = userData['email'] ?? currentUser.email ?? 'No email';
        String? photoUrl = userData['photoUrl'];
        Timestamp? createdAt = userData['createdAt'];

        // Build display name: use displayName if available, otherwise firstName + lastName
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

        // Format member since date
        String memberSince = "N/A";
        if (createdAt != null) {
          DateTime date = createdAt.toDate();
          memberSince = "${_getMonthName(date.month)} ${date.year}";
        }

        // Device ID - you can customize this logic
        String deviceId = "LD-${currentUser.uid.substring(0, 8).toUpperCase()}";

        if (mounted) {
          setState(() {
            _userName = finalDisplayName;
            _userEmail = email;
            _deviceId = deviceId;
            _memberSince = memberSince;
            _userProfileUrl = photoUrl;
            _isLoadingUser = false;
          });
        }
      } else {
        // User document doesn't exist
        if (mounted) {
          setState(() {
            _userName = currentUser.displayName ?? 'User';
            _userEmail = currentUser.email ?? 'No email';
            _deviceId = "LD-${currentUser.uid.substring(0, 8).toUpperCase()}";
            _memberSince = "Recently";
            _userProfileUrl = currentUser.photoURL;
            _isLoadingUser = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          _userName = "Error";
          _userEmail = "Please try again";
          _isLoadingUser = false;
        });
      }
    }
  }

  // Helper to get month name
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Future<void> _fetchSensorData() async {
    debugPrint("Waiting for ESP32 connection...");
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

  // --- ACCOUNT MODAL ---
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
              // Header
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
                            // Profile Picture
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: const Color(0xFF2962FF), // Solid blue
                                  backgroundImage: _userProfileUrl != null 
                                      ? NetworkImage(_userProfileUrl!) 
                                      : null,
                                  // --- UPDATED: Show Initials if no photo ---
                                  child: _userProfileUrl == null 
                                      ? Text(
                                          _getInitials(_userName),
                                          style: const TextStyle(
                                            fontSize: 32, 
                                            fontWeight: FontWeight.bold, 
                                            color: Colors.white
                                          ),
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
                            
                            // Name & Email
                            Text(_userName, 
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                            const SizedBox(height: 4),
                            Text(_userEmail, 
                                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            
                            const SizedBox(height: 32),

                            // Account Info Section
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
                                  _buildInfoRow(Icons.phone_android, "DEVICE ID", _deviceId),
                                  const Divider(height: 30),
                                  _buildInfoRow(Icons.calendar_today_outlined, "MEMBER SINCE", _memberSince),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Edit Profile Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () { 
                                  Navigator.pop(context); 
                                  Navigator.push(
                                    context, 
                                    MaterialPageRoute(builder: (context) => const EditProfileScreen())
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2962FF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("EDIT PROFILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Sign Out Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  // Sign out from Firebase
                                  await _auth.signOut();
                                  if (mounted) {
                                    Navigator.pop(context); // Close modal
                                    // Navigate to login screen
                                    // Navigator.pushReplacementNamed(context, '/login');
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

  void _showDetailModal(String title, String value, List<double> historyData, String statusMsg) {
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
                            const Text("Recent History", style: TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 20),
                            historyData.isEmpty
                                ? SizedBox(height: 100, width: double.infinity, child: Center(child: Text("Waiting for sensor data...", style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic))))
                                : SizedBox(height: 150, width: double.infinity, child: CustomPaint(painter: LineChartPainter(data: historyData, color: const Color(0xFF2962FF)))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      const SizedBox(height: 8),
                      Text(
                          value == "--" || value == "-- %" || value == "-- °C" ? "Connect your Smart Rack sensors to see real-time status." : statusMsg,
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
                    Text("System Active • Auto Mode", style: TextStyle(fontSize: 14, color: Color(0xFF5A6175), fontWeight: FontWeight.w500)),
                  ],
                ),
                GestureDetector(
                  onTap: _showAccountModal, 
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF2962FF), // Darker Blue Background
                    backgroundImage: _userProfileUrl != null ? NetworkImage(_userProfileUrl!) : null,
                    // --- UPDATED: Show Initials here too ---
                    child: _userProfileUrl == null 
                      ? Text(
                          _getInitials(_userName), // Use the helper
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ) 
                      : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Weather & Sensor Cards
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchWeather(),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {"temp": "--", "condition": "Loading...", "description": "...", "icon": Icons.wb_sunny};
                return GestureDetector(
                  onTap: () => _showDetailModal("Weather", data['temp'], _weatherHistory, "Current weather is optimal."),
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

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                _buildSensorCard(title: "Humidity", value: _sensorHumidity, icon: Icons.water_drop_outlined, color: Colors.green, bgColor: const Color(0xFFE8F5E9), onTap: () => _showDetailModal("Humidity", _sensorHumidity, _humidityHistory, "Humidity is optimal.")),
                _buildSensorCard(title: "Temperature", value: _sensorTemperature, icon: Icons.thermostat, color: Colors.blue, bgColor: const Color(0xFFE3F2FD), onTap: () => _showDetailModal("Temperature", _sensorTemperature, _tempHistory, "Temperature is good.")),
                _buildSensorCard(title: "Rain Sensor", value: _sensorRainStatus, subtitle: _sensorRainStatus == "Dry" ? "Safe" : (_sensorRainStatus == "--" ? "" : "Alert"), icon: Icons.cloud_outlined, color: Colors.green, bgColor: const Color(0xFFE8F5E9), onTap: () => _showDetailModal("Rain Sensor", _sensorRainStatus, _rainHistory, "No rain.")),
                _buildCircleProgressCard(title: "Rain Chance", percentage: _rainChance.toInt(), icon: Icons.thunderstorm_outlined, onTap: () => _showDetailModal("Rain Chance", "${_rainChance.toInt()}%", _rainChanceHistory, "Low chance.")),
                _buildSensorCard(title: "Ambient Light", value: _sensorLight, icon: Icons.wb_sunny_outlined, color: Colors.orange, bgColor: const Color(0xFFFFF3E0), onTap: () => _showDetailModal("Ambient Light", _sensorLight, _lightHistory, "Good sunlight.")),
                _buildSensorCard(title: "Load Weight", value: _sensorWeight, subtitle: _sensorWeight == "-- kg" ? "" : "Drying...", icon: Icons.scale_outlined, color: Colors.indigo, bgColor: const Color(0xFFE8EAF6), showChip: _sensorWeight != "-- kg", onTap: () => _showDetailModal("Load Weight", _sensorWeight, _weightHistory, "Weight decreasing.")),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard({required String title, required String value, String? subtitle, required IconData icon, required Color color, required Color bgColor, bool showChip = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)), if (showChip) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Text("Drying...", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)))]),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
            if (subtitle != null && subtitle.isNotEmpty) ...[const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold))],
            const Spacer(),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleProgressCard({required String title, required int percentage, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            const Spacer(),
            Center(child: Stack(alignment: Alignment.center, children: [SizedBox(height: 70, width: 70, child: CircularProgressIndicator(value: percentage / 100, strokeWidth: 6, backgroundColor: Colors.grey[100], color: const Color(0xFF1E2339))), Text("$percentage%", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])),
            const Spacer(),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  LineChartPainter({required this.data, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..color = color..strokeWidth = 3..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    double minVal = data.reduce((a, b) => a < b ? a : b);
    if (maxVal == minVal) { maxVal += 1; minVal -= 1; }
    final double spacing = size.width / (data.length - 1);
    final double range = maxVal - minVal;
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final double x = i * spacing;
      final double y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}