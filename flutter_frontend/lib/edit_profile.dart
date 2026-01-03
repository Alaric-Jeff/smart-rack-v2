import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // --- FORM KEY ---
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    // TODO: BACKEND - Fetch these values from your database (e.g., Firebase)
    _firstNameController = TextEditingController(text: "Kirby");
    _lastNameController = TextEditingController(text: "Gabayno");
    _emailController = TextEditingController(text: "kirbygabayno16@email.com");
    _phoneController = TextEditingController(text: "+63 917-123-4567");
    _addressController = TextEditingController(text: "123 Main Street");
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // --- LOGIC: SAVE CONFIRMATION ---
  void _onSavePressed() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Save Changes?", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
          content: const Text("Are you sure you want to update your profile information?"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
              child: const Text("CONFIRM", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fix the errors in red before saving."), backgroundColor: Colors.red),
      );
    }
  }

  // --- LOGIC: ACTUAL SAVE ---
  Future<void> _performSave() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Prepare Data for Database
    final Map<String, dynamic> updates = {
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "email": _emailController.text.trim(),
      "phone": _phoneController.text.trim(),
      "address": _addressController.text.trim(),
      "updated_at": DateTime.now().toIso8601String(),
    };

    debugPrint("Sending to Database: $updates");

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
    );
    Navigator.pop(context); 
  }

  void _uploadPhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 250,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("Change Profile Photo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.blue)),
              title: const Text("Take a photo", style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); debugPrint("Camera Selected"); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle), child: const Icon(Icons.photo_library, color: Colors.purple)),
              title: const Text("Choose from gallery", style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); debugPrint("Gallery Selected"); },
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIC: CHANGE PASSWORD (UPDATED) ---
  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) {
        // State variable ONLY for New Password
        bool obscureNew = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current Password (ALWAYS HIDDEN - No Icon)
                  TextField(
                    obscureText: true, // Always true
                    decoration: InputDecoration(
                      labelText: "Current Password",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      // suffixIcon removed
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // New Password (HAS TOGGLE)
                  TextField(
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () { 
                    Navigator.pop(context); 
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password changed!")));
                  }, 
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text("UPDATE", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("This action cannot be undone. All your data and settings will be permanently removed."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); }, 
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    const SizedBox(width: 12),
                    const Text("Back", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                const Text("Manage Account", style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 30),

                Center(
                  child: GestureDetector(
                    onTap: _uploadPhoto,
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(radius: 50, backgroundColor: Colors.blue.shade100, backgroundImage: const AssetImage('assets/user_placeholder.png')),
                            Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle), padding: const EdgeInsets.all(30), child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 30)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text("Click to upload new photo", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                const Text("Personal Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildTextField("FIRST NAME", _firstNameController, validator: (val) => val!.isEmpty ? "Required" : null)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField("LAST NAME", _lastNameController, validator: (val) => val!.isEmpty ? "Required" : null)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField("EMAIL", _emailController, type: TextInputType.emailAddress, validator: (val) => !val!.contains("@") ? "Invalid Email" : null),
                const SizedBox(height: 16),
                _buildTextField("PHONE NUMBER", _phoneController, type: TextInputType.phone),
                const SizedBox(height: 16),
                const Text("Address", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildTextField("Street Address", _addressController),

                const SizedBox(height: 30),

                const Text("Security", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF1E2339)),
                    label: const Text("CHANGE PASSWORD", style: TextStyle(color: Color(0xFF1E2339), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Colors.white),
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _onSavePressed,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5, shadowColor: const Color(0xFF2962FF).withOpacity(0.4)),
                    child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                
                const SizedBox(height: 20),

                Center(child: TextButton(onPressed: _deleteAccount, child: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? type, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5A6175))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: type,
          validator: validator,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
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