import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';
import 'package:disaster_resilience_ai/utils/accessibility_settings.dart';

/// Full-screen incoming emergency alert — resembles an incoming phone call.
///
/// Shows pulsating danger visuals, continuous vibration, and reads the alert
/// aloud using the device's text-to-speech engine. The user can either
/// acknowledge the alert (navigates to the detailed emergency page) or dismiss.
class IncomingAlertPage extends StatefulWidget {
  const IncomingAlertPage({super.key, required this.warning});

  final Warning warning;

  @override
  State<IncomingAlertPage> createState() => _IncomingAlertPageState();
}

class _IncomingAlertPageState extends State<IncomingAlertPage>
    with TickerProviderStateMixin {
  static const int _dismissLockSeconds = 12;

  late final AnimationController _pulseController;
  late final AnimationController _slideController;
  late final Animation<double> _pulseAnimation;
  late final Animation<Offset> _slideAnimation;

  int _dismissCountdown = _dismissLockSeconds;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _assetAlarmPlaying = false;
  Timer? _vibrationTimer;
  Timer? _ringTimer;
  Timer? _dismissCountdownTimer;
  bool _reducedMotionEnabled = false;
  bool _hapticOnlyAlertsEnabled = false;

  @override
  void initState() {
    super.initState();

    // ── Pulse animation for the icon ring ──
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Slide-up animation for the bottom card ──
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    unawaited(_loadAccessibilityAndStartAlertEffects());

    // ── Force the screen to stay on and show over the lock screen ──
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _loadAccessibilityAndStartAlertEffects() async {
    final settings = await AccessibilitySettings.load();
    if (!mounted) return;

    _reducedMotionEnabled = settings.reducedMotionEnabled;
    _hapticOnlyAlertsEnabled = settings.hapticOnlyAlertsEnabled;

    if (_reducedMotionEnabled) {
      _pulseController.stop();
      _pulseController.value = 1;
      _slideController.value = 1;
    }

    _startVibrationLoop();
    if (!_hapticOnlyAlertsEnabled) {
      unawaited(_startRingingLoop());
    }
    _startDismissCountdown();

    setState(() {});
  }

  void _startVibrationLoop() {
    // Vibrate immediately, then every 2 seconds
    HapticFeedback.vibrate();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.vibrate();
    });
  }

  Future<void> _startRingingLoop() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/alarm.wav'));
      _assetAlarmPlaying = true;
    } catch (_) {
      _assetAlarmPlaying = false;
      SystemSound.play(SystemSoundType.alert);
    }

    _ringTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!_assetAlarmPlaying) {
        SystemSound.play(SystemSoundType.alert);
      }
      HapticFeedback.heavyImpact();
    });
  }

  void _startDismissCountdown() {
    _dismissCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_dismissCountdown <= 1) {
        setState(() => _dismissCountdown = 0);
        timer.cancel();
        return;
      }
      setState(() => _dismissCountdown -= 1);
    });
  }

  void _stopAlertEffects() {
    _vibrationTimer?.cancel();
    _ringTimer?.cancel();
    _dismissCountdownTimer?.cancel();
    _audioPlayer.stop();
    _assetAlarmPlaying = false;
  }

  @override
  void dispose() {
    _stopAlertEffects();
    _pulseController.dispose();
    _slideController.dispose();
    _audioPlayer.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _acknowledge() {
    _stopAlertEffects();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EmergencyAlertPage(warning: widget.warning),
      ),
    );
  }

  void _dismiss() {
    if (_dismissCountdown > 0) return;
    _stopAlertEffects();
    Navigator.of(context).pop();
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final warning = widget.warning;
    final isEvacuate = warning.alertLevel == AlertLevel.evacuate;

    final Color bgStart = isEvacuate
        ? const Color(0xFFB71C1C)
        : const Color(0xFFE65100);
    final Color bgEnd = isEvacuate
        ? const Color(0xFF880E0E)
        : const Color(0xFFBF360C);

    return PopScope(
      canPop: _dismissCountdown == 0,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgStart, bgEnd],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),
                // ── Alert level badge ──
                _buildAlertBadge(warning),
                const SizedBox(height: 28),
                // ── Pulsating icon ──
                _buildPulsingIcon(warning),
                const SizedBox(height: 28),
                // ── Title ──
                Semantics(
                  header: true,
                  label: isEvacuate
                      ? 'Emergency alert: evacuate now'
                      : 'Emergency alert received',
                  child: Text(
                    isEvacuate ? 'EVACUATE NOW' : 'EMERGENCY ALERT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    warning.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // ── Slide-up detail card ──
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildDetailCard(warning),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertBadge(Warning warning) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_rounded,
            color: Colors.yellowAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            warning.alertLevel.displayName,
            style: const TextStyle(
              color: Colors.yellowAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingIcon(Warning warning) {
    final IconData icon;
    switch (warning.alertLevel) {
      case AlertLevel.evacuate:
        icon = Icons.directions_run;
      case AlertLevel.warning:
        icon = Icons.warning_amber_rounded;
      case AlertLevel.observe:
        icon = Icons.visibility;
      case AlertLevel.advisory:
        icon = Icons.info_outline;
    }

    Widget iconBody = Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(30),
        border: Border.all(color: Colors.white.withAlpha(100), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 60),
    );

    if (!_reducedMotionEnabled) {
      iconBody = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _pulseAnimation.value, child: child);
        },
        child: iconBody,
      );
    }

    return Semantics(
      label: 'Hazard icon: ${warning.hazardType.displayName}',
      image: true,
      child: iconBody,
    );
  }

  Widget _buildDetailCard(Warning warning) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Hazard type chip ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _hazardColor(warning.hazardType).withAlpha(30),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hazardIcon(warning.hazardType),
                  size: 16,
                  color: _hazardColor(warning.hazardType),
                ),
                const SizedBox(width: 6),
                Text(
                  warning.hazardType.displayName.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _hazardColor(warning.hazardType),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Alert message ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.record_voice_over,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Alert Message',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  warning.description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_dismissCountdown > 0)
            Text(
              'Dismiss enabled in ${_dismissCountdown}s',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
          if (_dismissCountdown > 0) const SizedBox(height: 8),
          // ── Source & time ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.source, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Source: ${warning.source}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(width: 12),
              Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                _formatTime(warning.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Action buttons ──
          Row(
            children: [
              // Dismiss
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _dismissCountdown == 0 ? _dismiss : null,
                  icon: const Icon(Icons.close, size: 20),
                  label: Text(
                    _dismissCountdown == 0
                        ? 'DISMISS'
                        : 'DISMISS (${_dismissCountdown}s)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // View full details & evacuate
              Expanded(
                flex: 2,
                child: Semantics(
                  button: true,
                  label: warning.alertLevel == AlertLevel.evacuate
                      ? 'Open evacuation guidance now'
                      : 'Open detailed emergency guidance',
                  child: ElevatedButton.icon(
                    onPressed: _acknowledge,
                    icon: Icon(
                      warning.alertLevel == AlertLevel.evacuate
                          ? Icons.directions_run
                          : Icons.open_in_new,
                      size: 20,
                    ),
                    label: Text(
                      warning.alertLevel == AlertLevel.evacuate
                          ? 'EVACUATE NOW'
                          : 'VIEW DETAILS',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hazard helpers ────────────────────────────────────────────────────────

  IconData _hazardIcon(HazardType type) {
    switch (type) {
      case HazardType.flood:
        return Icons.water;
      case HazardType.landslide:
        return Icons.landscape;
      case HazardType.typhoon:
        return Icons.cyclone;
      case HazardType.earthquake:
        return Icons.public;
      case HazardType.forecast:
        return Icons.cloud;
      case HazardType.aid:
        return Icons.volunteer_activism;
      case HazardType.infrastructure:
        return Icons.construction;
    }
  }

  Color _hazardColor(HazardType type) {
    switch (type) {
      case HazardType.flood:
        return Colors.blue[700]!;
      case HazardType.landslide:
        return Colors.brown[700]!;
      case HazardType.typhoon:
        return Colors.indigo[700]!;
      case HazardType.earthquake:
        return Colors.red[700]!;
      case HazardType.forecast:
        return Colors.teal[700]!;
      case HazardType.aid:
        return Colors.green[700]!;
      case HazardType.infrastructure:
        return Colors.orange[700]!;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
