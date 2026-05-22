import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:comeback_app/models/page_alert.dart';
import 'package:comeback_app/services/firestore_service.dart';

class AlarmOverlay extends StatefulWidget {
  final PageAlert alert;
  final String ownerName;

  const AlarmOverlay({
    super.key,
    required this.alert,
    required this.ownerName,
  });

  @override
  State<AlarmOverlay> createState() => _AlarmOverlayState();
}

class _AlarmOverlayState extends State<AlarmOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _acknowledging = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _playAlarm();
    _listenForCancellation();
  }

  Future<void> _playAlarm() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
  }

  void _listenForCancellation() {
    final firestore = context.read<FirestoreService>();
    firestore
        .getActivePageForEmployee(widget.alert.employeeId)
        .listen((activeAlert) {
      if (!mounted) return;
      if (activeAlert == null || activeAlert.id != widget.alert.id) {
        _stopAndPop();
      }
    });
  }

  Future<void> _acknowledge() async {
    if (_acknowledging) return;
    setState(() => _acknowledging = true);
    final firestore = context.read<FirestoreService>();
    await firestore.acknowledgePageAlert(widget.alert.id);
    if (mounted) _stopAndPop();
  }

  void _stopAndPop() {
    _audioPlayer.stop();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Color.lerp(
              const Color(0xFFB71C1C),
              const Color(0xFFFF1744),
              _pulseAnimation.value,
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 80,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Come Back!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your boss is looking for you!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.ownerName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 64),
                  GestureDetector(
                    onTap: _acknowledge,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _acknowledging
                            ? const CircularProgressIndicator(
                                color: Color(0xFFB71C1C),
                              )
                            : const Text(
                                'OK',
                                style: TextStyle(
                                  color: Color(0xFFB71C1C),
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
