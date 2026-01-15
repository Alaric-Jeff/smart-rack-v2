import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'controls.dart'; 
import 'notification.dart';
import 'settings.dart'; 
import 'edit_profile.dart';

// ============================================
// TOP LEVEL CONFIGURATION
// ============================================
const int SENSOR_UPDATE_INTERVAL_SECONDS = 10; // Updates every 10 seconds
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
          type: BottomNavigationBarType.fixed, // Ensures 4 items fit evenly
          selectedItemColor: const Color(0xFF2962FF),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          
          selectedFontSize: 11,
          unselectedFontSize: 11,
          
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled), 
              label: "HOME"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune), 
              label: "CONTROLS"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined), 
              label: "ALERTS" 
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), 
              label: "SETTINGS"
            ),
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
  // Firebase Instances for REAL User Data
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- REAL USER DATA VARIABLES ---
  String _userName = "Loading..."; 
  String _userEmail = "...";
  final String _deviceId = "LD-8D390DC"; // Static Device ID
  String _memberSince = "...";
  String? _userProfileUrl; 

  // --- SIMULATION VARIABLES (FAKE SENSORS) ---
  // Weather State
  String _weatherCondition = "Sunny";
  String _weatherDescription = "Clear skies";
  IconData _weatherIcon = Icons.wb_sunny;
  List<Color> _weatherGradient = [const Color(0xFF2962FF), const Color(0xFF448AFF)];

  double _sensorHumidity = 65.5;
  double _sensorTemperature = 28.5;
  double _sensorLight = 850.0;
  double _sensorRainIntensity = 4095; // 4095 = Dry, < 2000 = Rain
  double _rainConfidence = 0.0;

  // History Lists for Charts
  final List<SensorDataPoint> _humidityHistory = [];
  final List<SensorDataPoint> _tempHistory = [];
  final List<SensorDataPoint> _lightHistory = [];
  final List<SensorDataPoint> _rainHistory = [];
  final List<SensorDataPoint> _rainConfidenceHistory = [];

  Timer? _simulationTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _prefillHistory(); 
    _startSimulation();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  // --- REAL: FETCH USER FROM FIREBASE ---
  Future<void> _fetchUserData() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          if (data['displayName'] != null && data['displayName'].toString().isNotEmpty) {
            _userName = data['displayName'];
          } else if (data['firstName'] != null) {
            _userName = "${data['firstName']} ${data['lastName'] ?? ''}";
          } else {
            _userName = "User";
          }

          _userEmail = data['email'] ?? user.email ?? "No Email";
          _userProfileUrl = data['photoUrl'];
          
          if (data['createdAt'] != null) {
             DateTime date = (data['createdAt'] as Timestamp).toDate();
             _memberSince = "${_getMonthName(date.month)} ${date.year}";
          } else {
             _memberSince = "Recently";
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // --- FAKE: DYNAMIC WEATHER SIMULATION LOGIC ---
  void _startSimulation() {
    // Initial update
    _updateSimulatedData();
    
    _simulationTimer = Timer.periodic(
      const Duration(seconds: SENSOR_UPDATE_INTERVAL_SECONDS),
      (_) => _updateSimulatedData(),
    );
  }

  void _updateSimulatedData() {
    if (!mounted) return;
    setState(() {
      DateTime now = DateTime.now();

      // 1. Randomly pick a weather condition
      // 0-3: Sunny/Cloudy (Likely), 4-5: Rain (Less Likely), 6: Storm (Rare)
      int weatherRoll = _random.nextInt(10); 
      
      // Target values based on weather
      double targetTemp, targetHum, targetLight, targetRain;

      if (weatherRoll < 4) { 
        // SUNNY / CLEAR
        _weatherCondition = "Sunny";
        _weatherDescription = "Clear skies, perfect for drying";
        _weatherIcon = Icons.wb_sunny;
        _weatherGradient = [const Color(0xFF2962FF), const Color(0xFF448AFF)]; // Blue
        
        targetTemp = 30.0 + _random.nextDouble() * 3; // Hot (30-33)
        targetHum = 50.0 + _random.nextDouble() * 10; // Dry (50-60%)
        targetLight = 3000.0 + _random.nextDouble() * 1000; // Bright
        targetRain = 4095; // Dry Sensor
        _rainConfidence = 5.0 + _random.nextDouble() * 5; // Low chance

      } else if (weatherRoll < 7) {
        // CLOUDY / OVERCAST
        _weatherCondition = "Cloudy";
        _weatherDescription = "Overcast, moderate drying";
        _weatherIcon = Icons.cloud;
        _weatherGradient = [const Color(0xFF78909C), const Color(0xFF90A4AE)]; // Grey-Blue
        
        targetTemp = 27.0 + _random.nextDouble() * 2; // Mild (27-29)
        targetHum = 70.0 + _random.nextDouble() * 10; // Humid (70-80%)
        targetLight = 800.0 + _random.nextDouble() * 400; // Dimmer
        targetRain = 4095; // Dry Sensor
        _rainConfidence = 40.0 + _random.nextDouble() * 20; // Medium chance

      } else if (weatherRoll < 9) {
        // RAINY
        _weatherCondition = "Rainy";
        _weatherDescription = "Light rain, rod retracted";
        _weatherIcon = Icons.grain;
        _weatherGradient = [const Color(0xFF455A64), const Color(0xFF607D8B)]; // Dark Grey
        
        targetTemp = 24.0 + _random.nextDouble() * 2; // Cool (24-26)
        targetHum = 90.0 + _random.nextDouble() * 5; // Very Humid (90-95%)
        targetLight = 300.0 + _random.nextDouble() * 200; // Dark
        targetRain = 1500; // Wet Sensor (< 2000)
        _rainConfidence = 85.0 + _random.nextDouble() * 10; // High chance

      } else {
        // THUNDERSTORM
        _weatherCondition = "Storm";
        _weatherDescription = "Heavy rain & wind alert";
        _weatherIcon = Icons.thunderstorm;
        _weatherGradient = [const Color(0xFF263238), const Color(0xFF37474F)]; // Very Dark
        
        targetTemp = 22.0 + _random.nextDouble() * 2; // Cold
        targetHum = 98.0; // Max Humidity
        targetLight = 100.0; // Very Dark
        targetRain = 500; // Very Wet (< 1000)
        _rainConfidence = 100.0; // Certain
      }

      // 2. Smoothly transition values (Mock inertia)
      // Instead of jumping instantly, move 20% towards the target
      _sensorTemperature += (targetTemp - _sensorTemperature) * 0.2;
      _sensorHumidity += (targetHum - _sensorHumidity) * 0.2;
      _sensorLight += (targetLight - _sensorLight) * 0.2;
      
      // Rain sensor jumps instantly because rain is sudden
      _sensorRainIntensity = targetRain;

      // Add noise to make graphs look real
      _sensorTemperature += (_random.nextDouble() - 0.5) * 0.2;
      _sensorHumidity += (_random.nextDouble() - 0.5) * 1.0;

      // 3. Update History
      _addToHistory(_humidityHistory, _sensorHumidity, now);
      _addToHistory(_tempHistory, _sensorTemperature, now);
      _addToHistory(_lightHistory, _sensorLight, now);
      _addToHistory(_rainHistory, _sensorRainIntensity, now);
      _addToHistory(_rainConfidenceHistory, _rainConfidence, now);
      _cleanupOldHistory();
    });
  }

  void _prefillHistory() {
    DateTime now = DateTime.now();
    for (int i = 15; i >= 0; i--) {
      DateTime time = now.subtract(Duration(minutes: i * 2));
      _addToHistory(_humidityHistory, 65.0 + sin(i)*5, time);
      _addToHistory(_tempHistory, 28.0 + cos(i)*2, time);
      _addToHistory(_lightHistory, 800.0 + _random.nextInt(200), time);
      _addToHistory(_rainConfidenceHistory, 5.0 + _random.nextDouble() * 5, time);
      _addToHistory(_rainHistory, 4095, time);
    }
  }

  void _addToHistory(List<SensorDataPoint> history, double value, DateTime timestamp) {
    history.add(SensorDataPoint(value: value, timestamp: timestamp));
  }

  void _cleanupOldHistory() {
    if (_humidityHistory.length > 20) _humidityHistory.removeAt(0);
    if (_tempHistory.length > 20) _tempHistory.removeAt(0);
    if (_lightHistory.length > 20) _lightHistory.removeAt(0);
    if (_rainConfidenceHistory.length > 20) _rainConfidenceHistory.removeAt(0);
    if (_rainHistory.length > 20) _rainHistory.removeAt(0);
  }

  // --- HELPER: Initials ---
  String _getInitials(String name) {
    if (name.isEmpty || name == "Loading...") return "";
    List<String> nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.isEmpty) return "U";
    String first = nameParts[0].isNotEmpty ? nameParts[0][0] : "";
    String last = nameParts.length > 1 && nameParts[1].isNotEmpty ? nameParts[1][0] : "";
    return (first + last).toUpperCase();
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFF2962FF), 
                            backgroundImage: _userProfileUrl != null ? NetworkImage(_userProfileUrl!) : null,
                            child: _userProfileUrl == null 
                              ? Text(_getInitials(_userName), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))
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
                      Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      const SizedBox(height: 4),
                      Text(_userEmail, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(height: 32),
                      
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
                            Navigator.pop(context); // Close Modal
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => const EditProfileScreen())
                            ).then((_) {
                              _fetchUserData(); 
                            });
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
                            if (mounted) Navigator.pop(context);
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
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E2339)), overflow: TextOverflow.ellipsis),
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
                            const Text("Recent History (Simulated)", style: TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 20),
                            SizedBox(height: 150, width: double.infinity, child: CustomPaint(painter: TimeSeriesChartPainter(data: historyData, color: const Color(0xFF2962FF)))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      const SizedBox(height: 8),
                      Text(statusMsg, style: const TextStyle(fontSize: 14, color: Color(0xFF5A6175), height: 1.5)),
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
    final double padding = MediaQuery.of(context).size.width * 0.05;

    // Helper for Rain Text
    String getRainStatus() {
      if (_sensorRainIntensity > 3500) return "Dry";
      if (_sensorRainIntensity > 2000) return "Moist";
      return "Wet"; 
    }

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
                    backgroundColor: const Color(0xFF2962FF), 
                    backgroundImage: _userProfileUrl != null ? NetworkImage(_userProfileUrl!) : null,
                    child: _userProfileUrl == null 
                      ? Text(_getInitials(_userName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- STATIC WEATHER CARD (Now Dynamic) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                // Dynamic Gradient based on weather
                gradient: LinearGradient(colors: _weatherGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: _weatherGradient.last.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
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
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on, color: Colors.white, size: 12), SizedBox(width: 4), Text("Quezon City", style: TextStyle(color: Colors.white, fontSize: 12))]),
                        ),
                        const SizedBox(height: 12),
                        Text(_weatherCondition, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(_weatherDescription, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4)),
                        const SizedBox(height: 10),
                        // Current Sim Temp
                        Text("${_sensorTemperature.toStringAsFixed(0)}°", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Icon(_weatherIcon, size: 60, color: Colors.yellowAccent),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- SENSOR CARDS ---
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
                  onTap: () => _showDetailModal("Humidity", "${_sensorHumidity.toStringAsFixed(1)}%", _humidityHistory, "Humidity is fluctuating based on weather.")
                ),
                _buildSensorCard(
                  title: "Temperature", 
                  value: "${_sensorTemperature.toStringAsFixed(1)}°C", 
                  icon: Icons.thermostat, 
                  color: Colors.blue, 
                  bgColor: const Color(0xFFE3F2FD), 
                  onTap: () => _showDetailModal("Temperature", "${_sensorTemperature.toStringAsFixed(1)}°C", _tempHistory, "Temperature adapts to simulated weather.")
                ),
                _buildSensorCard(
                  title: "Rain Sensor", 
                  value: getRainStatus(), 
                  subtitle: getRainStatus() == "Dry" ? "Safe" : "Alert", 
                  icon: Icons.cloud_outlined, 
                  color: getRainStatus() == "Dry" ? Colors.green : Colors.orange, 
                  bgColor: const Color(0xFFFFF3E0), 
                  onTap: () => _showDetailModal("Rain Sensor", getRainStatus(), _rainHistory, "Detects rain when weather turns bad.")
                ),
                _buildCircleProgressCard(
                  title: "Rain Chance", 
                  percentage: _rainConfidence.toInt(), 
                  icon: Icons.thunderstorm_outlined, 
                  onTap: () => _showDetailModal("Rain Chance", "${_rainConfidence.toInt()}%", _rainConfidenceHistory, "Calculated based on current weather.")
                ),
                _buildSensorCard(
                  title: "Ambient Light", 
                  value: "${_sensorLight.toStringAsFixed(0)} lux", 
                  icon: Icons.wb_sunny_outlined, 
                  color: Colors.orange, 
                  bgColor: const Color(0xFFFFF3E0), 
                  onTap: () => _showDetailModal("Ambient Light", "${_sensorLight.toStringAsFixed(0)} lux", _lightHistory, "Varies with cloud cover.")
                ),
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
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8), 
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), 
              child: Icon(icon, color: color, size: 20)
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
    
    // Find min and max values safely
    double maxVal = data.first.value;
    double minVal = data.first.value;
    for (var point in data) {
      if (point.value > maxVal) maxVal = point.value;
      if (point.value < minVal) minVal = point.value;
    }
    
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