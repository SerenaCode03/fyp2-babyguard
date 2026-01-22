// services/cry_injection_manager.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

enum CryTestType {
  asphyxia,
  hungry,
  normal,
  pain,
}

extension CryTestTypeX on CryTestType {

  String get assetPath {
    switch (this) {
      case CryTestType.asphyxia:
        return 'assets/asphyxia_63.wav';
      case CryTestType.hungry:
        return 'assets/hunger_4.wav';
      case CryTestType.normal:
        return 'assets/52k.wav';
      case CryTestType.pain:
        return 'assets/pain_dac_2.wav';
    }
  }

  /// Friendly label (if you want to show in UI later)
  String get displayName {
    switch (this) {
      case CryTestType.asphyxia:
        return 'Asphyxia cry';
      case CryTestType.hungry:
        return 'Hungry cry';
      case CryTestType.normal:
        return 'Normal cry';
      case CryTestType.pain:
        return 'Pain cry';
    }
  }
}

class CryInjectionManager {
  CryInjectionManager._();
  static final CryInjectionManager instance = CryInjectionManager._();
  Future<File?> materializeToTempFile(CryTestType type) async {
    try {
      final data = await rootBundle.load(type.assetPath);

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/${type.name}_$ts.wav');

      await file.writeAsBytes(data.buffer.asUint8List());
      debugPrint('[CryInjection] Created temp WAV for ${type.name}: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('[CryInjection] Failed to load ${type.name}: $e');
      return null;
    }
  }
}
