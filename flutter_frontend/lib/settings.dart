import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart'; 

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
  // --- STATE VARIABLES ---
  bool _autoRetract = false; 
  bool _childProtection = false; // REPLACED _safetyLock
  bool _notificationsEnabled = true; 
  double _rainSensitivity = 0.0;     
  
  // --- 2FA State ---
  bool _is2FAEnabled = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // User Data 
  String _userName = "Loading..."; 
  String _userEmail = "Loading...";
  String _deviceId = "Loading..."; 
  String _memberSince = "Loading...";
  String? _userProfileUrl;
  bool _isLoadingUserData = false;

  // Store actual device ID for RTDB calls
  String? _actualDeviceId; 

  @override
  void initState() {
    super.initState();
    _loadPreferences(); 
    _fetchUserData(showLoading: true); 
  }

  // --- LOAD SETTINGS ---
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      
      setState(() {
        _autoRetract = prefs.getBool('auto_retract') ?? false;
        _childProtection = prefs.getBool('child_protection') ?? false;
        _notificationsEnabled = prefs.getBool('notifications') ?? true;
        _rainSensitivity = prefs.getDouble('rain_sensitivity') ?? 0.0;
      });
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
  }

  // --- HELPER: INITIALS ---
  String _getInitials(String name) {
    if (name.isEmpty || name == "Loading...") return "";
    List<String> nameParts = name.trim().split(RegExp(r'\s+')); 
    if (nameParts.isEmpty) return "U";
    
    String first = nameParts[0].isNotEmpty ? nameParts[0][0] : "";
    String last = nameParts.length > 1 && nameParts[1].isNotEmpty ? nameParts[1][0] : "";
    
    String initials = (first + last).toUpperCase();
    return initials.isEmpty ? "U" : initials;
  }

  // --- FETCH USER DATA ---
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
            _actualDeviceId = null;
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
        
        bool is2FA = data['is2FAEnabled'] ?? false;

        // Get actual device ID for RTDB
        String? currentDevId = data['currentDeviceConnected'] as String?;
        if (currentDevId == null || currentDevId.isEmpty) {
          if (data.containsKey('devices') && data['devices'] is List) {
            List devices = data['devices'] as List;
            if (devices.isNotEmpty) {
              currentDevId = devices[0].toString();
            }
          }
        }

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

        String displayDeviceId = "LD-${user.uid.substring(0, 8).toUpperCase()}";

        if (mounted) {
          setState(() {
            _userName = finalDisplayName;
            _userEmail = email;
            _deviceId = displayDeviceId;
            _actualDeviceId = currentDevId; 
            _memberSince = memberSince;
            _userProfileUrl = photoUrl;
            _is2FAEnabled = is2FA; 
            _isLoadingUserData = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userName = user.displayName ?? 'User';
            _userEmail = user.email ?? 'No email';
            _deviceId = "LD-${user.uid.substring(0, 8).toUpperCase()}";
            _actualDeviceId = null;
            _memberSince = "Recently";
            _userProfileUrl = user.photoURL;
            _isLoadingUserData = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = "Error";
          _userEmail = "Retry later";
          _deviceId = "N/A";
          _actualDeviceId = null;
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

  // --- SIGN OUT ---
  Future<void> _signOut() async {
    try {
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Sign Out?", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
          content: const Text("Are you sure you want to sign out?"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("SIGN OUT", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldSignOut != true) return;

      final user = _auth.currentUser;
      
      if (user != null) {
        bool isGoogleSignIn = user.providerData.any(
          (provider) => provider.providerId == 'google.com'
        );
        
        if (isGoogleSignIn) {
          try {
            final googleSignIn = GoogleSignIn();
            await googleSignIn.signOut();
            debugPrint('Signed out from Google Sign-In');
          } catch (googleError) {
            debugPrint('Google Sign-In sign out skipped: $googleError');
          }
        } else {
          debugPrint('Manual email/password sign-in detected - skipping Google Sign-In sign out');
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- NEW: CHILD PROTECTION TOGGLE WITH PASSWORD VERIFICATION ---
  Future<void> _handleChildProtectionToggle(bool newValue) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Check if user has an email/password provider
    bool hasPassword = user.providerData.any((info) => info.providerId == 'password');

    // 2. If NO password (e.g., SSO only), prompt to set one in Edit Profile
    if (!hasPassword) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Password Required", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
          content: const Text("You are signed in via Google (SSO). To use Child Protection, you must set a password in your profile first."),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())).then((_) => _fetchUserData());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("EDIT PROFILE", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // 3. If HAS password, prompt to enter it
    final TextEditingController passwordController = TextEditingController();
    bool isVerifying = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Security Verification", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Please enter your password to turn ${newValue ? 'ON' : 'OFF'} Child Protection."),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Password",
                      errorText: errorMessage,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(dialogContext),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isVerifying ? null : () async {
                    if (passwordController.text.isEmpty) {
                      setDialogState(() => errorMessage = "Password cannot be empty");
                      return;
                    }

                    setDialogState(() {
                      isVerifying = true;
                      errorMessage = null;
                    });

                    try {
                      AuthCredential credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: passwordController.text,
                      );
                      
                      // Re-authenticate
                      await user.reauthenticateWithCredential(credential);
                      
                      // Success! Proceed to update settings
                      if (mounted) {
                        Navigator.pop(dialogContext);
                        _updateSetting('child_protection', newValue);
                      }
                    } catch (e) {
                      setDialogState(() {
                        isVerifying = false;
                        errorMessage = "Incorrect password. Please try again.";
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isVerifying 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("VERIFY", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // --- SETTINGS UPDATER ---
  Future<void> _updateSetting(String key, dynamic value) async {
    // 1. Update UI and SharedPreferences instantly
    setState(() {
      if (key == 'auto_retract') _autoRetract = value;
      if (key == 'child_protection') _childProtection = value;
      if (key == 'notifications') _notificationsEnabled = value;
      if (key == 'rain_sensitivity') _rainSensitivity = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      if (key == 'auto_retract') await prefs.setBool('auto_retract', value);
      if (key == 'child_protection') await prefs.setBool('child_protection', value);
      if (key == 'notifications') await prefs.setBool('notifications', value);
      if (key == 'rain_sensitivity') await prefs.setDouble('rain_sensitivity', value);
    } catch (e) {
      debugPrint("Error saving setting to SharedPreferences: $e");
    }

    // 2. If it is Child Protection, also update Realtime Database
    if (key == 'child_protection') {
      if (_actualDeviceId != null && _actualDeviceId!.isNotEmpty) {
        try {
          await FirebaseDatabase.instance
              .ref('devices/$_actualDeviceId/settings')
              .update({'childProtection': value});
              
          debugPrint("Child Protection status ($value) sent to RTDB.");
          
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(value ? "Child Protection Enabled" : "Child Protection Disabled"),
                backgroundColor: value ? Colors.blue : Colors.grey,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          debugPrint("Error saving Child Protection to RTDB: $e");
          // Revert UI if RTDB fails
          setState(() {
            _childProtection = !value; 
          });
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Failed to update Child Protection on device."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        debugPrint("Cannot update Child Protection: No device connected.");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No device connected. Settings saved locally."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    // --- Notification Pop Up Logic ---
    if (key == 'notifications' && value == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Notifications Enabled"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- TOGGLE 2FA LOGIC ---
  Future<void> _toggle2FA(bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      bool isPhoneVerified = userDoc.data()?['isPhoneVerified'] ?? false;

      if (value == true && !isPhoneVerified) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Action Required", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              content: const Text("You must verify your phone number in 'Account > Edit Profile' before enabling 2FA."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
              ],
            ),
          );
        }
        return; 
      }

      await _firestore.collection('users').doc(user.uid).update({
        'is2FAEnabled': value
      });

      setState(() {
        _is2FAEnabled = value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? "2-Factor Authentication Enabled" : "2-Factor Authentication Disabled"),
            backgroundColor: value ? Colors.green : Colors.grey,
          ),
        );
      }

    } catch (e) {
      debugPrint("Error toggling 2FA: $e");
    }
  }

  // --- BLE FUNCTION (Placeholder) ---
  void _onBluetoothTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bluetooth functionality ready for integration.")),
    );
  }

  // --- CONFIRMATION MODAL (For simple toggles) ---
  void _showConfirmation(String title, bool newValue, VoidCallback onConfirm) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Change $title?", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
          content: Text("Are you sure you want to turn ${newValue ? 'ON' : 'OFF'} $title?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
                onConfirm(); 
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("CONFIRM", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
                                  backgroundColor: const Color(0xFF2962FF), 
                                  backgroundImage: _userProfileUrl != null && _userProfileUrl!.isNotEmpty
                                      ? NetworkImage(_userProfileUrl!)
                                      : null,
                                  child: _userProfileUrl == null || _userProfileUrl!.isEmpty
                                      ? Text(
                                          _getInitials(_userName),
                                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
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
                                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
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
                                onPressed: () {
                                  Navigator.pop(context); 
                                  _signOut(); 
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
                    // --- CHILD PROTECTION TOGGLE ---
                    _buildSwitchTile(
                      title: "Child Protection", 
                      subtitle: "Require password to access manual controls", 
                      icon: Icons.shield_outlined, 
                      value: _childProtection, 
                      onChanged: (val) {
                        _handleChildProtectionToggle(val);
                      }
                    ),
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
                    // --- 2FA SWITCH ---
                    _buildSwitchTile(
                      title: "2-Factor Auth",
                      subtitle: "Secure login with OTP",
                      icon: Icons.security_outlined,
                      value: _is2FAEnabled,
                      onChanged: (val) {
                        _showConfirmation("2-Factor Auth", val, () => _toggle2FA(val));
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),

                    _buildSwitchTile(
                      title: "Notifications", 
                      subtitle: "Receive alerts for rain and completion", 
                      icon: Icons.notifications_active_outlined, 
                      value: _notificationsEnabled, 
                      onChanged: (val) {
                        _showConfirmation("Notifications", val, () => _updateSetting('notifications', val));
                      }
                    ),
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

                    // --- BLUETOOTH BUTTON ---
                    _buildNavTile(
                      title: "Bluetooth Connection", 
                      icon: Icons.bluetooth, 
                      onTap: _onBluetoothTap, 
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