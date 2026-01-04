import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _displayNameController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _addressController;

  String? _photoUrl;
  File? _selectedImage;
  bool _isUploadingPhoto = false;
  
  // Track if user has a password (for SSO users)
  bool _hasPassword = false;
  String? _signInProvider;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _contactNumberController = TextEditingController();
    _addressController = TextEditingController();
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

  // Fetch user data from Firestore
  Future<void> _fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated', Colors.red);
        Navigator.pop(context);
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        _showSnackBar('User data not found', Colors.red);
        return;
      }

      final data = userDoc.data()!;
      
      if (mounted) {
        setState(() {
          _displayNameController.text = data['displayName'] ?? '';
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _contactNumberController.text = data['contactNumber'] ?? '';
          _addressController.text = data['address'] ?? '';
          _photoUrl = data['photoUrl'];
          _signInProvider = data['signInProvider'];
          
          // Check if user has password in Firestore
          // Password exists if the field is not null AND not empty string
          final passwordField = data['password'];
          _hasPassword = passwordField != null && 
                        passwordField is String && 
                        passwordField.isNotEmpty;
          
          _isLoading = false;
        });
      }
      
      debugPrint('=== USER PASSWORD STATUS ===');
      debugPrint('Has password in Firestore: $_hasPassword');
      debugPrint('Sign-in provider: $_signInProvider');
      debugPrint('Password field value: ${data['password'] == null ? "null" : (data['password'] as String).isEmpty ? "empty string" : "exists"}');
      debugPrint('===========================');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading profile: ${e.toString()}', Colors.red);
      }
    }
  }

  // Upload photo to Firebase Storage
  Future<String?> _uploadPhotoToStorage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Check if file exists and is readable
      if (!await imageFile.exists()) {
        debugPrint('Image file does not exist');
        return null;
      }

      final String fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage.ref().child('profile_photos/$fileName');

      // Set metadata for the upload
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=3600',
      );

      // Start upload with metadata
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
      
      // Monitor upload state
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        debugPrint('Upload progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%');
      });

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Check if upload was successful
      if (snapshot.state == TaskState.success) {
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        return downloadUrl;
      } else if (snapshot.state == TaskState.canceled) {
        debugPrint('Upload was canceled');
        return null;
      } else {
        debugPrint('Upload in unexpected state: ${snapshot.state}');
        return null;
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: ${e.code} - ${e.message}');
      String errorMessage = 'Upload failed';
      
      switch (e.code) {
        case 'object-not-found':
          errorMessage = 'Storage location not found. Please check your Firebase configuration.';
          break;
        case 'unauthorized':
          errorMessage = 'Permission denied. Please check Firebase Storage rules.';
          break;
        case 'canceled':
          errorMessage = 'Upload was canceled';
          break;
        case 'unknown':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = e.message ?? 'Upload failed';
      }
      
      if (mounted) {
        _showSnackBar(errorMessage, Colors.red);
      }
      return null;
    } catch (e) {
      debugPrint('Photo upload error: $e');
      if (mounted) {
        _showSnackBar('Failed to upload photo: ${e.toString()}', Colors.red);
      }
      return null;
    }
  }

  // Pick and upload photo
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _selectedImage = File(pickedFile.path);
        _isUploadingPhoto = true;
      });

      final String? downloadUrl = await _uploadPhotoToStorage(_selectedImage!);

      if (downloadUrl != null) {
        // Update Firestore with new photo URL
        final user = _auth.currentUser;
        await _firestore.collection('users').doc(user!.uid).update({
          'photoUrl': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _photoUrl = downloadUrl;
            _isUploadingPhoto = false;
          });
          _showSnackBar('Profile photo updated!', Colors.green);
        }
      } else {
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
          _showSnackBar('Failed to upload photo', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 250,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Change Profile Photo",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2339),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text(
                "Take a photo",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library, color: Colors.purple),
              ),
              title: const Text(
                "Choose from gallery",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Save changes to Firestore
  void _onSavePressed() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "Save Changes?",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2339),
            ),
          ),
          content: const Text(
            "Are you sure you want to update your profile information?",
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
      _showSnackBar(
        "Please fix the errors in red before saving.",
        Colors.red,
      );
    }
  }

  Future<void> _performSave() async {
    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated', Colors.red);
        return;
      }

      // Prepare update fields (only include changed fields)
      final Map<String, dynamic> updates = {};

      if (_displayNameController.text.trim().isNotEmpty) {
        updates['displayName'] = _displayNameController.text.trim();
      }
      if (_firstNameController.text.trim().isNotEmpty) {
        updates['firstName'] = _firstNameController.text.trim();
      }
      if (_lastNameController.text.trim().isNotEmpty) {
        updates['lastName'] = _lastNameController.text.trim();
      }
      if (_contactNumberController.text.trim().isNotEmpty) {
        // Normalize contact number
        String normalized = _contactNumberController.text.replaceAll(RegExp(r'[\s-]'), '');
        updates['contactNumber'] = normalized;
      }
      if (_addressController.text.trim().isNotEmpty) {
        updates['address'] = _addressController.text.trim();
      }

      if (updates.isEmpty) {
        _showSnackBar('No changes to save', Colors.orange);
        setState(() => _isSaving = false);
        return;
      }

      updates['updatedAt'] = FieldValue.serverTimestamp();

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

  // Change or Set password (for SSO users)
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

  // Change existing password
  Future<void> _performPasswordChange(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        _showSnackBar('User not authenticated', Colors.red);
        return;
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password in Firebase Auth
      await user.updatePassword(newPassword);
      
      // Update password in Firestore (store hashed in production!)
      await _firestore.collection('users').doc(user.uid).update({
        'password': newPassword, // NOTE: In production, hash this!
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _hasPassword = true);
      }
      
      if (mounted) {
        _showSnackBar('Password changed successfully!', Colors.green);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to change password';

      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Current password is incorrect';
          break;
        case 'weak-password':
          errorMessage = 'New password is too weak';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log out and log in again';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }

      _showSnackBar(errorMessage, Colors.red);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  // Set password for SSO users
  Future<void> _performSetPassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated', Colors.red);
        return;
      }

      // Update password in Firebase Auth
      await user.updatePassword(newPassword);
      
      // Update password in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'password': newPassword, // NOTE: In production, hash this!
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _hasPassword = true);
      }
      
      if (mounted) {
        _showSnackBar('Password set successfully! You can now login with email.', Colors.green);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to set password';

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Password is too weak';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log out and log in again to set password';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }

      _showSnackBar(errorMessage, Colors.red);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Delete Account?",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "This action cannot be undone. All your data and settings will be permanently removed.",
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performAccountDeletion();
            },
            child: const Text(
              "DELETE",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Delete user document from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete user account from Firebase Auth
      await user.delete();

      if (mounted) {
        _showSnackBar('Account deleted', Colors.green);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnackBar(
          'Please log out and log in again to delete account',
          Colors.red,
        );
      } else {
        _showSnackBar('Error: ${e.message}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FB),
        body: Center(
          child: CircularProgressIndicator(),
        ),
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
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
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

                // Profile Photo
                Center(
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blue.shade100,
                              backgroundImage: _photoUrl != null
                                  ? NetworkImage(_photoUrl!)
                                  : null,
                              child: _photoUrl == null
                                  ? const Icon(Icons.person, size: 50, color: Colors.blue)
                                  : null,
                            ),
                            if (_isUploadingPhoto)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(30),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(30),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isUploadingPhoto
                              ? "Uploading..."
                              : "Click to upload new photo",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                const Text(
                  "Personal Information",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Display Name
                _buildTextField(
                  "DISPLAY NAME",
                  _displayNameController,
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Required";
                    if (val.length < 3 || val.length > 25) {
                      return "3-25 characters";
                    }
                    if (!RegExp(r'^[A-Za-z0-9 ._-]+$').hasMatch(val)) {
                      return "Invalid characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // First and Last Name
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "FIRST NAME",
                        _firstNameController,
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Required";
                          if (val.length < 3 || val.length > 27) {
                            return "3-27 chars";
                          }
                          if (!RegExp(r'^[A-Za-z]+$').hasMatch(val)) {
                            return "Letters only";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        "LAST NAME",
                        _lastNameController,
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Required";
                          if (val.length < 3 || val.length > 27) {
                            return "3-27 chars";
                          }
                          if (!RegExp(r'^[A-Za-z]+$').hasMatch(val)) {
                            return "Letters only";
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Contact Number
                _buildTextField(
                  "PHONE NUMBER",
                  _contactNumberController,
                  type: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.isEmpty) return null;
                    String normalized = val.replaceAll(RegExp(r'[\s-]'), '');
                    if (!RegExp(r'^\+639\d{9}$').hasMatch(normalized)) {
                      return "Use format: +639XXXXXXXXX";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Address
                const Text(
                  "Address",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  "Street Address",
                  _addressController,
                  validator: (val) {
                    if (val != null && val.length > 120) {
                      return "Max 120 characters";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                // Security Section
                const Text(
                  "Security",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: Icon(
                      _hasPassword ? Icons.lock_outline : Icons.lock_open_outlined,
                      size: 20,
                      color: const Color(0xFF1E2339),
                    ),
                    label: Text(
                      _hasPassword ? "CHANGE PASSWORD" : "SET PASSWORD",
                      style: const TextStyle(
                        color: Color(0xFF1E2339),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _onSavePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                      shadowColor: const Color(0xFF2962FF).withOpacity(0.4),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "SAVE CHANGES",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Delete Account
                Center(
                  child: TextButton(
                    onPressed: _deleteAccount,
                    child: const Text(
                      "Delete Account",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
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
    TextInputType? type,
    String? Function(String?)? validator,
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
          keyboardType: type,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          decoration: InputDecoration(
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
        ),
      ],
    );
  }
}

// Password Dialog Widget
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
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    if (mounted) {
      Navigator.pop(context);
    }

    if (widget.hasPassword) {
      await widget.onPasswordChange(currentPassword, newPassword);
    } else {
      await widget.onPasswordSet(newPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.hasPassword ? "Change Password" : "Set Password",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show info message for users without password
              if (!widget.hasPassword)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.signInProvider == 'manual'
                              ? "Set a password to secure your account."
                              : "You signed up with ${widget.signInProvider == 'google.com' ? 'Google' : widget.signInProvider == 'facebook.com' ? 'Facebook' : 'SSO'}. Set a password to enable email/password login.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!widget.hasPassword) const SizedBox(height: 16),
              
              // Current password (only for users who have password)
              if (widget.hasPassword) ...[
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Current password is required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "Current Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _obscureCurrent = !_obscureCurrent);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // New password
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length < 8 || value.length > 50) {
                    return 'Password must be 8-50 characters';
                  }
                  if (!RegExp(r'^(?=.*[0-9])(?=.*[!@#$%^&*])[A-Za-z0-9!@#$%^&*]+$')
                      .hasMatch(value)) {
                    return 'Must contain a number and special character';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: widget.hasPassword ? "New Password" : "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() => _obscureNew = !_obscureNew);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Confirm password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            
            // Password requirements
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Password must:",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text("• Be 8-50 characters long", style: TextStyle(fontSize: 10)),
                  Text("• Contain at least one number", style: TextStyle(fontSize: 10)),
                  Text("• Contain at least one special character (!@#\$%^&*)", style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        ),
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
          onPressed: _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2962FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            widget.hasPassword ? "UPDATE" : "SET PASSWORD",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}