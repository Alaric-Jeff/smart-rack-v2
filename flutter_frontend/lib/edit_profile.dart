import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import './sms/send_otp.dart';
import './sms/verify_otp.dart';
import './cloudinary/setImage.dart';
import './cloudinary/deleteImage.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSendingOtp = false;
  bool _isUploadingImage = false; // NEW: Track image upload state

  bool _isPhoneVerified = false;

  late TextEditingController _displayNameController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _addressController;

  String? _photoUrl;
  String? _photoPublicId; // NEW: Store Cloudinary public_id
  File? _selectedImage;
  bool _hasPassword = false;
  String? _signInProvider;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Deactivation Variables ---
  String? _selectedDeactivationReason;
  final List<String> _deactivationReasons = [
    "I need a break",
    "I have privacy concerns",
    "I created a new account",
    "The app is not useful for me",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _contactNumberController = TextEditingController();
    _addressController = TextEditingController();

    _displayNameController.addListener(() {
      if (mounted) setState(() {});
    });
    _firstNameController.addListener(() {
      if (mounted) setState(() {});
    });
    _lastNameController.addListener(() {
      if (mounted) setState(() {});
    });

    _contactNumberController.addListener(() {
      if (_isPhoneVerified && mounted) {
        setState(() {
          _isPhoneVerified = false;
        });
      }
    });

    _fetchUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // --- UPDATED: Pick and Upload Image Immediately ---
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      // Show the image locally first
      setState(() {
        _selectedImage = File(image.path);
        _isUploadingImage = true;
      });

      // Convert to base64
      final bytes = await File(image.path).readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar("User not logged in", Colors.red);
        setState(() => _isUploadingImage = false);
        return;
      }

      // Upload to Cloudinary
      await setImage(
        userId: user.uid,
        fileBase64: base64Image,
        oldPublicId: _photoPublicId, // Delete old image if exists
      );

      // Fetch updated user data to get new URL and public_id
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data();

      if (mounted) {
        setState(() {
          _photoUrl = data?['image_url'];
          _photoPublicId = data?['image_public_id'];
          _selectedImage = null; // Clear local file
          _isUploadingImage = false;
        });
        _showSnackBar('Image uploaded successfully!', Colors.green);
      }
    } catch (e) {
      debugPrint("Image Upload Error: $e");
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showSnackBar("Error uploading image: ${e.toString()}", Colors.red);
      }
    }
  }

  // --- NEW: Delete Profile Image ---
  Future<void> _deleteImage() async {
    if (_photoPublicId == null) {
      _showSnackBar("No image to delete", Colors.orange);
      return;
    }

    // Confirm deletion
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Profile Picture?"),
        content: const Text("Are you sure you want to remove your profile picture?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _isUploadingImage = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar("User not logged in", Colors.red);
        setState(() => _isUploadingImage = false);
        return;
      }

      await deleteImage(userId: user.uid);

      if (mounted) {
        setState(() {
          _photoUrl = null;
          _photoPublicId = null;
          _isUploadingImage = false;
        });
        _showSnackBar('Profile picture removed', Colors.green);
      }
    } catch (e) {
      debugPrint("Image Delete Error: $e");
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showSnackBar("Error deleting image: ${e.toString()}", Colors.red);
      }
    }
  }

  Future<List<String>> _fetchAddressSuggestions(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse('https://photon.komoot.io/api/?q=$query&limit=5');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['features'] as List).map((item) {
          final props = item['properties'];
          String name = props['name'] ?? '';
          String street = props['street'] ?? '';
          String city = props['city'] ?? props['state'] ?? '';
          String country = props['country'] ?? '';
          return [
            name,
            street,
            city,
            country,
          ].where((part) => part.isNotEmpty).join(', ');
        }).toList();
      }
    } catch (e) {
      debugPrint("Address API Error: $e");
    }
    return [];
  }

  Future<void> _verifyPhoneNumber() async {
    String number = _contactNumberController.text.trim();
    if (number.length != 10 || !number.startsWith('9')) {
      _showSnackBar(
        "Please enter a valid 10-digit number starting with 9",
        Colors.red,
      );
      return;
    }

    String fullPhoneNumber = "+63$number";
    setState(() => _isSendingOtp = true);

    try {
      final result = await sendOtp(phoneNumber: fullPhoneNumber);
      setState(() => _isSendingOtp = false);

      if (result['status'] == 'success') {
        _showOtpVerificationDialog(fullPhoneNumber);
      } else {
        _showSnackBar(
          result['message'] ?? 'Failed to send OTP. Please try again.',
          Colors.red,
        );
      }
    } catch (e) {
      setState(() => _isSendingOtp = false);
      debugPrint("Send OTP Error: $e");
      _showSnackBar("Error sending OTP: ${e.toString()}", Colors.red);
    }
  }

  void _showOtpVerificationDialog(String phoneNumber) {
    TextEditingController otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Verify Phone Number"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("A verification code has been sent to $phoneNumber"),
                const SizedBox(height: 20),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Enter 6-digit OTP",
                    border: OutlineInputBorder(),
                    hintText: "000000",
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Please check your SMS inbox",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () => Navigator.pop(context),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        String otpCode = otpController.text.trim();

                        if (otpCode.length != 6) {
                          _showSnackBar(
                            "Please enter a 6-digit OTP",
                            Colors.orange,
                          );
                          return;
                        }

                        setDialogState(() => isVerifying = true);

                        try {
                          final result = await verifyOtp(
                            phoneNumber: phoneNumber,
                            otp: otpCode,
                          );

                          if (result['status'] == 'success') {
                            await _savePhoneVerification();
                            setState(() => _isPhoneVerified = true);
                            Navigator.pop(context);
                            _showSnackBar(
                              "Phone number verified successfully!",
                              Colors.green,
                            );
                          } else {
                            setDialogState(() => isVerifying = false);
                            _showSnackBar(
                              result['message'] ??
                                  'Invalid OTP. Please try again.',
                              Colors.red,
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isVerifying = false);
                          debugPrint("Verify OTP Error: $e");
                          _showSnackBar(
                            "Error verifying OTP: ${e.toString()}",
                            Colors.red,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                ),
                child: isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "VERIFY",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _savePhoneVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'contactNumber': "+63${_contactNumberController.text.trim()}",
        'isPhoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("Phone verification saved to Firestore");
    } catch (e) {
      debugPrint("Error saving phone verification: $e");
      _showSnackBar(
        "Phone verified but failed to save. Please click Save Changes.",
        Colors.orange,
      );
    }
  }

  String _getInitials() {
    String display = _displayNameController.text.trim();
    if (display.isNotEmpty) {
      List<String> parts = display.split(RegExp(r'\s+'));
      String first = parts[0][0];
      String last = parts.length > 1 ? parts[1][0] : "";
      return (first + last).toUpperCase();
    }

    String first = _firstNameController.text.trim();
    String last = _lastNameController.text.trim();
    String firstLetter = first.isNotEmpty ? first[0] : "";
    String lastLetter = last.isNotEmpty ? last[0] : "";

    String initials = (firstLetter + lastLetter).toUpperCase();
    return initials.isEmpty ? "U" : initials;
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        Navigator.pop(context);
        return;
      }
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      if (mounted) {
        setState(() {
          _displayNameController.text = data['displayName'] ?? '';
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';

          String rawPhone = data['contactNumber'] ?? '';
          if (rawPhone.startsWith('+63')) {
            _contactNumberController.text = rawPhone.substring(3);
          } else if (rawPhone.startsWith('09')) {
            _contactNumberController.text = rawPhone.substring(1);
          } else if (rawPhone.startsWith('0')) {
            _contactNumberController.text = rawPhone.substring(1);
          } else {
            _contactNumberController.text = rawPhone;
          }

          _addressController.text = data['address'] ?? '';
          
          // NEW: Load Cloudinary image data
          _photoUrl = data['image_url'];
          _photoPublicId = data['image_public_id'];
          
          _signInProvider = data['signInProvider'];
          _isPhoneVerified = data['isPhoneVerified'] ?? false;

          final passwordField = data['password'];
          _hasPassword =
              passwordField != null &&
              passwordField is String &&
              passwordField.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSavePressed() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "Save Changes?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text("Are you sure you want to update your profile?"),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performSave();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
              ),
              child: const Text(
                "CONFIRM",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      _showSnackBar("Please fix the errors highlighted in red.", Colors.red);
    }
  }

  Future<void> _performSave() async {
    setState(() => _isSaving = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final Map<String, dynamic> updates = {};

      // Image is already uploaded via _pickImage, so no need to upload here
      updates['displayName'] = _displayNameController.text.trim();
      updates['firstName'] = _firstNameController.text.trim();
      updates['lastName'] = _lastNameController.text.trim();
      updates['contactNumber'] = "+63${_contactNumberController.text.trim()}";
      updates['address'] = _addressController.text.trim();
      updates['updatedAt'] = FieldValue.serverTimestamp();
      updates['isPhoneVerified'] = _isPhoneVerified;

      await _firestore.collection('users').doc(user.uid).update(updates);

      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Profile updated successfully!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Error saving: ${e.toString()}', Colors.red);
      }
    }
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) => _PasswordDialog(
        hasPassword: _hasPassword,
        signInProvider: _signInProvider,
        onPasswordChange: _performPasswordChange,
        onPasswordSet: _performSetPassword,
        showSnackBar: _showSnackBar,
      ),
    );
  }

  Future<void> _performPasswordChange(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      await _firestore.collection('users').doc(user.uid).update({
        'password': newPassword,
      });
      if (mounted) setState(() => _hasPassword = true);
      _showSnackBar('Password changed successfully!', Colors.green);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Error', Colors.red);
    }
  }

  Future<void> _performSetPassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await user.updatePassword(newPassword);
      await _firestore.collection('users').doc(user.uid).update({
        'password': newPassword,
      });
      if (mounted) setState(() => _hasPassword = true);
      _showSnackBar('Password set successfully!', Colors.green);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Error', Colors.red);
    }
  }

  void _deactivateAccount() {
    _selectedDeactivationReason = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              "Deactivate Account",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "We're sorry to see you go. Please tell us why you are deactivating:",
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Reason",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  initialValue: _selectedDeactivationReason,
                  items: _deactivationReasons.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(reason, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => _selectedDeactivationReason = val);
                  },
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Your account will be deactivated immediately. You can recover it by logging in within 30 days. After 30 days, your data will be permanently deleted.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "CANCEL",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: _selectedDeactivationReason == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        _performDeactivation();
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  "DEACTIVATE",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performDeactivation() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      DateTime scheduledDeletion = DateTime.now().add(const Duration(days: 30));

      await _firestore.collection('users').doc(user.uid).update({
        'isDeactivated': true,
        'deactivationReason': _selectedDeactivationReason ?? "Unknown",
        'deactivatedAt': FieldValue.serverTimestamp(),
        'scheduledDeletionDate': Timestamp.fromDate(scheduledDeletion),
      });

      await _auth.signOut();

      if (mounted) {
        _showSnackBar(
          'Account deactivated. You can recover it within 30 days.',
          Colors.orange,
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error deactivating account: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Back",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2339),
                  ),
                ),
                const Text(
                  "Manage Account",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // --- UPDATED PROFILE PICTURE SECTION ---
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _isUploadingImage ? null : _pickImage,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2962FF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2962FF).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            image: _selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : (_photoUrl != null && _photoUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(_photoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                          ),
                          alignment: Alignment.center,
                          child: _isUploadingImage
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                )
                              : (_selectedImage == null &&
                                      (_photoUrl == null || _photoUrl!.isEmpty))
                                  ? Text(
                                      _getInitials(),
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 2,
                                      ),
                                    )
                                  : null,
                        ),
                      ),
                      
                      // Camera Icon (Upload)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploadingImage ? null : _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Color(0xFF2962FF),
                            ),
                          ),
                        ),
                      ),
                      
                      // Delete Icon (Only show if image exists)
                      if (_photoUrl != null && _photoUrl!.isNotEmpty)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploadingImage ? null : _deleteImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                const Text(
                  "Personal Information",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  "DISPLAY NAME",
                  _displayNameController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Cannot be empty";
                    }
                    if (val.length < 3) return "Too short (min 3 chars)";
                    if (val.length > 25) return "Too long (max 25 chars)";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "FIRST NAME",
                        _firstNameController,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z .-]'),
                          ),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Required";
                          }
                          if (val.length < 2) return "Too short";
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        "LAST NAME",
                        _lastNameController,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z .-]'),
                          ),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Required";
                          }
                          if (val.length < 2) return "Too short";
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PHONE NUMBER",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A6175),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 55,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black87,
                              width: 1.0,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              "+63",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _contactNumberController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: "9XX XXX XXXX",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.black87,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2962FF),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1.5,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Required";
                              }
                              if (!value.startsWith('9')) {
                                return "Must start with 9";
                              }
                              if (value.length != 10) {
                                return "Must be 10 digits";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          height: 55,
                          alignment: Alignment.center,
                          child: _isPhoneVerified
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 30,
                                )
                              : TextButton(
                                  onPressed: _isSendingOtp
                                      ? null
                                      : _verifyPhoneNumber,
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFE3F2FD),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isSendingOtp
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF2962FF),
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          "Verify",
                                          style: TextStyle(
                                            color: Color(0xFF2962FF),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                        ),
                      ],
                    ),

                    if (!_isPhoneVerified) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              "Phone number not verified. Tap 'Verify' to secure your account.",
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "STREET ADDRESS",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A6175),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return await _fetchAddressSuggestions(
                              textEditingValue.text,
                            );
                          },
                      onSelected: (String selection) {
                        _addressController.text = selection;
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                            if (controller.text != _addressController.text) {
                              controller.text = _addressController.text;
                            }
                            controller.addListener(() {
                              _addressController.text = controller.text;
                            });

                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return "Required";
                                }
                                if (val.length < 5) return "Invalid address";
                                return null;
                              },
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: "Search address...",
                                suffixIcon: const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.grey,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black87,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2962FF),
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                    width: 1.5,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: MediaQuery.of(context).size.width - 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: const BoxConstraints(maxHeight: 250),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (ctx, i) =>
                                    const Divider(height: 1),
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(
                                    index,
                                  );
                                  return ListTile(
                                    title: Text(
                                      option,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                const Text(
                  "Security",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: Icon(
                      _hasPassword
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                      size: 20,
                    ),
                    label: Text(
                      _hasPassword ? "CHANGE PASSWORD" : "SET PASSWORD",
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _onSavePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "SAVE CHANGES",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: _deactivateAccount,
                    child: const Text(
                      "Deactivate Account",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5A6175),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          inputFormatters: inputFormatters,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black87, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2962FF), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ========== PASSWORD DIALOG ==========
class _PasswordDialog extends StatefulWidget {
  final bool hasPassword;
  final String? signInProvider;
  final Future<void> Function(String, String) onPasswordChange;
  final Future<void> Function(String) onPasswordSet;
  final void Function(String, Color) showSnackBar;

  const _PasswordDialog({
    required this.hasPassword,
    required this.signInProvider,
    required this.onPasswordChange,
    required this.onPasswordSet,
    required this.showSnackBar,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obsCurrent = true;
  bool _obsNew = true;
  bool _obsConfirm = true;

  bool _hasMinLength = false;
  bool _hasMaxLength = true;
  bool _hasUppercase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _newController.addListener(_validatePasswordLive);
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _validatePasswordLive() {
    final password = _newController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasMaxLength = password.length <= 50;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Minimum 8 characters required';
    }
    if (value.length > 50) {
      return 'Maximum 50 characters allowed';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Must contain at least 1 uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Must contain at least 1 digit';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Must contain at least 1 special character';
    }
    return null;
  }

  Widget _buildValidationIndicator(String label, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isValid ? Colors.green : Colors.red.shade300,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isValid ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hasPassword ? "Change Password" : "Set Password"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.hasPassword) ...[
                TextFormField(
                  controller: _currentController,
                  obscureText: _obsCurrent,
                  decoration: InputDecoration(
                    labelText: "Current Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obsCurrent ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obsCurrent = !_obsCurrent),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _newController,
                obscureText: _obsNew,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: "New Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obsNew ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obsNew = !_obsNew),
                  ),
                ),
                validator: (value) {
                  final baseValidation = _validatePassword(value);
                  if (baseValidation != null) return baseValidation;

                  if (widget.hasPassword && value == _currentController.text) {
                    return 'New password must be different from current password';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 8),

              const Text(
                "Password must contain:",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5A6175),
                ),
              ),
              const SizedBox(height: 6),

              _buildValidationIndicator(
                "8-50 characters",
                _hasMinLength && _hasMaxLength,
              ),
              _buildValidationIndicator(
                "At least 1 uppercase letter (A-Z)",
                _hasUppercase,
              ),
              _buildValidationIndicator("At least 1 digit (0-9)", _hasDigit),
              _buildValidationIndicator(
                "At least 1 special character (!@#\$%^&*)",
                _hasSpecialChar,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmController,
                obscureText: _obsConfirm,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obsConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obsConfirm = !_obsConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (v != _newController.text) return "Passwords do not match";
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              if (widget.hasPassword) {
                widget.onPasswordChange(
                  _currentController.text,
                  _newController.text,
                );
              } else {
                widget.onPasswordSet(_newController.text);
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2962FF),
          ),
          child: const Text("SAVE", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}