# Neki — Comprehensive Feature Tracker & Project Roadmap

A modern, privacy-focused Islamic companion app built with Flutter, Riverpod, and an authentic audio engine.

---

## 🌟 Executive Summary: Current Status
- **Overall Test Coverage**: 124/124 automated unit, widget, and integration tests passing (`flutter test`).
- **Static Analysis**: 0 errors, 0 warnings (`flutter analyze`).
- **Active Branch**: `main`.
- **Core Pillars Completed**: Theme & Adaptive Sky Header, Recitations Hub (Quran, Dua, Hadith), Neural TTS & Studio Recitation Audio Engine, 2-Tier Floating Playback System, Digital Tasbih, Arabic Pronunciation & Tajweed Checker Studio, Single-Verse Auto-Pause & Continuous Full Surah Playback.

---

## ✅ Completed Milestones & Features

### Milestone 1: Dynamic Theme & Adaptive Readability
- [x] **Time-Aware Adaptive Color Palette**: 3-tier adaptive color system based on current prayer hour (Fajr, Dhuhr, Asr, Maghrib, Isha, Deep Night).
- [x] **Animated Header Component**: Animated sky gradient header with stars, glowing moon, and silhouette mosque graphics.
- [x] **Light & Dark Theme Engine**: Full support for system-following or user-selected dark/light modes via `ThemeProvider`.
- [x] **Bilingual Support (English & Bangla)**: Complete localized string catalog (`S.of(locale)`) with real-time language toggling (`AppLocale.bangla` / `AppLocale.english`) and SharedPreferences persistence.

### Milestone 2: Home Navigation & Multi-Tab Shell
- [x] **Vertical Two-Tier Home Screen**: Top Hero section (prayer times, celestial backdrop, daily highlight cards) seamlessly scrollable into the quick-access features deck.
- [x] **Persistent Navigation Shell**: Bottom navigation bar connecting Home, Recitations, Social, and Profile.
- [x] **Shared Navigation Providers**: Extracted navigation state (`navigation_providers.dart`) preventing circular dependencies.
- [x] **Quick Action Chips**: One-tap direct deep links from Home to Quran, Dua, and Hadith sub-sections.

### Milestone 3: Quran Reading & Audio Recitation Engine
- [x] **Full 114 Surahs Catalog**: Complete Surah index with Arabic titles, English/Bangla transliteration, verse count, and revelation location (Meccan / Medinan).
- [x] **Dual Reading Modes**:
  - *Mushaf View*: Continuous, authentic script view for uninterrupted recitation.
  - *Verse Study View*: Interactive card-by-card view with Arabic text, word-by-word translation, and contextual study.
- [x] **Interactive Ayah Navigation**:
  - Direct Ayah jumping dialog (`format_list_numbered`) to immediately leap to any verse.
  - Bottom panning Ayah pill bar with smooth horizontal scrolling and active verse indicator.
- [x] **Complete Audio Recitation**: High-quality studio recitations by world-renowned **Sheikh Mishary Rashid Alafasy** (EveryAyah 128kbps) for all 114 Surahs.
- [x] **Surah Opening & Closing Vocals**: Seamless playback of *Ta'awwudh*, *Bismillah*, and Surah conclusions.
- [x] **Pronunciation & Tajweed Checker Studio**: Dual-engine Arabic voice recognition (Groq Whisper Large-v3 free tier with scripture vocabulary prompt conditioning + on-device STT fallback), live amplitude visualizer, real-time Arabic text streaming, Arabic orthographic normalizer, word-by-word alignment feedback, and Tajweed rule detection across Quran, Dua, and Hadith.
- [x] **Pronunciation Studio Ergonomic Actions & Bilingual Mode**: Pinned top action bar with previous/next Ayah navigation, instant retry button, Master Reciter button, and 1-tap Bengali <-> English translation switch.
- [x] **Intelligent Auto-Pause & Continuous Surah Recitation Flow**: Individual verse recitations automatically pause and reset upon completion; toolbar 'Play Surah / Play All' plays through the entire Surah continuously.
- [x] **Comprehensive Reading Settings**: Adjustable Arabic font size, multiple calligraphic fonts, translation visibility toggles, and reciter speed.

