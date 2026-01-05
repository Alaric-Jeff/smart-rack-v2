import 'package:flutter/material.dart';

class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  // --- STATE VARIABLES ---
  bool _isRodExtended = false;      // Blue
  bool _isDryingSystemOn = false;   // Orange (Merged Fan + Heater)
  
  // Power Consumption
  int _powerConsumption = 2; // Starts at 2 Watts (Idle)

  // Selected Options
  String _selectedFanTimer = "5m";
  String _selectedFanMode = "Auto";

  // --- HARDWARE LOGIC ---
  void _calculatePower() {
    int newPower = 2; // Base/Idle power

    if (_isRodExtended) newPower += 5;       // Motor torque
    if (_isDryingSystemOn) newPower += 1200; // Heater + Fan

    setState(() {
      _powerConsumption = newPower;
    });
  }

  Future<void> _sendToESP32(String component, dynamic value) async {
    // TODO: Add HTTP request logic here
    debugPrint("Sending to ESP32 -> Component: $component | Value: $value");
  }

  // --- CONFIRMATION MODAL ---
  void _showConfirmation(String title, String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text("Are you sure you want to $action?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2962FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
              // --- Header ---
              const Text(
                "Manual Controls",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2339)),
              ),
              const SizedBox(height: 4),
              const Text(
                "Override automatic settings",
                style: TextStyle(fontSize: 14, color: Color(0xFF5A6175), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              // --- 1. Main Controls ---
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, 
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  // BUTTON 1: Rod Control
                  _buildToggleCard(
                    title: _isRodExtended ? "Retract Rod" : "Extend Rod",
                    isOn: _isRodExtended,
                    icon: Icons.height,
                    activeColor: const Color(0xFF2962FF), // Blue
                    isDisabled: _isDryingSystemOn, // Disabled when Heater/Fan is ON
                    onTap: () {
                      if (_isDryingSystemOn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("⚠️ Safety Lock: Turn OFF the Drying System before moving the rod."),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      _showConfirmation(
                        "Rod Control", 
                        _isRodExtended ? "retract the rod" : "extend the rod", 
                        () {
                          setState(() {
                            _isRodExtended = !_isRodExtended;
                            _calculatePower(); 
                          });
                          _sendToESP32("rod", _isRodExtended ? "EXTEND" : "RETRACT");
                        }
                      );
                    },
                  ),
                  
                  // BUTTON 2: Drying System (Fan/Heater)
                  _buildToggleCard(
                    title: "Drying System",
                    isOn: _isDryingSystemOn,
                    icon: Icons.wb_sunny,
                    activeColor: const Color(0xFFFF6D00), // Orange
                    isDisabled: _isRodExtended, // Disabled if Rod is Extended
                    onTap: () {
                      if (_isRodExtended) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("⚠️ Safety Lock: Retract the rod first to use the Drying System."),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      _showConfirmation(
                        "Drying System", 
                        _isDryingSystemOn ? "turn OFF the heater & fan" : "turn ON the heater & fan", 
                        () {
                          setState(() {
                            _isDryingSystemOn = !_isDryingSystemOn;
                            _calculatePower(); 
                          });
                          _sendToESP32("drying_system", _isDryingSystemOn ? "ON" : "OFF");
                        }
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- LOGIC CHANGE HERE ---
              // These options are now locked UNLESS the drying system is ON.
              Opacity(
                // If Drying System is OFF, opacity is 0.5 (faded). If ON, it's 1.0 (clear).
                opacity: _isDryingSystemOn ? 1.0 : 0.5, 
                child: AbsorbPointer(
                  // If Drying System is OFF (!true), absorbing is true (blocking clicks).
                  absorbing: !_isDryingSystemOn, 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- 2. Fan Timer Selection ---
                      const Text("Timer", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildOptionButton("5m", _selectedFanTimer, (val) => setState(() { _selectedFanTimer = val; _sendToESP32("fan_timer", 5); })),
                          _buildOptionButton("10m", _selectedFanTimer, (val) => setState(() { _selectedFanTimer = val; _sendToESP32("fan_timer", 10); })),
                          _buildOptionButton("15m", _selectedFanTimer, (val) => setState(() { _selectedFanTimer = val; _sendToESP32("fan_timer", 15); })),
                          _buildOptionButton("30m", _selectedFanTimer, (val) => setState(() { _selectedFanTimer = val; _sendToESP32("fan_timer", 30); })),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- 3. Fan Mode Selection ---
                      const Text("Modes", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildOptionButton("Auto", _selectedFanMode, (val) => setState(() { _selectedFanMode = val; _sendToESP32("fan_mode", "AUTO"); })),
                          _buildOptionButton("Low", _selectedFanMode, (val) => setState(() { _selectedFanMode = val; _sendToESP32("fan_mode", "LOW"); })),
                          _buildOptionButton("Medium", _selectedFanMode, (val) => setState(() { _selectedFanMode = val; _sendToESP32("fan_mode", "MEDIUM"); })),
                          _buildOptionButton("High", _selectedFanMode, (val) => setState(() { _selectedFanMode = val; _sendToESP32("fan_mode", "HIGH"); })),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- 4. System Status Card ---
              const Text("System Status", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Mode", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          _isRodExtended 
                              ? "Rod Extended (Drying Locked)" 
                              : (_isDryingSystemOn ? "Drying Active (Rod Locked)" : "Standby"), 
                          style: TextStyle(
                            color: (_isRodExtended || _isDryingSystemOn) ? Colors.orange : const Color(0xFF2962FF), 
                            fontWeight: FontWeight.bold, 
                            fontSize: 13
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Power Consumption", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text("$_powerConsumption W", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
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

  // --- HELPER: Toggle Cards ---
  Widget _buildToggleCard({
    required String title,
    required bool isOn,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
    bool isDisabled = false, 
  }) {
    final Color bgColor = isDisabled ? Colors.grey.shade300 : (isOn ? activeColor : Colors.white);
    final Color iconBgColor = isDisabled ? Colors.grey.shade400 : (isOn ? Colors.white.withOpacity(0.2) : const Color(0xFFF5F6FA));
    final Color contentColor = isDisabled ? Colors.grey.shade500 : (isOn ? Colors.white : const Color(0xFF1E2339));
    final Color subTextColor = isDisabled ? Colors.grey.shade500 : (isOn ? Colors.white.withOpacity(0.7) : Colors.grey);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor, 
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
             if(isOn && !isDisabled) BoxShadow(color: activeColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: contentColor, size: 24),
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isDisabled ? "LOCKED" : (isOn ? "ON" : "OFF"), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor)),
                const SizedBox(height: 4),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: contentColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER: Options ---
  Widget _buildOptionButton(String text, String selectedValue, Function(String) onTap) {
    bool isSelected = text == selectedValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(text),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? const Color(0xFF2962FF) : Colors.grey.shade200, width: 1.5),
          ),
          child: Center(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFF1E2339) : Colors.grey))),
        ),
      ),
    );
  }
}