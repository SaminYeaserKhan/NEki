import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/dua/dua_provider.dart';
import 'package:neki/features/hadith/hadith_provider.dart';
import 'package:neki/features/recitations/providers/recitation_audio_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dua Library & Model Enhancements', () {
    test('Dua model correctly detects Quranic duas with Surah and Verse numbers', () {
      final json = {
        'id': 101,
        'category': 'Daily',
        'title': 'Rabbana Atina',
        'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
        'transliteration': 'Rabbana aatina fid-dunya hasanatan wa fil-aakhirati hasanatan wa qina adhaban-nar',
        'transliterationBn': 'রাব্বানা আতিনা ফিদ্দুনইয়া হাসানাতান',
        'english': 'Our Lord, give us in this world that which is good and in the Hereafter that which is good.',
        'bengali': 'হে আমাদের প্রতিপালক! আমাদের ইহকালে কল্যাণ দিন এবং পরকালেও কল্যাণ দিন।',
        'reference': 'Surah Al-Baqarah 2:201',
        'surahNumber': 2,
        'verseNumber': 201,
      };

      final dua = Dua.fromJson(json);
      expect(dua.id, equals(101));
      expect(dua.isQuranic, isTrue);
      expect(dua.surahNumber, equals(2));
      expect(dua.verseNumber, equals(201));
      expect(dua.transliterationBn, isNotNull);
      expect(dua.bengali, contains('ইহকালে কল্যাণ'));
    });

    test('Non-Quranic Prophetic Dua has isQuranic set to false', () {
      final json = {
        'id': 202,
        'category': 'Morning',
        'title': 'Sayyidul Istighfar',
        'arabic': 'اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ',
        'transliteration': "Allahumma Anta Rabbi la ilaha illa Anta",
        'english': 'O Allah, You are my Lord, there is no god but You.',
        'bengali': 'হে আল্লাহ, আপনিই আমার প্রতিপালক, আপনি ছাড়া কোনো উপাস্য নেই।',
        'reference': 'Sahih al-Bukhari 6306',
      };

      final dua = Dua.fromJson(json);
      expect(dua.isQuranic, isFalse);
      expect(dua.surahNumber, isNull);
      expect(dua.verseNumber, isNull);
    });

    test('assets/data/duas.json contains comprehensive collection (70+ duas)', () async {
      final content = await rootBundle.loadString('assets/data/duas.json');
      final list = jsonDecode(content) as List;

      expect(list.length, greaterThanOrEqualTo(70));

      final duas = list.map((e) => Dua.fromJson(e as Map<String, dynamic>)).toList();

      // Verify categories representation
      final categories = duas.map((d) => d.category).toSet();
      expect(categories.contains('morning'), isTrue);
      expect(categories.contains('evening'), isTrue);
      expect(categories.contains('prayer'), isTrue);
      expect(categories.contains('hardship'), isTrue);
      expect(categories.contains('protection'), isTrue);
      expect(categories.contains('family'), isTrue);

      // Verify Quranic Rabbana duas are present and properly annotated
      final quranicDuas = duas.where((d) => d.isQuranic).toList();
      expect(quranicDuas.length, greaterThanOrEqualTo(20));
      for (final qd in quranicDuas) {
        expect(qd.surahNumber, isNotNull);
        expect(qd.verseNumber, isNotNull);
        expect(qd.surahNumber!, greaterThanOrEqualTo(1));
        expect(qd.surahNumber!, lessThanOrEqualTo(114));
      }
    });
  });

  group('Hadith Library & CDN Architecture', () {
    test('assets/data/hadiths.json contains authentic core hadiths across Canonical books', () async {
      final content = await rootBundle.loadString('assets/data/hadiths.json');
      final list = jsonDecode(content) as List;

      expect(list.length, greaterThanOrEqualTo(20));

      final hadiths = list.map((e) => HadithEntry.fromJson(e as Map<String, dynamic>)).toList();

      // Check canonical collection coverage
      final bookIds = hadiths.map((h) => h.bookId).toSet();
      expect(bookIds.contains('bukhari'), isTrue);
      expect(bookIds.contains('muslim'), isTrue);
      expect(bookIds.contains('tirmidhi'), isTrue);
      expect(bookIds.contains('abudawud'), isTrue);
      expect(bookIds.contains('nasai'), isTrue);
      expect(bookIds.contains('ibnmajah'), isTrue);

      // Verify all hadiths have authentic Arabic Tashkeel and translations
      for (final h in hadiths) {
        expect(h.arabic.isNotEmpty, isTrue);
        expect(h.text.isNotEmpty, isTrue);
        expect(h.grade != null && (h.grade!.contains('Sahih') || h.grade!.contains('Hasan')), isTrue);
      }
    });

    test('hadithBooks contains the 6 Canonical Hadith collections', () {
      expect(hadithBooks.length, equals(6));
      expect(hadithBooks.map((b) => b.id).toList(), equals([
        'bukhari',
        'muslim',
        'tirmidhi',
        'abudawud',
        'nasai',
        'ibnmajah',
      ]));
    });
  });

  group('Authentic Recitation & Pronunciation Tests', () {
    test('Quranic Duas resolve to Sheikh Mishary Rashid Alafasy studio recitation', () {
      final dua = Dua(
        id: 101,
        category: 'daily',
        title: 'Rabbana Atina',
        arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً',
        transliteration: 'Rabbana atina',
        description: 'Our Lord give us good',
        bengali: 'হে আমাদের রব',
        surahNumber: 2,
        verseNumber: 201,
      );

      final url = RecitationAudioNotifier.getDuaAudioUrl(dua);
      final subtitle = RecitationAudioNotifier.getDuaSubtitle(dua);

      expect(url, isNotNull);
      expect(url!.toLowerCase(), contains('alafasy'));
      expect(subtitle, contains('Mishary Alafasy'));
      expect(subtitle, contains('Baqarah:201'));
    });

    test('Prophetic Duas resolve to authentic vocalized Arabic recitation', () {
      final dua1 = Dua(
        id: 1,
        category: 'morning',
        title: 'Morning Supplication',
        arabic: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
        transliteration: 'Asbahna',
        description: 'We enter the morning',
        bengali: 'আমরা সকালে উপনীত হলাম',
      );

      final url1 = RecitationAudioNotifier.getDuaAudioUrl(dua1);
      final subtitle1 = RecitationAudioNotifier.getDuaSubtitle(dua1);

      expect(url1, isNull);
      expect(subtitle1, equals('Arabic Recitation • Authentic Pronunciation'));

      // Test Quranic Dua (Dua 61: 2:201)
      final dua61 = Dua(
        id: 61,
        category: 'prayer',
        title: 'Best of Both Worlds',
        surahNumber: 2,
        verseNumber: 201,
        arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً',
        transliteration: 'Rabbana atina',
        description: 'Our Lord give us good in this world',
        bengali: 'হে আমাদের পালনকর্তা',
        audioUrl: 'https://everyayah.com/data/Alafasy_128kbps/002201.mp3',
      );

      final url61 = RecitationAudioNotifier.getDuaAudioUrl(dua61);
      final subtitle61 = RecitationAudioNotifier.getDuaSubtitle(dua61);
      expect(url61, equals('https://everyayah.com/data/Alafasy_128kbps/002201.mp3'));
      expect(subtitle61, contains('Sheikh Mishary Alafasy'));
    });

    test('All Duas in duas.json map to authentic studio EveryAyah tracks or Arabic Neural TTS', () async {
      final content = await rootBundle.loadString('assets/data/duas.json');
      final list = jsonDecode(content) as List;
      final duas = list.map((e) => Dua.fromJson(e as Map<String, dynamic>)).toList();

      for (final dua in duas) {
        final url = RecitationAudioNotifier.getDuaAudioUrl(dua);
        if (dua.isQuranic) {
          expect(url, isNotNull, reason: 'Quranic Dua ${dua.id} must have studio audio');
          expect(url!.contains('everyayah.com'), isTrue);
          expect(url.contains('Alafasy'), isTrue);
        } else {
          expect(url, isNull, reason: 'Prophetic Dua ${dua.id} must voice via Arabic Neural TTS');
          expect(dua.audioUrl, isNull, reason: 'Prophetic Dua ${dua.id} must not have mismatched URL');
        }
      }
    });

    test('Core Hadiths resolve to authentic human Arabic audio assets', () {
      final hadith1 = HadithEntry(
        id: 1,
        number: 1,
        bookId: 'bukhari',
        chapter: 'Revelation',
        arabic: 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
        text: 'Actions are by intentions',
        audioAsset: 'assets/audio/hadiths/h1.mp3',
      );

      final asset1 = RecitationAudioNotifier.getHadithAudioAsset(hadith1);
      final sub1 = RecitationAudioNotifier.getHadithSubtitle(hadith1);

      expect(asset1, equals('assets/audio/hadiths/h1.mp3'));
      expect(sub1, contains('Human Arabic Recitation'));

      final hadith9 = HadithEntry(
        id: 9,
        number: 223,
        bookId: 'muslim',
        chapter: 'Purification',
        arabic: 'الطُّهُورُ شَطْرُ الإِيمَانِ',
        text: 'Purity is half of faith',
        audioAsset: 'assets/audio/hadiths/h9.mp3',
      );

      final asset9 = RecitationAudioNotifier.getHadithAudioAsset(hadith9);
      final sub9 = RecitationAudioNotifier.getHadithSubtitle(hadith9);

      expect(asset9, equals('assets/audio/hadiths/h9.mp3'));
      expect(sub9, contains('Human Arabic Recitation'));
    });
  });
}
