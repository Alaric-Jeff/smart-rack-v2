import 'package:flutter/material.dart';
import 'terms_and_condtions.dart'; // Make sure this matches your actual file name!
import 'edit_profile.dart'; // Ensure this import is present
import 'device_pairing.dart'; // <--- IMPORT ADDED for the new screen

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- STATE VARIABLES ---
  bool _autoRetract = true; 
  bool _safetyLock = true;
  bool _notificationsEnabled = true; 
  double _rainSensitivity = 50;
  
  // User Data (For the Modal)
  final String _userName = "Kirby Gabayno"; 
  final String _userEmail = "kirbygabayno@gmail.com";
  final String _deviceId = "LD-2024-8X9K"; 
  final String _memberSince = "December 2025";
  String? _userProfileUrl;

  // --- LOGIC: UPDATE SETTINGS ---
  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() {
      if (key == 'auto_retract') _autoRetract = value;
      if (key == 'safety_lock') _safetyLock = value;
      if (key == 'notifications') _notificationsEnabled = value;
      if (key == 'rain_sensitivity') _rainSensitivity = value;
    });
    debugPrint("Setting Updated -> $key: $value");
  }

  // --- MODAL: DEVICE INFO ---
  void _showDeviceInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Device Information", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(Icons.wifi, "Connection", "Online (WiFi)"),
              const Divider(),
              _buildInfoRow(Icons.router, "IP Address", "192.168.1.45"),
              const Divider(),
              _buildInfoRow(Icons.memory, "Firmware", "v1.0.2-stable"),
              const Divider(),
              _buildInfoRow(Icons.access_time, "Last Sync", "Just now"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE", style: TextStyle(color: Color(0xFF2962FF))),
            ),
          ],
        );
      },
    );
  }

  // --- MODAL: ACCOUNT ---
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
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Account", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))
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
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: _userProfileUrl != null ? NetworkImage(_userProfileUrl!) : const AssetImage('assets/user_placeholder.png') as ImageProvider,
                            child: _userProfileUrl == null ? const Icon(Icons.person, size: 50, color: Colors.blue) : null,
                          ),
                          Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Icon(Icons.edit, size: 16, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      const SizedBox(height: 4),
                      Text(_userEmail, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(height: 32),
                      Align(alignment: Alignment.centerLeft, child: Text("Account Information", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]))),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(20)),
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
                      
                      // --- EDIT PROFILE BUTTON ---
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () { 
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text("EDIT PROFILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); }, icon: const Icon(Icons.logout, size: 20, color: Colors.black87), label: const Text("SIGN OUT", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: const Color(0xFFF5F6FA)))),
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

  // Helper for Info Rows
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.grey[700], size: 20)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E2339))),
            ],
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double padding = size.width * 0.05;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Settings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const SizedBox(height: 4),
              const Text("Preferences and configuration", style: TextStyle(fontSize: 14, color: Color(0xFF5A6175), fontWeight: FontWeight.w500)),
              const SizedBox(height: 32),

              // --- 1. Device Automation ---
              const Text("Device Automation", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    _buildSwitchTile(title: "Auto-Retract on Rain", subtitle: "Automatically pull in rod when rain is detected", icon: Icons.flash_on_rounded, value: _autoRetract, onChanged: (val) => _updateSetting('auto_retract', val)),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),
                    _buildSwitchTile(title: "Safety Lock", subtitle: "Prevent manual controls when heavy load detected", icon: Icons.shield_outlined, value: _safetyLock, onChanged: (val) => _updateSetting('safety_lock', val)),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- 2. Calibration ---
              const Text("Calibration", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.tune, color: Color(0xFF1E2339), size: 22)),
                        const SizedBox(width: 16),
                        const Text("Rain Sensitivity", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                        const Spacer(),
                        Text("${_rainSensitivity.round()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: _rainSensitivity, 
                      min: 0, 
                      max: 100, 
                      activeColor: const Color(0xFF2962FF),
                      inactiveColor: Colors.grey.shade200,
                      onChanged: (val) => _updateSetting('rain_sensitivity', val),
                    ),
                    const Text("Adjust threshold for rain detection. Lower values mean higher sensitivity.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- 3. App Settings ---
              const Text("App Settings", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    _buildSwitchTile(title: "Notifications", subtitle: "Receive alerts for rain and completion", icon: Icons.notifications_active_outlined, value: _notificationsEnabled, onChanged: (val) => _updateSetting('notifications', val)),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),
                    
                    _buildNavTile(title: "Account", icon: Icons.person_outline, onTap: _showAccountModal),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),
                    
                    // --- DEVICE PAIRING (Now Navigates to Screen) ---
                    _buildNavTile(
                      title: "Device Pairing", 
                      icon: Icons.smartphone_outlined, 
                      onTap: () {
                         // Navigation to the dedicated pairing screen
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (context) => const DevicePairingScreen()),
                         );
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),
                    // ------------------------------------------------

                    _buildNavTile(title: "Device Info", icon: Icons.info_outline, onTap: _showDeviceInfo),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),
                    
                    // --- TERMS AND CONDITIONS ---
                    _buildNavTile(
                      title: "Terms & Conditions", 
                      icon: Icons.description_outlined, 
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen()));
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),
                    
                    _buildNavTile(title: "Log Out", icon: Icons.logout, onTap: () { Navigator.pop(context); }),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required IconData icon, required bool value, required Function(bool) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF1E2339), size: 22)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9095A1), height: 1.4))])),
          const SizedBox(width: 10),
          Switch(value: value, onChanged: onChanged, activeThumbColor: Colors.white, activeTrackColor: const Color(0xFF2962FF), inactiveThumbColor: Colors.white, inactiveTrackColor: Colors.grey.shade300),
        ],
      ),
    );
  }

  Widget _buildNavTile({required String title, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF1E2339), size: 22)),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E2339)))),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}