### Milestone 4: Dua System Overhaul & Authentic Audio Mapping
- [x] **Category-Based Dua Discovery**: Grouped into thematic categories (Morning, Evening, Prayer, Protection, Travel, Food, Forgiveness, etc.).
- [x] **Modernized Dua UI**: Search bar, category filter pills, bookmarking, and diacritic-rich Arabic presentation.
- [x] **Authentic Audio Resolution**:
  - *Quranic Duas (20 Duas)*: Mapped to verified EveryAyah studio recitations by Sheikh Mishary Alafasy.
  - *Prophetic & Daily Duas (61 Duas)*: Vocalized via Microsoft Azure/Edge Neural Arabic TTS (`ar-SA-HamedNeural` and `ar-SA-ZariyahNeural`). Full Arabic *tashkeel/harakat* vowels ensure 100% authentic pronunciation matching on-screen text.
  - *Cleanup*: Purged mismatched external links and local clipped files.
- [x] **Disk Caching Engine**: Automatic persistent audio caching (`tts_cache/`) for offline instant replay.
- [x] **Bilingual Spoken Translations**: Spoken English (`en-US-JennyNeural`) and Bangla (`bn-BD-NabanitaNeural`) translations alongside Arabic recitations.

### Milestone 5: Hadith System Overhaul & Bukhari Audio
- [x] **Sahih al-Bukhari Comprehensive Index**: Complete catalog covering all 97 books with chapter metadata (`bukhari_sections_data.dart`).
- [x] **Clean Hadith Text Sanitizer**: Text sanitization utility (`hadith_text_sanitizer.dart`) stripping narrator prefixes for smooth TTS and reading.
- [x] **Human Arabic Audio Voicing**: Integrated authentic human-voiced chapter audio tracks (`assets/audio/hadiths/h1.mp3` through `h22.mp3`).
- [x] **Hadith Detail Reader**: Narrator chain (*isnad*), Matn, commentary, and synchronized audio playback.
- [x] **Spoken Translations**: English and Bangla translation playback for Hadiths.

