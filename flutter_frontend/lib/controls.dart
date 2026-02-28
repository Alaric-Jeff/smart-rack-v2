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
  // --- CHILD PROTECTION STATE ---
  bool _isChildProtectionEnabled = false;

  // --- ACTUATOR STATE ---
  bool _isRodExtended = false;
  bool _isCommandProcessing = false;
  bool _isLoadingState = true;
  int _powerConsumption = 2;

  // --- ACTUATOR COOLDOWN ---
  Timer? _cooldownTimer;
  int _cooldownRemainingSeconds = 0;
  bool get _isCoolingDown => _cooldownRemainingSeconds > 0;

  // --- FAN STATE ---
  bool _isDryingSystemOn = false;
  String _selectedFanMode = 'low';
  String? _selectedFanTimer;
  bool _isFanCommandProcessing = false;
  
  // Prevents listener from reverting optimistic UI update
  bool _suppressListenerUpdate = false;
  
  // --- FAN COOLDOWN (prevents rapid double-taps) ---
  Timer? _fanCooldownTimer;
  int _fanCooldownRemainingSeconds = 0;
  bool get _isFanCoolingDown => _fanCooldownRemainingSeconds > 0;

  // --- RTDB-BACKED TIMER ---
  Timer? _dryingTimer;         
  int _remainingSeconds = 0;
  int? _timerEndsAt;           

  // --- FIREBASE LISTENERS ---
  StreamSubscription<DatabaseEvent>? _actuatorListener;
  StreamSubscription<DatabaseEvent>? _fanListener;
  StreamSubscription<DatabaseEvent>? _settingsListener; // NEW: Listens for Lock

  @override
  void initState() {
    super.initState();
    if (widget.deviceId.isNotEmpty) {
      _initializeActuatorState();
      _initializeFanState();
      _setupActuatorListener();
      _setupFanListener();
      _setupSettingsListener(); // Initialize lock listener
    } else {
      setState(() => _isLoadingState = false);
    }
  }

  @override
  void dispose() {
    _dryingTimer?.cancel();
    _cooldownTimer?.cancel();
    _fanCooldownTimer?.cancel();
    _actuatorListener?.cancel();
    _fanListener?.cancel();
    _settingsListener?.cancel(); // Dispose listener
    super.dispose();
  }

  // ============================================================
  // DIALOGS
  // ============================================================
  void _showNoDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("No Device Paired",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
        content: const Text(
            "This function is disabled because no device is paired. Please go to Settings to connect a device."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFF2962FF))),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SETTINGS (CHILD PROTECTION) LISTENER
  // ============================================================
  void _setupSettingsListener() {
    if (widget.deviceId.isEmpty) return;

    _settingsListener = FirebaseDatabase.instance
        .ref('devices/${widget.deviceId}/settings/childProtection')
        .onValue
        .listen((DatabaseEvent event) {
      if (!mounted) return;
      final value = event.snapshot.value;
      setState(() {
        _isChildProtectionEnabled = (value == true);
      });
    }, onError: (error) => debugPrint('Settings listener error: $error'));
  }

  // ============================================================
  // ACTUATOR INIT + LISTENER
  // ============================================================
  Future<void> _initializeActuatorState() async {
    if (widget.deviceId.isEmpty) return;
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
        if (mounted) setState(() => _isLoadingState = false);
      }
    } catch (e) {
      debugPrint('Initial actuator state load: $e');
      if (mounted) setState(() => _isLoadingState = false);
    }
  }

  void _setupActuatorListener() {
    if (widget.deviceId.isEmpty) return;

    _actuatorListener = FirebaseDatabase.instance
        .ref('devices/${widget.deviceId}/actuator')
        .onValue
        .listen(
      (DatabaseEvent event) {
        if (!event.snapshot.exists || !mounted) return;

        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return;

        final state = data['state'] as String?;
        final commandRejected = data['commandRejected'] as bool? ?? false;

        if (state == 'extended' || state == 'retracted') {
          final newExtended = state == 'extended';

          if (commandRejected) {
            setState(() {
              _isCommandProcessing = false;
              _cooldownRemainingSeconds = 0;
              _cooldownTimer?.cancel();
              _isRodExtended = newExtended;
              _calculatePower();
            });
            return;
          }

          if (_isRodExtended != newExtended) {
            setState(() {
              _isRodExtended = newExtended;
              _isCommandProcessing = false;
              _calculatePower();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(newExtended
                    ? '✓ Rod fully extended'
                    : '✓ Rod fully retracted'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            if (_isCommandProcessing) {
              setState(() => _isCommandProcessing = false);
            }
          }
        }
      },
      onError: (error) => debugPrint('Actuator listener error: $error'),
    );
  }

  // ============================================================
  // FAN INIT + LISTENER
  // ============================================================
  Future<void> _initializeFanState() async {
    if (widget.deviceId.isEmpty) return;
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('devices/${widget.deviceId}/fans')
          .get();

      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final state = data['state'] as String?;
          final speed = data['speed'] as String?;
          final timerEndsAt = data['timerEndsAt'];

          setState(() {
            _isDryingSystemOn = state == 'on';
            _selectedFanMode = _validateSpeed(speed);
            _calculatePower();
          });

          // Restore RTDB timer if it exists and is still in the future
          if (timerEndsAt != null) {
            final endsAt = (timerEndsAt as num).toInt();
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final remainingMs = endsAt - nowMs;

            if (remainingMs > 0) {
              _restoreTimer(endsAt, remainingMs);
            } else {
              _clearRtdbTimer();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Initial fan state load: $e');
    }
  }

  void _setupFanListener() {
    if (widget.deviceId.isEmpty) return;

    _fanListener = FirebaseDatabase.instance
        .ref('devices/${widget.deviceId}/fans')
        .onValue
        .listen(
      (DatabaseEvent event) {
        if (!event.snapshot.exists || !mounted) return;

        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return;

        final state = data['state'] as String?;
        final speed = data['speed'] as String?;
        final timerEndsAt = data['timerEndsAt'];

        if (state == 'on' || state == 'off') {
          final newOn = state == 'on';

          if (_suppressListenerUpdate) {
            if (newOn == _isDryingSystemOn) {
              _suppressListenerUpdate = false;
            } else {
              return; 
            }
          } 

          setState(() {
            _isDryingSystemOn = newOn;
            if (speed != null) {
              _selectedFanMode = _validateSpeed(speed);
            }
            _isFanCommandProcessing = false;
            _calculatePower();
          });
        }

        if (timerEndsAt == null) {
          _cancelLocalTimer();
        } else {
          final endsAt = (timerEndsAt as num).toInt();
          if (_timerEndsAt != endsAt) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final remainingMs = endsAt - nowMs;
            if (remainingMs > 0) {
              _restoreTimer(endsAt, remainingMs);
            } else {
              _cancelLocalTimer();
              _clearRtdbTimer();
            }
          }
        }
      },
      onError: (error) => debugPrint('Fan listener error: $error'),
    );
  }

  // ============================================================
  // TIMER — RTDB-backed (Timestamp Logic)
  // ============================================================
  void _restoreTimer(int endsAtMs, int remainingMs) {
    _dryingTimer?.cancel();
    _timerEndsAt = endsAtMs;

    setState(() {
      _selectedFanTimer = null; 
      _remainingSeconds = (remainingMs / 1000).ceil();
      _calculatePower();
    });

    _dryingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final remaining = ((_timerEndsAt! - nowMs) / 1000).ceil();

      if (remaining <= 0) {
        timer.cancel();
        _handleTimerExpiry();
      } else {
        setState(() => _remainingSeconds = remaining);
      }
    });
  }

  void _handleTimerExpiry() {
    _cancelLocalTimer();

    FirebaseDatabase.instance
        .ref('devices/${widget.deviceId}/fans')
        .update({
      'target': 'off',
      'timerEndsAt': null, 
      'commandRejected': false,
      'lastCommandAt': ServerValue.timestamp,
    }).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏱️ Timer finished — fans turned off'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _cancelLocalTimer() {
    _dryingTimer?.cancel();
    if (mounted) {
      setState(() {
        _selectedFanTimer = null;
        _remainingSeconds = 0;
        _timerEndsAt = null;
        _calculatePower();
      });
    }
  }

  Future<void> _clearRtdbTimer() async {
    try {
      await FirebaseDatabase.instance
          .ref('devices/${widget.deviceId}/fans/timerEndsAt')
          .remove();
    } catch (e) {
      debugPrint('clearRtdbTimer error: $e');
    }
  }

  void _startTimerSequence(String duration) {
    if (_isChildProtectionEnabled) return; // Guard

    int minutes = int.parse(duration.replaceAll('m', ''));
    int totalMs = minutes * 60 * 1000;
    int endsAtMs = DateTime.now().millisecondsSinceEpoch + totalMs;

    _dryingTimer?.cancel();

    setState(() {
      _selectedFanTimer = duration;
      _timerEndsAt = endsAtMs;
      _remainingSeconds = minutes * 60;
      _calculatePower();
    });

    FirebaseDatabase.instance
        .ref('devices/${widget.deviceId}/fans')
        .update({
      'timerEndsAt': endsAtMs,
      'lastCommandAt': ServerValue.timestamp,
    });

    _dryingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final remaining = ((endsAtMs - nowMs) / 1000).ceil();

      if (remaining <= 0) {
        timer.cancel();
        _handleTimerExpiry();
      } else {
        setState(() => _remainingSeconds = remaining);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏱️ Timer set for $minutes minutes'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _stopTimerAndTurnOffFans() {
    if (_isChildProtectionEnabled) return; // Guard
    _cancelLocalTimer();

    FirebaseDatabase.instance
        .ref('devices/${widget.deviceId}/fans')
        .update({
      'target': 'off',
      'timerEndsAt': null, 
      'commandRejected': false,
      'lastCommandAt': ServerValue.timestamp,
    }).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏹️ Timer stopped — fans turned off'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _handleTimerSelection(String duration) {
    if (widget.deviceId.isEmpty) {
      _showNoDeviceDialog();
      return;
    }
    if (_isChildProtectionEnabled) return; // Guard

    if (!_isDryingSystemOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turn ON fans before setting a timer!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedFanTimer != null && _selectedFanTimer != duration) {
      _showConfirmation('Change Timer', 'change the timer to $duration', () {
        _startTimerSequence(duration);
      });
      return;
    }
    if (_selectedFanTimer == duration) {
      _showConfirmation(
        'Stop Timer',
        'stop the timer and turn off the fans',
        _stopTimerAndTurnOffFans,
      );
      return;
    }
    _startTimerSequence(duration);
  }

  // ============================================================
  // FAN TOGGLE — OPTIMISTIC UPDATE
  // ============================================================
  void _startFanCooldown() {
    _fanCooldownTimer?.cancel();
    setState(() => _fanCooldownRemainingSeconds = 10);

    _fanCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _fanCooldownRemainingSeconds--;
        if (_fanCooldownRemainingSeconds <= 0) {
          _fanCooldownRemainingSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _toggleDryingPower() async {
    if (widget.deviceId.isEmpty) {
      _showNoDeviceDialog();
      return;
    }
    if (_isChildProtectionEnabled) return; // Guard

    if (_isFanCoolingDown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please wait ${_fanCooldownRemainingSeconds}s before toggling again'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final bool originalState = _isDryingSystemOn;
    final bool newState = !originalState;

    setState(() {
      _isDryingSystemOn = newState;
      _suppressListenerUpdate = true; 
      
      if (!newState) {
        _cancelLocalTimer();
      }
      
      _calculatePower();
    });

    try {
      if (!newState) {
        await FirebaseDatabase.instance
            .ref('devices/${widget.deviceId}/fans')
            .update({
          'target': 'off',
          'timerEndsAt': null, 
          'commandRejected': false,
          'lastCommandAt': ServerValue.timestamp,
        });
      } else {
        await FirebaseDatabase.instance
            .ref('devices/${widget.deviceId}/fans')
            .update({
          'target': 'on',
          'speed': _selectedFanMode,
          'commandRejected': false,
          'lastCommandAt': ServerValue.timestamp,
        });
      }
      
      _startFanCooldown();

    } catch (e) {
      debugPrint('Fan toggle error: $e');
      setState(() {
        _isDryingSystemOn = originalState;
        _suppressListenerUpdate = false;
        _calculatePower();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fan Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ============================================================
  // FAN SPEED
  // ============================================================
  Future<void> _handleFanModeSelection(String rtdbValue) async {
    if (widget.deviceId.isEmpty) {
      _showNoDeviceDialog();
      return;
    }
    if (_isChildProtectionEnabled) return; // Guard

    final validatedSpeed = _validateSpeed(rtdbValue);
    setState(() => _selectedFanMode = validatedSpeed);

    try {
      final Map<String, dynamic> update = {
        'speed': validatedSpeed,
        'commandRejected': false,
        'lastCommandAt': ServerValue.timestamp,
      };

      if (_isDryingSystemOn) {
        update['target'] = 'on';
      }

      await FirebaseDatabase.instance
          .ref('devices/${widget.deviceId}/fans')
          .update(update);

    } catch (e) {
      debugPrint('Fan mode error: $e');
      if (mounted) {
        final snapshot = await FirebaseDatabase.instance
            .ref('devices/${widget.deviceId}/fans/speed')
            .get();
        if (snapshot.exists && mounted) {
          setState(() {
            _selectedFanMode = _validateSpeed(snapshot.value as String?);
          });
        }
      }
    }
  }

  // ============================================================
  // ACTUATOR CONTROL
  // ============================================================
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
          if (_isCommandProcessing) _isCommandProcessing = false;
        }
      });
    });
  }

  Future<void> _handleActuatorControl(bool extend) async {
    if (widget.deviceId.isEmpty) {
      _showNoDeviceDialog();
      return;
    }
    if (_isCoolingDown || _isCommandProcessing || _isChildProtectionEnabled) return; // Guard

    setState(() => _isCommandProcessing = true);

    try {
      await FirebaseDatabase.instance
          .ref('devices/${widget.deviceId}/actuator')
          .update({
        'target': extend ? 'extended' : 'retracted',
        'commandRejected': false,
        'lastCommandAt': ServerValue.timestamp,
      });

      _startCooldown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extend
                ? 'Extending rod... (~60s)'
                : 'Retracting rod... (~60s)'),
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

  // ============================================================
  // HELPERS
  // ============================================================
  String _validateSpeed(String? speed) {
    const validSpeeds = ['low', 'mid', 'high'];
    if (speed != null && validSpeeds.contains(speed)) {
      return speed;
    }
    return 'low';
  }

  void _calculatePower() {
    int newPower = 2;
    if (_isRodExtended) newPower += 5;

    if (_isDryingSystemOn) {
      switch (_selectedFanMode) {
        case 'low':
          newPower += 100;
          break;
        case 'mid':
          newPower += 250;
          break;
        case 'high':
          newPower += 450;
          break;
        default:
          newPower += 100;
      }
    }

    _powerConsumption = newPower;
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _speedToLabel(String rtdbValue) {
    switch (rtdbValue) {
      case 'low':
        return 'Low';
      case 'mid':
        return 'Med';
      case 'high':
        return 'High';
      default:
        return 'Low';
    }
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

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double padding = size.width * 0.05;
    bool isRunning = _isDryingSystemOn && _dryingTimer != null;

    // ADDED: Include Child Protection in the lock logic
    final bool rodButtonLocked =
        _isDryingSystemOn || _isCoolingDown || _isCommandProcessing || _isChildProtectionEnabled;
    final bool fanButtonLocked = 
        _isRodExtended || _isCommandProcessing || _isChildProtectionEnabled;

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
              
              // --- CHILD PROTECTION BANNER ---
              if (_isChildProtectionEnabled)
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.red, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Child Protection is ON. Manual controls are locked. You can disable this in Settings.',
                          style: TextStyle(
                            color: Colors.red[800],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 28),

              if (_isCoolingDown) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

              if (_isFanCoolingDown && !_isChildProtectionEnabled) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFFF6D00).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF6D00),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fan toggle cooldown — wait ${_fanCooldownRemainingSeconds}s',
                          style: const TextStyle(
                            color: Color(0xFFFF6D00),
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
                    cooldownSeconds:
                        _isCoolingDown ? _cooldownRemainingSeconds : null,
                    onTap: () {
                      if (widget.deviceId.isEmpty) {
                        _showNoDeviceDialog();
                        return;
                      }
                      if (_isChildProtectionEnabled) return;
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
                    isDisabled: fanButtonLocked,
                    isLoading: false, 
                    onTap: () {
                      if (widget.deviceId.isEmpty) {
                        _showNoDeviceDialog();
                        return;
                      }
                      if (_isChildProtectionEnabled) return;
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
                        _isDryingSystemOn ? 'Turn OFF fans' : 'Turn ON fans',
                        _toggleDryingPower,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Opacity(
                // ADDED: Make it look disabled if child protection is ON
                opacity: (_isDryingSystemOn && !_isChildProtectionEnabled) ? 1.0 : 0.5,
                child: AbsorbPointer(
                  // ADDED: Prevent taps if child protection is ON
                  absorbing: !_isDryingSystemOn || _isChildProtectionEnabled,
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
                        
                        if (_selectedFanTimer != null || _remainingSeconds > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: GestureDetector(
                              onTap: () => _showConfirmation(
                                'Stop Timer',
                                'stop the timer and turn off the fans',
                                _stopTimerAndTurnOffFans,
                              ),
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
                        _buildFanModeButton(label: 'Low', rtdbValue: 'low'),
                        _buildFanModeButton(label: 'Med', rtdbValue: 'mid'),
                        _buildFanModeButton(label: 'High', rtdbValue: 'high'),
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
                                        ? 'FANS RUNNING'
                                        : 'SYSTEM OFF')),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRunning ? _formatTime(_remainingSeconds) : '--:--',
                            style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'monospace',
                                letterSpacing: 2.0,
                                height: 1.0),
                          ),
                          if (_isDryingSystemOn) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_speedToLabel(_selectedFanMode).toUpperCase()} SPEED',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                          if (isRunning) ...[
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
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      size: 8, color: Color(0xFF00E676)),
                                  SizedBox(width: 8),
                                  Text(
                                    'RUNNING',
                                    style: TextStyle(
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
                                  ? 'FANS ON'
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
                      'Fan Speed',
                      _isDryingSystemOn
                          ? _speedToLabel(_selectedFanMode).toUpperCase()
                          : 'OFF',
                      _isDryingSystemOn
                          ? const Color(0xFFFF6D00)
                          : Colors.grey,
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

  Widget _buildFanModeButton({
    required String label,
    required String rtdbValue,
  }) {
    final bool isSelected = _selectedFanMode == rtdbValue;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (widget.deviceId.isEmpty) {
            _showNoDeviceDialog();
            return;
          }
          if (_isChildProtectionEnabled) return;
          if (!isSelected) {
            _handleFanModeSelection(rtdbValue);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF6D00)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: const Color(0xFFFF6D00).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF5A6175),
              ),
            ),
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
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
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
                decoration: BoxDecoration(
                    color: Colors.grey[200], shape: BoxShape.circle),
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
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
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