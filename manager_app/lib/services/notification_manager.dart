import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

class NotificationManager {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;

  NotificationManager() {
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  // Play loop alarm sound from assets
  Future<void> playOrderAlarm() async {
    if (_isAlarmPlaying) return;
    try {
      _isAlarmPlaying = true;
      await _audioPlayer.play(AssetSource('sounds/alert.mp3'));
    } catch (e) {
      print('Error playing order alarm: $e');
      _isAlarmPlaying = false;
    }
  }

  // Stop loop alarm sound
  Future<void> stopOrderAlarm() async {
    if (!_isAlarmPlaying) return;
    try {
      await _audioPlayer.stop();
      _isAlarmPlaying = false;
    } catch (e) {
      print('Error stopping order alarm: $e');
    }
  }

  // Show OS native notification and bring app to foreground
  Future<void> triggerNewOrderNotification({
    required String orderId,
    required String guestName,
    required double totalPrice,
    required String deliveryType,
  }) async {
    if (kIsWeb) {
      print('Web notification: Nuovo ordine da $guestName (€${totalPrice.toStringAsFixed(2)})');
      return;
    }

    try {
      // 1. Show OS Native Notification
      final LocalNotification notification = LocalNotification(
        identifier: orderId,
        title: "Nuovo Ordine Ricevuto!",
        body: "Cliente: $guestName - Totale: €${totalPrice.toStringAsFixed(2)} ($deliveryType)",
        silent: true, // We handle the audio manually with loop player
      );

      notification.onShow = () {
        print('Notification shown for order: $orderId');
      };

      notification.onClick = () {
        print('Notification clicked, bringing app to front');
        bringWindowToFront();
      };

      await notification.show();
      await bringWindowToFront();
    } catch (e) {
      print('Error triggering notification: $e');
    }
  }

  // Focus and bring app window to front
  Future<void> bringWindowToFront() async {
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        if (await windowManager.isMinimized()) {
          await windowManager.restore();
        }
        await windowManager.focus();
        await windowManager.setAlwaysOnTop(true);
        await Future.delayed(const Duration(milliseconds: 500));
        await windowManager.setAlwaysOnTop(false);
      }
    } catch (e) {
      print('Error bringing window to front: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
