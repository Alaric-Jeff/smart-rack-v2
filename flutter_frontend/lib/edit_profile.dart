import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for input formatters
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _hasPassword = false;
  String? _signInProvider;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _contactNumberController = TextEditingController();
    _addressController = TextEditingController();

    // LIVE UPDATE LISTENERS (For Avatar)
    _displayNameController.addListener(() { if (mounted) setState(() {}); });
    _firstNameController.addListener(() { if (mounted) setState(() {}); });
    _lastNameController.addListener(() { if (mounted) setState(() {}); });

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

  // --- UPDATED AVATAR INITIALS HELPER ---
  // Priority: Display Name -> First/Last Name -> "U"
  String _getInitials() {
    // 1. Try Display Name first
    String display = _displayNameController.text.trim();
    if (display.isNotEmpty) {
      List<String> parts = display.split(RegExp(r'\s+'));
      String first = parts[0][0];
      String last = parts.length > 1 ? parts[1][0] : "";
      // If display name is just one word (e.g. "Kirby"), return "K"
      // If "Kirby Gabayno", return "KG"
      return (first + last).toUpperCase();
    }

    // 2. Fallback to First + Last Name
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
          
          // SMART PHONE NUMBER PARSING
          String rawPhone = data['contactNumber'] ?? '';
          if (rawPhone.startsWith('+63')) {
             _contactNumberController.text = rawPhone.substring(3);
          } else if (rawPhone.startsWith('09')) {
             _contactNumberController.text = rawPhone.substring(1); 
          } else {
             _contactNumberController.text = rawPhone;
          }

          _addressController.text = data['address'] ?? '';
          _photoUrl = data['photoUrl'];
          _signInProvider = data['signInProvider'];
          
          final passwordField = data['password'];
          _hasPassword = passwordField != null && passwordField is String && passwordField.isNotEmpty;
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
          title: const Text("Save Changes?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to update your profile?"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); _performSave(); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
              child: const Text("CONFIRM", style: TextStyle(color: Colors.white)),
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
      if (_displayNameController.text.trim().isNotEmpty) updates['displayName'] = _displayNameController.text.trim();
      if (_firstNameController.text.trim().isNotEmpty) updates['firstName'] = _firstNameController.text.trim();
      if (_lastNameController.text.trim().isNotEmpty) updates['lastName'] = _lastNameController.text.trim();
      
      // SAVE PHONE NUMBER WITH +63 PREFIX
      if (_contactNumberController.text.trim().isNotEmpty) {
        updates['contactNumber'] = "+63${_contactNumberController.text.trim()}";
      }
      
      if (_addressController.text.trim().isNotEmpty) updates['address'] = _addressController.text.trim();

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

  // --- PASSWORD LOGIC ---
  void _changePassword() {
    showDialog(context: context, builder: (context) => _PasswordDialog(
        hasPassword: _hasPassword,
        signInProvider: _signInProvider,
        onPasswordChange: _performPasswordChange,
        onPasswordSet: _performSetPassword,
        showSnackBar: _showSnackBar,
      ));
  }

  Future<void> _performPasswordChange(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      await _firestore.collection('users').doc(user.uid).update({'password': newPassword});
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
      await _firestore.collection('users').doc(user.uid).update({'password': newPassword});
      if (mounted) setState(() => _hasPassword = true);
      _showSnackBar('Password set successfully!', Colors.green);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Error', Colors.red);
    }
  }

  void _deleteAccount() {
    showDialog(context: context, builder: (context) => AlertDialog(
        title: const Text("Delete Account?", style: TextStyle(color: Colors.red)),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(onPressed: () async { Navigator.pop(context); await _performAccountDeletion(); }, child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ));
  }

  Future<void> _performAccountDeletion() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      if (mounted) {
        _showSnackBar('Account deleted', Colors.green);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showSnackBar('Error deleting account', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    const SizedBox(width: 12),
                    const Text("Back", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                const Text("Manage Account", style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 30),

                // --- AVATAR (Updated to prioritize Initials) ---
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2962FF),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFF2962FF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    alignment: Alignment.center,
                    // REMOVED logic that checks for _photoUrl. 
                    // Now strictly uses Initials from the text boxes.
                    child: Text(
                      _getInitials(), 
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                const Text("Personal Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // --- 1. DISPLAY NAME WITH REGEX ---
                _buildTextField(
                  "DISPLAY NAME", 
                  _displayNameController, 
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Required";
                    if (val.length < 3) return "Too short (min 3)";
                    if (val.length > 25) return "Too long (max 25)";
                    if (!RegExp(r'^[a-zA-Z0-9 ._]+$').hasMatch(val)) {
                      return "No special symbols allowed";
                    }
                    return null;
                  }
                ),
                const SizedBox(height: 16),

                // --- 2. FIRST & LAST NAME WITH REGEX ---
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "FIRST NAME", 
                        _firstNameController, 
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Required";
                          if (val.length < 2) return "Too short";
                          if (!RegExp(r'^[a-zA-Z .-]+$').hasMatch(val)) {
                            return "Letters only";
                          }
                          return null;
                        }
                      )
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        "LAST NAME", 
                        _lastNameController, 
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Required";
                          if (val.length < 2) return "Too short";
                          if (!RegExp(r'^[a-zA-Z .-]+$').hasMatch(val)) {
                            return "Letters only";
                          }
                          return null;
                        }
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- 3. PHONE NUMBER (UX OPTIMIZED) ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PHONE NUMBER", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5A6175))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          height: 55,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black87, width: 1.0),
                          ),
                          child: const Center(
                            child: Text("+63", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _contactNumberController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly, 
                              LengthLimitingTextInputFormatter(10),
                            ],
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                            decoration: InputDecoration(
                              counterText: "",
                              hintText: "9XX XXX XXXX",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2962FF), width: 2)),
                              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return null; 
                              if (!value.startsWith('9')) return "Must start with 9"; 
                              if (value.length != 10) return "Must be 10 digits";
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),

                // --- 4. ADDRESS (REQUIRED) ---
                const Text("Address", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildTextField(
                  "Street Address", 
                  _addressController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Address is required";
                    if (val.length > 150) return "Address too long";
                    return null;
                  },
                ),
                
                const SizedBox(height: 30),
                const Text("Security", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: Icon(_hasPassword ? Icons.lock_outline : Icons.lock_open_outlined, size: 20),
                    label: Text(_hasPassword ? "CHANGE PASSWORD" : "SET PASSWORD"),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _onSavePressed,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: TextButton(onPressed: _deleteAccount, child: const Text("Delete Account", style: TextStyle(color: Colors.red)))),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5A6175))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2962FF), width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
          ),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  final bool hasPassword;
  final String? signInProvider;
  final Future<void> Function(String, String) onPasswordChange;
  final Future<void> Function(String) onPasswordSet;
  final void Function(String, Color) showSnackBar;

  const _PasswordDialog({required this.hasPassword, required this.signInProvider, required this.onPasswordChange, required this.onPasswordSet, required this.showSnackBar});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obsCurrent = true; bool _obsNew = true; bool _obsConfirm = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hasPassword ? "Change Password" : "Set Password"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.hasPassword) ...[
                TextFormField(controller: _currentController, obscureText: _obsCurrent, decoration: InputDecoration(labelText: "Current Password", suffixIcon: IconButton(icon: Icon(_obsCurrent ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obsCurrent = !_obsCurrent))), validator: (v) => v!.isEmpty ? "Required" : null),
                const SizedBox(height: 10),
              ],
              TextFormField(controller: _newController, obscureText: _obsNew, decoration: InputDecoration(labelText: "New Password", suffixIcon: IconButton(icon: Icon(_obsNew ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obsNew = !_obsNew))), validator: (v) => v!.length < 8 ? "Min 8 chars" : null),
              const SizedBox(height: 10),
              TextFormField(controller: _confirmController, obscureText: _obsConfirm, decoration: InputDecoration(labelText: "Confirm Password", suffixIcon: IconButton(icon: Icon(_obsConfirm ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obsConfirm = !_obsConfirm))), validator: (v) => v != _newController.text ? "Mismatch" : null),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              if (widget.hasPassword) {
                widget.onPasswordChange(_currentController.text, _newController.text);
              } else {
                widget.onPasswordSet(_newController.text);
              }
            }
          },
          child: const Text("SAVE"),
        )
      ],
    );
  }
}