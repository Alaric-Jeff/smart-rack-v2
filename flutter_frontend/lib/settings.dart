import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'terms_and_condtions.dart';
import 'edit_profile.dart';
import 'device_pairing.dart';
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoRetract = true; 
  bool _safetyLock = true;
  bool _notificationsEnabled = true; 
  double _rainSensitivity = 50;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _userName = "Loading..."; 
  String _userEmail = "Loading...";
  String _deviceId = "Loading..."; 
  String _memberSince = "Loading...";
  String? _userProfileUrl;
  bool _isLoadingUserData = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData(showLoading: true);
  }

  Future<void> _fetchUserData({bool showLoading = false}) async {
    try {
      final bool shouldShowLoading = showLoading || _userName == "Loading...";
      if (shouldShowLoading) {
        setState(() => _isLoadingUserData = true);
      }

      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _userName = "Guest";
            _userEmail = "Not logged in";
            _deviceId = "N/A";
            _memberSince = "N/A";
            _isLoadingUserData = false;
          });
        }
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;

        String? displayName = data['displayName'];
        String? firstName = data['firstName'];
        String? lastName = data['lastName'];
        String email = data['email'] ?? user.email ?? 'No email';
        String? photoUrl = data['photoUrl'];
        Timestamp? createdAt = data['createdAt'];

        String finalDisplayName;
        if (displayName != null && displayName.isNotEmpty) {
          finalDisplayName = displayName;
        } else if (firstName != null && lastName != null) {
          finalDisplayName = '$firstName $lastName';
        } else if (firstName != null) {
          finalDisplayName = firstName;
        } else {
          finalDisplayName = user.displayName ?? 'User';
        }

        String memberSince = "Recently";
        if (createdAt != null) {
          DateTime date = createdAt.toDate();
          memberSince = "${_getMonthName(date.month)} ${date.year}";
        }

        String deviceId = "LD-${user.uid.substring(0, 8).toUpperCase()}";

        if (mounted) {
          setState(() {
            _userName = finalDisplayName;
            _userEmail = email;
            _deviceId = deviceId;
            _memberSince = memberSince;
            _userProfileUrl = photoUrl;
            _isLoadingUserData = false;
          });
        }

        debugPrint('=== USER DATA FETCHED ===');
        debugPrint('Display Name: $_userName');
        debugPrint('Email: $_userEmail');
        debugPrint('Device ID: $_deviceId');
        debugPrint('Member Since: $_memberSince');
        debugPrint('Photo URL: ${_userProfileUrl ?? "No photo"}');
        debugPrint('========================');
      } else {
        if (mounted) {
          setState(() {
            _userName = user.displayName ?? 'User';
            _userEmail = user.email ?? 'No email';
            _deviceId = "LD-${user.uid.substring(0, 8).toUpperCase()}";
            _memberSince = "Recently";
            _userProfileUrl = user.photoURL;
            _isLoadingUserData = false;
          });
        }
        
        debugPrint('Warning: User document not found in Firestore');
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      
      if (mounted) {
        setState(() {
          _userName = "Error loading data";
          _userEmail = "Please try again";
          _deviceId = "N/A";
          _memberSince = "N/A";
          _isLoadingUserData = false;
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

  Future<void> _signOut() async {
    try {
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "Sign Out?",
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2339)),
          ),
          content: const Text("Are you sure you want to sign out?"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "CANCEL",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "SIGN OUT",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (shouldSignOut != true) return;

      // Check if user signed in with Google before trying to sign out
      final user = _auth.currentUser;
      if (user != null) {
        bool isGoogleSignIn = user.providerData.any(
          (provider) => provider.providerId == 'google.com'
        );
        
        if (isGoogleSignIn) {
          await GoogleSignIn().signOut();
          debugPrint('Signed out from Google');
        }
      }

      await _auth.signOut();
      debugPrint('Signed out from Firebase Auth');

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() {
      if (key == 'auto_retract') _autoRetract = value;
      if (key == 'safety_lock') _safetyLock = value;
      if (key == 'notifications') _notificationsEnabled = value;
      if (key == 'rain_sensitivity') _rainSensitivity = value;
    });
    debugPrint("Setting Updated -> $key: $value");
  }

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

  void _showAccountModal() {
    _fetchUserData(showLoading: false);
    
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
                child: (_isLoadingUserData && _userName == "Loading...")
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
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: _userProfileUrl != null && _userProfileUrl!.isNotEmpty
                                      ? NetworkImage(_userProfileUrl!)
                                      : null,
                                  child: _userProfileUrl == null || _userProfileUrl!.isEmpty
                                      ? const Icon(Icons.person, size: 50, color: Colors.blue)
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
                            Text(
                              _userName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2339)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 32),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Account Information",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                              ),
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
                            
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                                  ).then((_) {
                                    _fetchUserData();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2962FF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  "EDIT PROFILE",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _signOut();
                                },
                                icon: const Icon(Icons.logout, size: 20, color: Colors.black87),
                                label: const Text(
                                  "SIGN OUT",
                                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                                ),
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
                    
                    _buildNavTile(
                      title: "Device Pairing", 
                      icon: Icons.smartphone_outlined, 
                      onTap: () {
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (context) => const DevicePairingScreen()),
                         );
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),

                    _buildNavTile(title: "Device Info", icon: Icons.info_outline, onTap: _showDeviceInfo),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),
                    
                    _buildNavTile(
                      title: "Terms & Conditions", 
                      icon: Icons.description_outlined, 
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen()));
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),
                    
                    _buildNavTile(title: "Log Out", icon: Icons.logout, onTap: _signOut),
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