import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui'; // For the blur effect

class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  // --- STATE VARIABLES ---
  bool _isRodExtended = false;
  bool _isDryingSystemOn = false; // "Main Power" switch
  int _powerConsumption = 2; 

  // --- TIMER VARIABLES ---
  Timer? _dryingTimer;
  int _remainingSeconds = 0;
  String? _selectedFanTimer; // Null = No timer selected
  String? _selectedFanMode;

  @override
  void dispose() {
    _dryingTimer?.cancel();
    super.dispose();
  }

  // --- HARDWARE MOCKUP (DYNAMIC POWER) ---
  void _calculatePower() {
    int newPower = 2; // Base Idle (WiFi/Standby)

    // 1. Rod Motor (consumes power if extended/holding)
    if (_isRodExtended) newPower += 5; 
    
    // 2. Drying System Logic
    if (_isDryingSystemOn) {
      // If a timer is running (Active Drying)
      if (_selectedFanTimer != null) {
        int heaterPower = 1000; // Base Heater
        int fanPower = 0;

        // Different power for different modes
        switch (_selectedFanMode) {
          case "Low":    fanPower = 100; break;
          case "Med":    fanPower = 250; break;
          case "High":   fanPower = 450; break;
          case "Auto":   fanPower = 300; break;
          default:       fanPower = 300; // Default if null
        }
        newPower += (heaterPower + fanPower);
        
      } else {
        // If just ON but not drying (Ready State)
        newPower += 10; // Display + Sensors
      }
    }
    
    setState(() => _powerConsumption = newPower);
  }

  Future<void> _sendToESP32(String component, dynamic value) async {
    debugPrint("Sending to ESP32 -> Component: $component | Value: $value");
  }

  // --- TOGGLE DRYING POWER ---
  void _toggleDryingPower() {
    setState(() {
      _isDryingSystemOn = !_isDryingSystemOn;
      
      if (!_isDryingSystemOn) {
        _stopTimer(); // Kill everything if turned off
      } else {
        _selectedFanMode = "Auto"; // Default to Auto when turned on
        _calculatePower(); // Calculate "Ready" power
      }
    });
    
    _sendToESP32("drying_system", _isDryingSystemOn ? "READY" : "OFF");
  }

  // --- HANDLE TIMER PRESS/UNPRESS ---
  void _handleTimerSelection(String duration) {
    // Unpress Logic (Stop)
    if (_selectedFanTimer == duration) {
      _showConfirmation("Stop Timer", "cancel the current timer", () {
          _stopTimer();
      });
      return; 
    }

    // Start/Change Logic
    int minutes = int.parse(duration.replaceAll('m', ''));
    int totalSeconds = minutes * 60;

    setState(() {
      _selectedFanTimer = duration; 
      _remainingSeconds = totalSeconds;
      _calculatePower(); // Update power immediately!
    });

    _dryingTimer?.cancel();
    _dryingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _stopTimer();
      }
    });

    _sendToESP32("fan_timer", minutes);
  }

  // --- NEW: HANDLE FAN MODE CHANGES ---
  void _handleFanModeSelection(String mode) {
    setState(() {
      _selectedFanMode = mode;
      _calculatePower(); // Update power immediately when mode changes!
    });
    _sendToESP32("fan_mode", mode.toUpperCase());
  }

  void _stopTimer() {
    _dryingTimer?.cancel();
    setState(() {
      _selectedFanTimer = null; 
      _remainingSeconds = 0;
      _calculatePower(); // Drop power back to "Ready" or "Idle"
    });
    _sendToESP32("drying_status", "STOPPED");
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  // --- CONFIRMATION ---
  void _showConfirmation(String title, String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
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
    bool isRunning = _isDryingSystemOn && _selectedFanTimer != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Manual Controls", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const SizedBox(height: 4),
              const Text("Override automatic settings", style: TextStyle(fontSize: 14, color: Color(0xFF5A6175), fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),

              // 1. MAIN TOGGLES
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, 
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  // ROD CONTROL
                  _buildToggleCard(
                    title: _isRodExtended ? "Retract Rod" : "Extend Rod",
                    isOn: _isRodExtended,
                    icon: Icons.height,
                    activeColor: const Color(0xFF2962FF), 
                    isDisabled: _isDryingSystemOn, 
                    onTap: () {
                      if (_isDryingSystemOn) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Turn OFF Drying System first!"), backgroundColor: Colors.red));
                        return;
                      }
                      _showConfirmation("Rod Control", _isRodExtended ? "retract rod" : "extend rod", () {
                        setState(() { _isRodExtended = !_isRodExtended; _calculatePower(); });
                        _sendToESP32("rod", _isRodExtended ? "EXTEND" : "RETRACT");
                      });
                    },
                  ),
                  
                  // DRYING SYSTEM (MASTER POWER)
                  _buildToggleCard(
                    title: "Drying System",
                    isOn: _isDryingSystemOn,
                    icon: Icons.wb_sunny,
                    activeColor: const Color(0xFFFF6D00), 
                    isDisabled: _isRodExtended,
                    onTap: () {
                      if (_isRodExtended) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Retract rod first!"), backgroundColor: Colors.red));
                        return;
                      }
                      _showConfirmation("Drying System", _isDryingSystemOn ? "Turn OFF System" : "Turn ON System (Ready Mode)", () {
                        _toggleDryingPower();
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 2. SETTINGS (Locked if System OFF)
              Opacity(
                opacity: _isDryingSystemOn ? 1.0 : 0.4, 
                child: AbsorbPointer(
                  absorbing: !_isDryingSystemOn, 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Set Duration", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      const SizedBox(height: 12),
                      Row(children: [
                        _buildOptionButton("5m", _selectedFanTimer, (val) => _handleTimerSelection(val)),
                        _buildOptionButton("10m", _selectedFanTimer, (val) => _handleTimerSelection(val)),
                        _buildOptionButton("15m", _selectedFanTimer, (val) => _handleTimerSelection(val)),
                        _buildOptionButton("30m", _selectedFanTimer, (val) => _handleTimerSelection(val)),
                      ]),
                      const SizedBox(height: 24),
                      const Text("Fan Mode", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      const SizedBox(height: 12),
                      Row(children: [
                        _buildOptionButton("Auto", _selectedFanMode, (val) => _handleFanModeSelection("Auto")),
                        _buildOptionButton("Low", _selectedFanMode, (val) => _handleFanModeSelection("Low")),
                        _buildOptionButton("Med", _selectedFanMode, (val) => _handleFanModeSelection("Med")),
                        _buildOptionButton("High", _selectedFanMode, (val) => _handleFanModeSelection("High")),
                      ]),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 3. SYSTEM STATUS
              const Text("System Status", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const SizedBox(height: 12),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    // DIGITAL DISPLAY
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2339),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF1E2339).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5)),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isRunning ? "TIME REMAINING" : (_isDryingSystemOn ? "SELECT TIMER TO START" : "SYSTEM OFF"),
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 4),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFE0E0E0)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds),
                            child: Text(
                              isRunning ? _formatTime(_remainingSeconds) : "--:--",
                              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace', letterSpacing: 2.0, height: 1.0),
                            ),
                          ),
                          if (isRunning) ...[
                             const SizedBox(height: 12),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                               decoration: BoxDecoration(
                                 color: Colors.green.withOpacity(0.2),
                                 borderRadius: BorderRadius.circular(20),
                                 border: Border.all(color: Colors.green.withOpacity(0.5), width: 1),
                               ),
                               child: const Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Icon(Icons.circle, size: 8, color: Colors.green),
                                   SizedBox(width: 6),
                                   Text("RUNNING", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))
                                 ],
                               ),
                             )
                          ]
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Status Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Activity", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          isRunning ? "DRYING" : (_isDryingSystemOn ? "READY" : (_isRodExtended ? "EXTENDED" : "IDLE")), 
                          style: TextStyle(
                            color: isRunning ? const Color(0xFFFF6D00) : (_isRodExtended ? const Color(0xFF2962FF) : Colors.grey), 
                            fontWeight: FontWeight.bold, fontSize: 13
                          )
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Power Consumption", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        // ANIMATED POWER TEXT (Optional Visual Touch)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            "$_powerConsumption W", 
                            key: ValueKey<int>(_powerConsumption),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                        ),
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
  Widget _buildToggleCard({required String title, required bool isOn, required IconData icon, required Color activeColor, required VoidCallback onTap, bool isDisabled = false}) {
    final Color bgColor = isDisabled ? Colors.grey.shade200 : (isOn ? activeColor : Colors.white);
    final Color iconBgColor = isDisabled ? Colors.transparent : (isOn ? Colors.white.withOpacity(0.2) : const Color(0xFFF5F6FA));
    final Color contentColor = isDisabled ? Colors.grey.shade400 : (isOn ? Colors.white : const Color(0xFF1E2339));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor, 
          borderRadius: BorderRadius.circular(24),
          boxShadow: [if(isOn && !isDisabled) BoxShadow(color: activeColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          border: isDisabled ? Border.all(color: Colors.grey.shade300) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle), child: Icon(icon, color: contentColor, size: 24)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isDisabled ? "LOCKED" : (isOn ? "ON" : "OFF"), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDisabled ? Colors.grey.shade400 : (isOn ? Colors.white.withOpacity(0.7) : Colors.grey))),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: contentColor)),
            ]),
          ],
        ),
      ),
    );
  }

  // --- HELPER: Options ---
  Widget _buildOptionButton(String text, String? selectedValue, Function(String) onTap) {
    bool isSelected = selectedValue != null && text == selectedValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(text),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2962FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? const Color(0xFF2962FF) : Colors.grey.shade200, width: 1.5),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF2962FF).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : [],
          ),
          child: Center(
            child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF1E2339))),
          ),
        ),
      ),
    );
  }
}