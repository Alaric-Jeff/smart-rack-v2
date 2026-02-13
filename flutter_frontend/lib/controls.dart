import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class ControlsScreen extends StatefulWidget {
  final String deviceId;

  const ControlsScreen({
    super.key,
    required this.deviceId,
  });

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  // --- STATE VARIABLES ---
  bool _isRodExtended = false;
  bool _isDryingSystemOn = false;
  int _powerConsumption = 2;
  bool _isCommandProcessing = false;
  bool _isLoadingState = true;

  // --- COOLDOWN VARIABLES ---
  Timer? _cooldownTimer;
  int _cooldownRemainingSeconds = 0;
  bool get _isCoolingDown => _cooldownRemainingSeconds > 0;

  // --- TIMER VARIABLES ---
  Timer? _dryingTimer;
  int _remainingSeconds = 0;
  String? _selectedFanTimer;
  String? _selectedFanMode;

  // --- REALTIME DATABASE LISTENER ---
  StreamSubscription<DatabaseEvent>? _deviceListener;

  @override
  void initState() {
    super.initState();
    _initializeActuatorState();
    _setupRealtimeDatabaseListener();
  }

  @override
  void dispose() {
    _dryingTimer?.cancel();
    _cooldownTimer?.cancel();
    _deviceListener?.cancel();
    super.dispose();
  }

  // --- LOAD INITIAL STATE (one-time read) ---
  Future<void> _initializeActuatorState() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('devices/${widget.deviceId}/actuator/state')
          .get();
      
      if (snapshot.exists && mounted) {
        final state = snapshot.value as String?;
        setState(() {
          _isRodExtended = state == 'extended';
          _isLoadingState = false;
          _calculatePower();
        });
      } else {
        if (mounted) {
          setState(() => _isLoadingState = false);
        }
      }
    } catch (e) {
      debugPrint('Initial state load: $e');
      if (mounted) {
        setState(() => _isLoadingState = false);
      }
    }
  }

  // --- REAL-TIME DATABASE LISTENER ---
  void _setupRealtimeDatabaseListener() {
    final databaseRef = FirebaseDatabase.instance
        .ref('devices/${widget.deviceId}/actuator');

    _deviceListener = databaseRef.onValue.listen(
      (DatabaseEvent event) {
        if (!event.snapshot.exists || !mounted) return;

        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return;

        final state = data['state'] as String?;

        // Only update UI on stable final states
        if (state == 'extended' || state == 'retracted') {
          final newExtended = state == 'extended';

          if (_isRodExtended != newExtended) {
            setState(() {
              _isRodExtended = newExtended;
              _isCommandProcessing = false;
              _calculatePower();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  newExtended
                      ? '✓ Rod fully extended'
                      : '✓ Rod fully retracted',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (state == 'moving_extend' || state == 'moving_retract') {
          if (!_isCommandProcessing && mounted) {
            setState(() => _isCommandProcessing = true);
          }
        }
      },
      onError: (error) {
        debugPrint('Realtime Database listener error: $error');
      },
    );
  }

  // --- START 60-SECOND UI COOLDOWN ---
  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownRemainingSeconds = 60);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemainingSeconds--;
        if (_cooldownRemainingSeconds <= 0) {
          _cooldownRemainingSeconds = 0;
          timer.cancel();
          if (_isCommandProcessing) {
            _isCommandProcessing = false;
          }
        }
      });
    });
  }

  // --- SEND ACTUATOR COMMAND ---
  Future<void> _handleActuatorControl(bool extend) async {
    if (_isCoolingDown || _isCommandProcessing) return;

    setState(() => _isCommandProcessing = true);

    try {
      await FirebaseDatabase.instance
          .ref('devices/${widget.deviceId}/actuator')
          .update({
        'target': extend ? 'extended' : 'retracted',
        'lastCommandAt': ServerValue.timestamp,
      });

      _startCooldown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              extend
                  ? 'Extending rod... (~60s)'
                  : 'Retracting rod... (~60s)',
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Actuator control error: $e');
      setState(() => _isCommandProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // --- POWER CALCULATION ---
  void _calculatePower() {
    int newPower = 2;
    if (_isRodExtended) newPower += 5;

    if (_isDryingSystemOn) {
      if (_selectedFanTimer != null) {
        int heaterPower = 1000;
        int fanPower = 0;
        switch (_selectedFanMode) {
          case 'Low':
            fanPower = 100;
            break;
          case 'Med':
            fanPower = 250;
            break;
          case 'High':
            fanPower = 450;
            break;
          default:
            fanPower = 300;
        }
        newPower += (heaterPower + fanPower);
      } else {
        newPower += 10;
      }
    }

    setState(() => _powerConsumption = newPower);
  }

  Future<void> _sendToESP32(String component, dynamic value) async {
    debugPrint('Sending to ESP32 -> Component: $component | Value: $value');
  }

  void _toggleDryingPower() {
    setState(() {
      _isDryingSystemOn = !_isDryingSystemOn;
      if (!_isDryingSystemOn) {
        _stopTimer();
      } else {
        _selectedFanMode = 'Auto';
        _calculatePower();
      }
    });
    _sendToESP32('drying_system', _isDryingSystemOn ? 'READY' : 'OFF');
  }

  void _handleTimerSelection(String duration) {
    if (_selectedFanTimer != null && _selectedFanTimer != duration) {
      _showConfirmation('Change Timer', 'change the timer to $duration', () {
        _startTimerSequence(duration);
      });
      return;
    }
    if (_selectedFanTimer == duration) {
      _showConfirmation('Stop Timer', 'cancel the current timer', _stopTimer);
      return;
    }
    _startTimerSequence(duration);
  }

  void _startTimerSequence(String duration) {
    int minutes = int.parse(duration.replaceAll('m', ''));
    int totalSeconds = minutes * 60;

    setState(() {
      _selectedFanTimer = duration;
      _remainingSeconds = totalSeconds;
      _calculatePower();
    });

    _dryingTimer?.cancel();
    _dryingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _stopTimer();
      }
    });

    _sendToESP32('fan_timer', minutes);
  }

  void _handleFanModeSelection(String mode) {
    setState(() {
      _selectedFanMode = mode;
      _calculatePower();
    });
    _sendToESP32('fan_mode', mode.toUpperCase());
  }

  void _stopTimer() {
    _dryingTimer?.cancel();
    setState(() {
      _selectedFanTimer = null;
      _remainingSeconds = 0;
      _calculatePower();
    });
    _sendToESP32('drying_status', 'STOPPED');
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showConfirmation(String title, String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
        content: Text('Are you sure you want to $action?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2962FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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

    final bool rodButtonLocked =
        _isDryingSystemOn || _isCoolingDown || _isCommandProcessing;

    if (_isLoadingState) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF2962FF)),
              SizedBox(height: 16),
              Text('Loading device state...',
                  style: TextStyle(color: Color(0xFF5A6175), fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manual Controls',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2339))),
                  SizedBox(height: 6),
                  Text('Override automatic settings',
                      style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF5A6175),
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 28),

              if (_isCoolingDown) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2962FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF2962FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2962FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isRodExtended
                              ? 'Rod extended — cooldown: ${_cooldownRemainingSeconds}s'
                              : 'Actuator moving — wait ${_cooldownRemainingSeconds}s',
                          style: const TextStyle(
                            color: Color(0xFF2962FF),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  _buildToggleCard(
                    title: 'Extend Rod',
                    activeTitle: 'Retract Rod',
                    isOn: _isRodExtended,
                    icon: Icons.height,
                    activeColor: const Color(0xFF2962FF),
                    isDisabled: rodButtonLocked,
                    isLoading: _isCommandProcessing,
                    cooldownSeconds: _isCoolingDown
                        ? _cooldownRemainingSeconds
                        : null,
                    onTap: () {
                      if (_isDryingSystemOn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Turn OFF Drying System first!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (_isCoolingDown) return;
                      _showConfirmation(
                        'Rod Control',
                        _isRodExtended ? 'retract rod' : 'extend rod',
                        () => _handleActuatorControl(!_isRodExtended),
                      );
                    },
                  ),

                  _buildToggleCard(
                    title: 'Drying System',
                    activeTitle: 'Drying System',
                    isOn: _isDryingSystemOn,
                    icon: Icons.wb_sunny_rounded,
                    activeColor: const Color(0xFFFF6D00),
                    isDisabled: _isRodExtended || _isCommandProcessing,
                    onTap: () {
                      if (_isRodExtended) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Retract rod first!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      _showConfirmation(
                        'Drying System',
                        _isDryingSystemOn
                            ? 'Turn OFF System'
                            : 'Turn ON System (Ready Mode)',
                        _toggleDryingPower,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Opacity(
                opacity: _isDryingSystemOn ? 1.0 : 0.5,
                child: AbsorbPointer(
                  absorbing: !_isDryingSystemOn,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Set Duration',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2339))),
                      const SizedBox(height: 16),
                      Row(children: [
                        _buildOptionButton('5m', _selectedFanTimer,
                            (val) => _handleTimerSelection(val)),
                        _buildOptionButton('10m', _selectedFanTimer,
                            (val) => _handleTimerSelection(val)),
                        _buildOptionButton('15m', _selectedFanTimer,
                            (val) => _handleTimerSelection(val)),
                        _buildOptionButton('30m', _selectedFanTimer,
                            (val) => _handleTimerSelection(val)),
                        if (_selectedFanTimer != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: GestureDetector(
                              onTap: () => _showConfirmation(
                                  'Stop Timer', 'stop the fan', _stopTimer),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Icon(Icons.stop_rounded,
                                    color: Colors.red, size: 20),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 24),
                      const Text('Fan Mode',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2339))),
                      const SizedBox(height: 16),
                      Row(children: [
                        _buildOptionButton('Auto', _selectedFanMode,
                            (val) => _handleFanModeSelection('Auto')),
                        _buildOptionButton('Low', _selectedFanMode,
                            (val) => _handleFanModeSelection('Low')),
                        _buildOptionButton('Med', _selectedFanMode,
                            (val) => _handleFanModeSelection('Med')),
                        _buildOptionButton('High', _selectedFanMode,
                            (val) => _handleFanModeSelection('High')),
                      ]),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const Text('System Status',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2339))),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2339),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF1E2339).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isRunning
                                ? 'TIME REMAINING'
                                : (_isCommandProcessing
                                    ? 'ROD MOVING'
                                    : (_isDryingSystemOn
                                        ? 'SYSTEM READY'
                                        : 'SYSTEM OFF')),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRunning
                                ? _formatTime(_remainingSeconds)
                                : (_isCoolingDown
                                    ? _formatTime(_cooldownRemainingSeconds)
                                    : '--:--'),
                            style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'monospace',
                                letterSpacing: 2.0,
                                height: 1.0),
                          ),
                          if (isRunning || _isCoolingDown) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF00E676), width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle,
                                      size: 8, color: Color(0xFF00E676)),
                                  const SizedBox(width: 8),
                                  Text(
                                    isRunning ? 'RUNNING' : 'MOVING',
                                    style: const TextStyle(
                                        color: Color(0xFF00E676),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildStatusRow(
                      'Activity',
                      _isCommandProcessing
                          ? 'MOVING'
                          : (isRunning
                              ? 'DRYING'
                              : (_isDryingSystemOn
                                  ? 'READY'
                                  : (_isRodExtended ? 'EXTENDED' : 'IDLE'))),
                      _isCommandProcessing
                          ? const Color(0xFFFF6D00)
                          : (isRunning
                              ? const Color(0xFFFF6D00)
                              : (_isRodExtended
                                  ? const Color(0xFF2962FF)
                                  : Colors.grey)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    _buildStatusRow(
                      'Power Consumption',
                      '$_powerConsumption W',
                      const Color(0xFF1E2339),
                      isAnimated: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color,
      {bool isAnimated = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
        isAnimated
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(value,
                    key: ValueKey<String>(value),
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              )
            : Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildToggleCard({
    required String title,
    String? activeTitle,
    required bool isOn,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
    bool isDisabled = false,
    bool isLoading = false,
    int? cooldownSeconds,
  }) {
    final Color cardBg = isOn ? activeColor : Colors.white;
    final Color iconBg =
        isOn ? Colors.white.withOpacity(0.2) : const Color(0xFFF5F6FA);
    final Color iconColor = isOn ? Colors.white : const Color(0xFF1E2339);
    final Color textColor = isOn ? Colors.white : const Color(0xFF1E2339);
    final Color subTextColor =
        isOn ? Colors.white.withOpacity(0.7) : Colors.grey;

    if (isDisabled && !isLoading) {
      if (cooldownSeconds != null && cooldownSeconds > 0) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: activeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: activeColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: activeColor,
                  ),
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${cooldownSeconds}s',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: activeColor)),
                const SizedBox(height: 4),
                Text(isOn ? (activeTitle ?? title) : title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: activeColor)),
              ]),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey[200], shape: BoxShape.circle),
              child: Icon(icon, color: Colors.grey, size: 24),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LOCKED',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400])),
              const SizedBox(height: 4),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400])),
            ]),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (isOn)
              BoxShadow(
                  color: activeColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6)),
            if (!isOn)
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 24),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isLoading ? 'SENDING...' : (isOn ? 'ON' : 'OFF'),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: subTextColor),
              ),
              const SizedBox(height: 4),
              Text(
                isOn && activeTitle != null ? activeTitle : title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(
      String text, String? selectedValue, Function(String) onTap) {
    bool isSelected = selectedValue != null && text == selectedValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(text),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2962FF) : Colors.grey[100],
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: const Color(0xFF2962FF).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Center(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF5A6175))),
          ),
        ),
      ),
    );
  }
}