### Milestone 6: Minimized Playback System Redesign
- [x] **Elevated 2-Tier Card Layout**: Solved mobile horizontal crowding by separating metadata and control decks in [`PersistentRecitationPlayer`](file:///Users/test/neki/lib/features/recitations/widgets/persistent_recitation_player.dart).
- [x] **Tier 1 (Maximum Track Title Visibility)**:
  - Live animated 4-bar sound wave visualizer (`AudioVisualizerWidget`).
  - Full-width expanded track title and subtitle (no squishing or truncation).
  - Quick dismiss button (`✕`).
- [x] **Tier 2 (Symmetrical Control Deck)**:
  - Frosted-glass **Speed Stepper** capsule: Slow Down (`-`), live speed indicator with popup selector menu (`0.5x` to `2.0x`), and Speed Up (`+`).
  - **Track Mode Toggle**: Relocated Arabic <-> Translation pill next to speed controls.
  - **5-Second Skip Buttons**: Dedicated "Go Back 5s" (`Icons.replay_5_rounded`) and "Go Forward 5s" (`Icons.forward_5_rounded`).
  - **Primary Play / Pause Action**: Centered 38sp emerald button.
- [x] **Full-Screen Player Modal Sheet**: Expanded view with scrub bar, repeat modes (off, verse, all), 10s skips, and pronunciation tools.

### Milestone 7: Digital Tasbih Tool
- [x] **Interactive Dhikr Counter**: Tap-to-count screen with haptic feedback, customizable target counts (33, 99, 100, custom), progress rings, and reset.
- [x] **Dhikr Presets**: SubhanAllah, Alhamdulillah, Allahu Akbar, Astaghfirullah, and custom phrases with transliteration and translation.

### Milestone 8: Pronunciation & Tajweed Studio (Dual-Engine AI Evaluation)
- [x] **Zero-Cost High-Precision Speech Recognition**: Groq Whisper Large-v3 with Scripture Prompt Conditioning, delivering Wispr Flow-grade accuracy (free tier, 2,000 requests/day). Seamless offline on-device speech fallback.
- [x] **Linguistic & Phonetic Discrepancy Diagnostics**: Letter-level analysis detecting emphatic letters (`ص` vs `س`, `ط` vs `ت`), throat letters (`ع`, `ح`, `خ`, `غ`), interdentals (`ث`, `ذ`), missing Qalqalah bounces (`[قطبجد]`), shortened Shaddah (`ّ`), and omitted words.
- [x] **Dedicated "Where You Went Wrong & How to Fix" Section**: High-contrast diagnostic cards detailing the exact discrepancy between what was heard and authentic scripture, paired with physical mouth/tongue/Makhraj instructions.
- [x] **Sticky Zero-Scroll Top Action Bar**: Pinned directly beneath the studio header containing `[🔄 Try Again]` (prominent primary action), `[🔊 Master Reciter]`, `[◀ Prev]`, `[Next Ayah ▶]`, and an Ayah navigation counter badge.
- [x] **Instant English <-> Bangla Language Switcher**: `[বাং / EN]` button in the top bar allowing 1-tap switching between English and Bangla translations and phonetic pronunciation scripts.
- [x] **Direct Scripture Card Integration**: Check Recitation button integrated directly on Quran verse study cards, Dua cards, and Hadith cards.

### Milestone 9: Testing & Quality Assurance
- [x] **119 Automated Tests**: Comprehensive unit and widget tests covering pronunciation evaluation, phonetic matching, sticky top actions, language toggling, navigation, and audio playback.
- [x] **Zero Analysis Warnings**: 100% clean `flutter analyze`.

---

## 🚀 Upcoming Roadmap: In Progress & Planned Features

### Milestone 10: Namaz & Prayer Times (Next Priority)
- [ ] **Task 9.1: Location & Prayer Calculation Engine**
  - Integrate GPS geolocation and offline city coordinates lookup.
  - Implement Islamic calculation conventions (MWL, ISNA, Umm al-Qura, Karachi, Egyptian).
  - Juristic methods (Shafi'i/Hanbali/Maliki vs Hanafi Asr time).
- [ ] **Task 9.2: Azan Audio & Push Notification System**
  - Local background notifications for Fajr, Dhuhr, Asr, Maghrib, and Isha.
  - User-configurable audio alerts (Full Azan, Takbir, gentle tone, silent).
  - Pre-prayer reminders (10/15 minutes before next prayer).
- [ ] **Task 9.3: Interactive Prayer Tracker**
  - Daily checkbox tracker for 5 obligatory prayers + Tahajjud, Duha, and Witr.
  - Qaza (missed prayer) counter and history logger.
  - Weekly and monthly prayer consistency charts.

### Milestone 10: Zakat Calculator & Distribution Guide
- [ ] **Task 10.1: Multi-Asset Zakat Calculator**
  - Cash, bank deposits, gold & silver holdings, stocks, business merchandise, and agriculture.
  - Deductible debts and living expenses.
  - Live/custom Nisab threshold calculator based on current gold/silver prices.
- [ ] **Task 10.2: Zakat Distribution Guidelines**
  - Educational guide detailing the 8 Quranic categories of Zakat recipients (*As-Sadaqat*, Surah At-Tawbah 9:60).
  - Calculation history saver and annual payment reminder.

### Milestone 11: Islamic Education & Quiz Module
- [ ] **Task 11.1: Quiz Engine & Data Providers**
  - Categorized question banks (Quran, Hadith, Seerah, Prophets, Islamic History, Fiqh basics).
  - Difficulty tiers (Beginner, Intermediate, Advanced).
- [ ] **Task 11.2: Interactive Quiz UI**
  - Timed multiple-choice questions with instant explanations and Quran/Hadith references.
  - Streak multipliers, score calculation, and review mode for missed questions.

### Milestone 12: Achievements & Gamification
- [ ] **Task 12.1: Achievement & Milestone Data Model**
  - Badges for reading consistency (e.g. 7-Day Quran Streak, Dua Master, 1000 Dhikr Milestone).
  - Local persistence for achievements, statistics, and milestones.
- [ ] **Task 12.2: Achievements & Badges Showcase Screen**
  - Visual trophy room displaying unlocked and locked badges with progress bars.

### Milestone 13: Community & Social Hub
- [ ] **Task 13.1: Social & Community Hub Screen**
  - Community collective Quran completion (*Khatam*) trackers.
  - Global daily Dhikr counter (collective community goal).
- [ ] **Task 13.2: User Profile & Account Settings**
  - User profile customizer (display name, avatar, bio).
  - Bookmarks & favorites manager across Quran verses, Duas, and Hadiths.
  - Cloud backup & data export/import settings.

### Milestone 14: Tools Expansion
- [ ] **Task 14.1: Qibla Compass**
  - Device magnetometer integration with calibrated heading indicator.
  - Kaaba bearing calculation from current GPS coordinates.
  - AR/Visual compass ring with haptic alignment feedback.
- [ ] **Task 14.2: Hijri Calendar & Islamic Events**
  - Accurate lunar Hijri calendar with Gregorian conversion.
  - Highlights for key Islamic dates (Ramadan, Eid al-Fitr, Eid al-Adha, Day of Arafah, Ashura, Laylat al-Qadr, White Days / *Ayyam al-Beed*).

---

## 📊 Summary Progress Checklist
| Feature Area | Status | Notes |
| :--- | :---: | :--- |
| **Theme & Adaptive Header** | ✅ 100% | 6-period dynamic sky gradients, dark/light modes, bilingual support. |
| **Quran Reader & Recitations** | ✅ 100% | 114 Surahs, Mushaf/Study view, EveryAyah Mishary recitations, Ayah jump. |
| **Dua Overhaul & Audio** | ✅ 100% | 81 Duas, EveryAyah Mishary + Azure Neural Arabic TTS, disk cache. |
| **Hadith Overhaul & Audio** | ✅ 100% | Bukhari index, sanitizer, 22 voiced chapter audios, bilingual translations. |
| **Minimized Playback System** | ✅ 100% | 2-tier card, full track name, 5s skips, speed stepper (-/1x/+), mode pill. |
| **Digital Tasbih** | ✅ 100% | Interactive counter, haptics, presets, custom targets. |
| **Pronunciation & Tajweed Studio** | ✅ 100% | Groq Whisper Large-v3, sticky zero-scroll actions, mistake diagnosis, [বাং/EN] toggle. |
| **Automated Tests** | ✅ 100% | 119/119 passing tests, 0 lint warnings. |
| **Namaz & Prayer Times** | ⏳ Planned | GPS prayer calculations, Azan alerts, daily prayer tracker. |
| **Zakat Calculator** | ⏳ Planned | Multi-asset calculator, live Nisab, recipient guide. |
| **Education & Quiz** | ⏳ Planned | Categorized Islamic trivia, timed challenges, score tracking. |
| **Achievements & Badges** | ⏳ Planned | Streak rewards, reading milestones, trophy showcase. |
| **Community & Social** | ⏳ Planned | Community Khatam, shared Dhikr goals, profile management. |
| **Qibla Compass & Hijri** | ⏳ Planned | Magnetometer compass, lunar calendar with Islamic events. |
