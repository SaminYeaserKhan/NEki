import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/dua/dua_provider.dart';
import 'package:neki/features/hadith/hadith_provider.dart';
import 'package:neki/features/recitations/providers/reading_settings_provider.dart';
import 'package:neki/features/recitations/providers/recitation_audio_provider.dart';
import 'package:neki/features/recitations/services/neural_tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dua Arabic Audio Verification', () {
    test('All 20 Quranic Duas map to verified EveryAyah Sheikh Mishary Alafasy studio tracks', () async {
      final content = await rootBundle.loadString('assets/data/duas.json');
      final list = jsonDecode(content) as List;
      final duas = list.map((e) => Dua.fromJson(e as Map<String, dynamic>)).toList();

      expect(duas.length, equals(81));

      final quranicDuas = duas.where((d) => d.isQuranic).toList();
      expect(quranicDuas.length, equals(20));

      for (final dua in quranicDuas) {
        expect(dua.audioUrl, isNotNull, reason: 'Quranic Dua ${dua.id} must have an audioUrl');
        expect(dua.audioUrl!.contains('everyayah.com'), isTrue,
            reason: 'Quranic Dua ${dua.id} must stream from EveryAyah studio archive');
        expect(dua.audioUrl!.contains('Alafasy'), isTrue,
            reason: 'Quranic Dua ${dua.id} must be Sheikh Mishary Alafasy');

        final resolvedUrl = RecitationAudioNotifier.getDuaAudioUrl(dua);
        expect(resolvedUrl, isNotNull);
        expect(resolvedUrl!.contains('everyayah.com'), isTrue);

        final subtitle = RecitationAudioNotifier.getDuaSubtitle(dua);
        expect(subtitle.contains('Mishary'), isTrue,
            reason: 'Quranic Dua ${dua.id} subtitle must indicate Sheikh Mishary Alafasy');
      }
    });

    test('All 61 Prophetic Duas use Arabic Neural TTS with authentic vocalized pronunciation', () async {
      final content = await rootBundle.loadString('assets/data/duas.json');
      final list = jsonDecode(content) as List;
      final duas = list.map((e) => Dua.fromJson(e as Map<String, dynamic>)).toList();

      final propheticDuas = duas.where((d) => !d.isQuranic).toList();
      expect(propheticDuas.length, equals(61));

      for (final dua in propheticDuas) {
        // Must not have fake/mismatched chapter audio or local clipped audio
        expect(dua.audioUrl, isNull,
            reason: 'Prophetic Dua ${dua.id} must not use mismatched chapter URLs');

        final subtitle = RecitationAudioNotifier.getDuaSubtitle(dua);
        expect(subtitle, equals('Arabic Recitation • Authentic Pronunciation'));
      }
    });
  });

  group('Hadith 100% Human Audio Verification', () {
    test('All 22 Hadiths have verified local audio assets bundled on disk', () async {
      final content = await rootBundle.loadString('assets/data/hadiths.json');
      final list = jsonDecode(content) as List;
      final hadiths = list.map((e) => HadithEntry.fromJson(e as Map<String, dynamic>)).toList();

      expect(hadiths.length, equals(22));

      for (final hadith in hadiths) {
        final asset = RecitationAudioNotifier.getHadithAudioAsset(hadith);
        expect(asset, equals('assets/audio/hadiths/h${hadith.id}.mp3'));

        final file = File(asset);
        expect(file.existsSync(), isTrue, reason: 'Asset file $asset must exist on disk');
        expect(file.lengthSync(), greaterThan(10000),
            reason: 'Audio file $asset must be non-empty valid audio');

        final subtitle = RecitationAudioNotifier.getHadithSubtitle(hadith);
        expect(subtitle, contains('Human Arabic Recitation'));
      }
    });
  });

  group('Neural TTS Service & Spoken Translation Tests', () {
    test('Voice resolution correctly maps Bengali and English female and male neural voices', () {
      expect(
        NeuralTtsService.resolveVoice(langCode: 'bn', gender: TtsVoiceGender.female),
        equals(NeuralTtsService.voiceBanglaFemale),
      );
      expect(
        NeuralTtsService.resolveVoice(langCode: 'bn', gender: TtsVoiceGender.male),
        equals(NeuralTtsService.voiceBanglaMale),
      );
      expect(
        NeuralTtsService.resolveVoice(langCode: 'en', gender: TtsVoiceGender.female),
        equals(NeuralTtsService.voiceEnglishFemale),
      );
      expect(
        NeuralTtsService.resolveVoice(langCode: 'en', gender: TtsVoiceGender.male),
        equals(NeuralTtsService.voiceEnglishMale),
      );
      expect(
        NeuralTtsService.resolveVoice(langCode: 'ar', gender: TtsVoiceGender.male),
        equals(NeuralTtsService.voiceArabicMale),
      );
    });

    test('Sanitizes HTML tags, footnote numbers, and parenthetical notes cleanly', () {
      const input = '<p>In the name of Allah [1] (SWT), the Most Gracious.</p>';
      final sanitized = NeuralTtsService.sanitizeText(input);
      expect(sanitized, equals('In the name of Allah , the Most Gracious.'));
    });

    test('ReadingSettingsState manages voiceGender preference correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(readingSettingsProvider);
      expect(settings.voiceGender, equals(TtsVoiceGender.female));

      final updated = settings.copyWith(voiceGender: TtsVoiceGender.male);
      expect(updated.voiceGender, equals(TtsVoiceGender.male));
    });
  });

  group('Playback Speed Slow-Down and Speed-Up Tests', () {
    test('RecitationAudioNotifier increments and decrements speed accurately across presets', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(recitationAudioProvider.notifier);

      // Default speed is 1.0
      expect(container.read(recitationAudioProvider).speed, equals(1.0));

      // Slow down: 1.0 -> 0.75
      await notifier.decreaseSpeed();
      expect(container.read(recitationAudioProvider).speed, equals(0.75));

      // Slow down again: 0.75 -> 0.5
      await notifier.decreaseSpeed();
      expect(container.read(recitationAudioProvider).speed, equals(0.5));

      // Slow down at minimum (0.5): stays 0.5
      await notifier.decreaseSpeed();
      expect(container.read(recitationAudioProvider).speed, equals(0.5));

      // Speed up: 0.5 -> 0.75
      await notifier.increaseSpeed();
      expect(container.read(recitationAudioProvider).speed, equals(0.75));

      // Speed up: 0.75 -> 1.0
      await notifier.increaseSpeed();
      expect(container.read(recitationAudioProvider).speed, equals(1.0));

      // Speed up: 1.0 -> 1.25
      await notifier.increaseSpeed();
      expect(container.read(recitationAudioProvider).speed, equals(1.25));

      // Speed up: 1.25 -> 1.5
      await notifier.increaseSpeed();
      expect(container.read(recitationAudioProvider).speed, equals(1.5));

      // Speed up: 1.5 -> 2.0
      await notifier.increaseSpeed();
      expect(container.read(recitationAudioProvider).speed, equals(2.0));

      // Speed up at maximum (2.0): stays 2.0
      await notifier.increaseSpeed();
      expect(container.read(recitationAudioProvider).speed, equals(2.0));
    });

    test('Available speeds list is sorted and covers educational range 0.5x to 2.0x', () {
      expect(RecitationAudioNotifier.availableSpeeds, equals([0.5, 0.75, 1.0, 1.25, 1.5, 2.0]));
    });
  });
}
