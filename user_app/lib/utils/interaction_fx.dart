import "package:flutter/services.dart";

Future<void> playTapFx() async {
  try {
    await SystemSound.play(SystemSoundType.click);
  } catch (_) {}
  try {
    HapticFeedback.selectionClick();
  } catch (_) {}
}

Future<void> playSuccessFx() async {
  try {
    await SystemSound.play(SystemSoundType.alert);
  } catch (_) {}
  try {
    HapticFeedback.mediumImpact();
  } catch (_) {}
}
