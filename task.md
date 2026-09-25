# 🌙 Neki — Comprehensive Feature Tracker & Project Roadmap

> **A modern, privacy-focused Islamic companion app built with Flutter, Riverpod, and an authentic audio engine.**

---

## 📊 Project Health Dashboard

| Metric | Status | Details |
| :--- | :---: | :--- |
| **Test Suite** | ![152/152 Passing](https://img.shields.io/badge/Tests-152%2F152%20Passing-brightgreen?style=flat-square) | 100% automated test coverage across unit, widget, and audio flows |
| **Static Analysis** | ![0 Issues](https://img.shields.io/badge/Analyzer-0%20Issues-brightgreen?style=flat-square) | Zero lint warnings or errors via `flutter analyze` |
| **Active Branch** | ![main](https://img.shields.io/badge/Branch-main-blue?style=flat-square) | All features merged and pushed to GitHub |
| **Milestone Progress** | ![63% Complete](https://img.shields.io/badge/Roadmap-10%20%2F%2016%20Completed%20(63%25)-green?style=flat-square) | Core recitations, prayer calculation engine, bookmarks & audio sync complete |

---

## 📑 Table of Contents

- [Completed Milestones (1 – 10)](#-completed-milestones)
  - [M1: Dynamic Theme & Adaptive Sky](#milestone-1-dynamic-theme--adaptive-readability)
  - [M2: Home Hub & Navigation Shell](#milestone-2-home-navigation--multi-tab-shell)
  - [M3: Quran Reader, Bookmarks & Recitation Engine](#milestone-3-quran-reading--audio-recitation-engine)
  - [M4: Dua Library & Authentic Audio](#milestone-4-dua-system--authentic-audio-mapping)
  - [M5: Hadith Library & Voiced Chapters](#milestone-5-hadith-system--bukhari-audio)
  - [M6: Persistent Audio Player](#milestone-6-minimized-playback-system-redesign)
  - [M7: Digital Tasbih Tool](#milestone-7-digital-tasbih-tool)
  - [M8: Pronunciation & Tajweed Studio](#milestone-8-pronunciation--tajweed-studio-dual-engine-ai)
  - [M9: Testing, Quality Assurance & Security](#milestone-9-testing-quality-assurance--security)
  - [M10: Namaz & Prayer Times](#milestone-10-namaz--prayer-times)
- [Upcoming Roadmap (11 – 16)](#-upcoming-roadmap)
  - [M11: Zakat Calculator & Guidelines](#milestone-11-zakat-calculator--distribution-guide)
  - [M12: Islamic Education & Quiz Module](#milestone-12-islamic-education--quiz-module)
  - [M13: Achievements & Gamification](#milestone-13-achievements--gamification)
  - [M14: Social Media Hub & In-App Video Feed](#milestone-14-social-media-hub-community--in-app-video-feed)
  - [M15: Qibla Compass & Hijri Calendar](#milestone-15-tools-expansion)
  - [M16: Neki AI Islamic Assistant & App Agent](#milestone-16-neki-ai-islamic-assistant--app-agent)
- [Feature Matrix & Status Summary](#-feature-matrix--status-summary)

---

## ✅ Completed Milestones

### Milestone 1: Dynamic Theme & Adaptive Readability
- [x] **Time-Aware Adaptive Color Palette**: 3-tier adaptive color system dynamically updating based on the Islamic prayer hour (Fajr, Dhuhr, Asr, Maghrib, Isha, Deep Night).
- [x] **Animated Header Graphics**: Dynamic sky gradient backdrop with twinkles, glowing moon phases, and silhouette mosque art.
- [x] **Theme Switcher**: Instant switching between system, dark, and light modes via `ThemeProvider`.
- [x] **Bilingual Support (English & Bangla)**: Complete localized string catalog with real-time language toggling (`AppLocale.bangla` / `AppLocale.english`) and persistence.

### Milestone 2: Home Navigation & Multi-Tab Shell
- [x] **Two-Tier Scrollable Home Deck**: Top Hero section (prayer countdown, celestial backdrop, daily cards) scrolling seamlessly into feature cards.
- [x] **Persistent Navigation Shell**: Bottom navigation bar connecting Home, Recitations, Social, and Profile tabs.
- [x] **Decoupled State Management**: Isolated navigation providers preventing cyclic Riverpod dependencies.
- [x] **Quick-Access Action Chips**: One-tap deep links directly jumping into Quran, Dua, and Hadith sections.

### Milestone 3: Quran Reading & Audio Recitation Engine
- [x] **Full 114 Surahs Catalog**: Comprehensive index with Arabic script, English & Bangla transliterations, verse counts, and Meccan/Medinan markers.
- [x] **Dual Reading Modes**:
  - **Mushaf View**: Continuous authentic Uthmani script flow with interactive medallion separators (`۝`).
  - **Verse Study View**: Line-by-line card layout with Arabic text, translation, transliteration, and action controls.
- [x] **Ayah Navigation & Jumping**:
  - Direct jump dialog (`format_list_numbered`) to leap to any Ayah instantly.
  - Horizontal panning Ayah pill bar with smooth scrubbing and active verse indication.
- [x] **Sheikh Mishary Alafasy Recitations**: Studio audio streaming via EveryAyah (128kbps) for all 6,236 verses.
- [x] **Authentic Vocals**: Seamless playback of *Ta'awwudh*, *Bismillah*, and Surah conclusions (*Sadaqallahul 'Adheem*).
- [x] **Single-Verse Auto-Stop vs. Continuous Play All**:
  - Reciting or listening to an individual Ayah automatically stops and pauses the player at `0:00` upon completion.
  - Tapping **Play All / Play Surah** plays through the entire Surah continuously from the opening to the conclusion.
- [x] **Reading Customization**: Adjustable Arabic font sizes, multiple calligraphic fonts, translation visibility toggles, and playback speed modifiers.

### Milestone 4: Dua System & Authentic Audio Mapping
- [x] **Thematic Categorization**: 81 authentic Duas grouped into Morning, Evening, Prayer, Travel, Protection, Forgiveness, and Hardship.
- [x] **Modern Search & Filter Deck**: Category pill filters, search query filtering, and bookmarking.
- [x] **Multi-Source Audio Engine**:
  - **Quranic Duas (20 Duas)**: Mapped to EveryAyah studio recitations by Sheikh Mishary Alafasy.
  - **Prophetic Duas (61 Duas)**: High-fidelity vocalization via Microsoft Azure/Edge Neural Arabic TTS (`ar-SA-HamedNeural` and `ar-SA-ZariyahNeural`) with 100% *harakat/tashkeel* accuracy.
- [x] **Persistent Audio Caching**: Automatic disk caching (`tts_cache/`) for instantaneous offline replay.
- [x] **Spoken Translations**: English (`en-US-JennyNeural`) and Bangla (`bn-BD-NabanitaNeural`) spoken audio tracks.

### Milestone 5: Hadith System & Bukhari Audio
- [x] **Sahih al-Bukhari Catalog**: Complete index of all 97 books with chapter metadata (`bukhari_sections_data.dart`).
- [x] **Clean Text Sanitizer**: Automated pipeline stripping repetitive narrator chains (*isnad*) for natural reading and TTS flow.
- [x] **Human Arabic Voice Tracks**: Bundled studio recitations for key chapter highlights (`assets/audio/hadiths/`).
- [x] **Synchronized Detail Reader**: Full Hadith viewer with Arabic matn, English and Bangla translations, reference metadata, and audio sync.

### Milestone 6: Minimized Playback System Redesign
- [x] **Elevated 2-Tier Floating Bar**: Prevents mobile screen crowding by cleanly separating metadata from interactive controls in `PersistentRecitationPlayer`.
- [x] **Tier 1 (Metadata Deck)**:
  - Live animated 4-bar audio frequency visualizer.
  - Full-width scrolling track title and subtitle (zero truncation).
  - One-tap dismiss button (`✕`).
- [x] **Tier 2 (Control Deck)**:
  - **Speed Stepper**: Frosted-glass capsule with slow down (`-`), current speed indicator (`0.5x` – `2.0x`), and speed up (`+`).
  - **Track Mode Pill**: One-tap toggle between Arabic Recitation (`আরবি`) and Spoken Translation (`অনুবাদ`).
  - **5-Second Skip Buttons**: Dedicated replay 5s (`replay_5_rounded`) and forward 5s (`forward_5_rounded`).
  - **Centered Play/Pause**: High-contrast 38sp emerald playback button with dynamic state feedback.
- [x] **Expanded Bottom Sheet Modal**: Full-screen player modal with progress scrub bar, repeat mode cycles (Off, Verse, All), and 10s skip controls.

### Milestone 7: Digital Tasbih Tool
- [x] **Interactive Dhikr Counter**: Tap-to-count canvas with haptic feedback, animated progress rings, and reset protection.
- [x] **Preset & Custom Targets**: Quick presets for 33, 99, 100, or unlimited counts.
- [x] **Authentic Supplication Presets**: Pre-loaded with SubhanAllah, Alhamdulillah, Allahu Akbar, Astaghfirullah, and custom phrases.

### Milestone 8: Pronunciation & Tajweed Studio (Dual-Engine AI)
- [x] **Acoustic Speech Recognition**: Cloud Whisper Large-v3 via Groq API (free tier, 2,000 req/day) delivering precision speech recognition without artificial prompt bias.
- [x] **Offline Speech Fallback**: On-device native speech recognition ensuring zero downtime when offline.
- [x] **Phonetic & Tajweed Diagnostics**: Deep letter-level diagnostic engine identifying:
  - Emphatic letters (`ص` vs `س`, `ط` vs `ت`)
  - Guttural/throat letters (`ع`, `ح`, `خ`, `غ`)
  - Interdentals (`ث`, `ذ`)
  - Missing Qalqalah bounces (`[قطبجد]`)
  - Unheld Shaddah (`ّ`) and omitted syllables
- [x] **"Where You Went Wrong & How to Fix" Guidance**: High-contrast diagnostic feedback cards detailing exact phonetic discrepancies paired with physical mouth/tongue/Makhraj instructions.
- [x] **Zero-Scroll Sticky Top Action Bar**:
  - Pinned directly beneath the studio header.
  - Previous (`◀`) and Next (`▶`) Ayah navigation controls without scrolling.
  - Instant `[🔄 Try Again]` primary button and `[🔊 Master Reciter]` reference audio button.
- [x] **1-Tap Bilingual Switcher**: `[বাং / EN]` toggle in the top bar to swap translations and phonetic pronunciation scripts instantly.
- [x] **Universal Card Integration**: One-tap studio launcher accessible on every Quran Ayah card, Dua card, and Hadith view.

### Milestone 9: Testing, Quality Assurance & Security
- [x] **143 Automated Tests**: 100% test pass rate across unit, widget, audio completion, phonetic matching, navigation, and prayer calculation suites.
- [x] **Zero Static Analysis Warnings**: Clean `flutter analyze` with 0 issues.
- [x] **Security Hardening**:
  - Secure `.env` configuration loader with dynamic path resolution and compile-time fallback.
  - `.env` strictly ignored in `.gitignore` to prevent credential leaks.
  - Tracked `.env.example` template for development setup.

---

## 🚀 Upcoming Roadmap

### Milestone 10: Namaz & Prayer Times (Completed)
- [x] **10.1: Geolocation & Prayer Calculation Engine**
  - Offline-first astronomical calculation engine using `adhan` package with zero network dependency.
  - GPS device location detection (`geolocator` & `geocoding`) with fallback to 30+ curated offline cities (Bangladesh divisions + worldwide Islamic capitals).
  - Nearest city Haversine distance resolver and instant search selector bottom sheet.
  - International calculation conventions: Karachi (standard for Bangladesh/Pakistan/India), Muslim World League (MWL), ISNA, Umm al-Qura, Egyptian General Authority, Dubai, Qatar, Kuwait, Singapore, Tehran.
  - Asr juristic calculation methods: Hanafi (shadow factor 2, standard South Asia) vs. Shafi'i/Maliki/Hanbali (standard).
  - Per-prayer minute offsets (-30 to +30 min) and high-latitude rule adjustments with SharedPreferences persistence.
  - Gregorian to Hijri lunar calendar converter with English & Bangla month names and localized numerals.
  - Real-time ticking live Waqt stream provider with dynamic countdown, waqt progress percentage, Qibla compass angle, and Makruh prohibited time detection (sunrise window, midday Zawal zenith, sunset window).
- [x] **10.2: Azan Audio & Alert Configuration System**
  - Configurable alert tones and audio previews using `just_audio` (Makkah Azan, Madinah Azan, Al-Aqsa Azan, Takbir-only).
  - Sound preview controls with live playback indicator in the settings tab and prayer cards.
  - Per-prayer Azan notification toggles and alert mode selector (Full Azan, Beep/Chime, Silent banner).
- [x] **10.3: Daily Prayer Tracker & History**
  - Daily checklist for obligatory (Farz) prayers (Fajr, Dhuhr, Asr, Maghrib, Isha) with persistent completion records.
  - Sunnah & Nafl prayer tracking: Tahajjud, Ishraq/Duha, and Witr.
  - Qaza-e-Umri missed prayer counter deck with increment, decrement, and clamping safety.
  - Monthly prayer timetable generator with daily Hijri dates and Sehri/Iftar timings.
  - Interactive Home Screen integration:
    - Replaced the coming-soon placeholder card with an interactive `NamazHomeCard` showing the 5 daily prayers, active waqt highlight, and prayed count.
    - Updated the Home Screen date/time widget (`_HeroPrayerCard`) with an interactive GPS location badge/pill to switch locations and direct tap-to-open access to the full Namaz hub.

### Milestone 11: Zakat Calculator & Distribution Guide
- [ ] **11.1: Multi-Asset Wealth Calculator**
  - Category assessment: Cash & bank balances, gold & silver holdings, investment stocks, business inventory, and agricultural produce.
  - Deductible liabilities: Debts due, immediate living expenses.
  - Dynamic Nisab threshold calculation based on current gold/silver market prices.
- [ ] **11.2: Zakat Distribution Guidelines**
  - Educational reference covering the 8 Quranic categories of eligible recipients (*As-Sadaqat*, Surah At-Tawbah 9:60).
  - Calculation history archiver with annual due date reminder alerts.

### Milestone 12: Islamic Education & Quiz Module
- [ ] **12.1: Question Banks & Trivia Engine**
  - Categorized question banks: Quranic Knowledge, Hadith Literature, Seerah & Prophets, Islamic History, and Fiqh Fundamentals.
  - Progressive difficulty tiers: Beginner, Intermediate, Advanced.
- [ ] **12.2: Interactive Challenge UI**
  - Timed multiple-choice quiz interface with immediate answer explanations and Quran/Hadith citations.
  - Streak multipliers, score counters, and missed question review mode.

### Milestone 13: Achievements & Gamification
- [ ] **13.1: Milestone & Streak Data Model**
  - Streaks for daily reading consistency (e.g., 7-Day Quran Streak, Dua Master, 1000 Dhikr Milestone).
  - Local SQLite / SharedPreferences persistence for badges and user stats.
- [ ] **13.2: Trophy Showcase Screen**
  - Visual trophy cabinet displaying unlocked and in-progress badges with completion progress bars.

### Milestone 14: Social Media Hub, Community & In-App Video Feed
- [ ] **14.1: Multi-Category Social Architecture & Supabase Backend**
  - Supabase Postgres schema with unified `posts` table supporting post types: `general`, `imam_wisdom`, `janaza`, `event`, and `video`.
  - User verification system with verified scholar credentials (`is_verified_imam`, `title`, `organization`, `avatar_url`).
  - Real-time post feed streams via Supabase Realtime and optimistic UI caching.
- [ ] **14.2: Default Feed & Top Filter Pill Navigation**
  - Unified default social timeline aggregating a rich, healthy mix of community posts, Imam wisdom, urgent Janaza notices, upcoming events, and Islamic videos.
  - Top sticky filter pill deck allowing instant 1-tap switching between:
    - `[🌐 All Feed]` — Curated chronological blended timeline.
    - `[📝 User Posts]` — Community discussions, personal reflections, and questions.
    - `[🕌 Imam Wisdom]` — Exclusive verified scholar reminders, tafsir pearls, and quotes.
    - `[🕊️ Janaza Alerts]` — Urgent funeral prayer notices and cemetery locations.
    - `[📅 Events]` — Local and virtual Islamic lectures, halaqas, and gatherings.
    - `[🎬 Video Reels]` — Exclusive in-app distraction-free video playback page.
- [ ] **14.3: Community Posts & Reflection Deck**
  - Post creation sheet with text styling, image attachments, and Islamic etiquette reminders.
  - Halal reaction system (SubhanAllah, Alhamdulillah, Allahu Akbar, Ameen).
  - Moderated comment threads and community self-policing (report/flag inappropriate content).
- [ ] **14.4: Verified Imams & Islamic Wisdom Hub**
  - Dedicated view displaying exclusively verified Imams, scholars, and recognized Islamic institutions.
  - High-visibility gold/emerald verification badge (`verified_rounded`) to safeguard against unverified religious advice.
  - "Daily Wisdom Pearl" highlighted hero card with one-tap bookmarking and social sharing.
- [ ] **14.5: Janaza Announcement & Urgent Alert Network**
  - Dedicated emergency Janaza feed with real-time push notification broadcasts.
  - Structured announcement card: Deceased name, Janaza prayer time (*Waqt*), Mosque/Islamic center, and GPS coordinates.
  - One-tap "Open in Maps" navigation to the funeral prayer venue.
  - "Attending Janaza" and "Made Dua" community counter.
- [ ] **14.6: Islamic Events & Halaqa Registry**
  - Dedicated events catalog for local lectures, weekly halaqas, Ramadan programs, and charity drives.
  - Interactive RSVP system ("Attending", "Interested") and local calendar export (`Add to Device Calendar`).
  - Event detail sheet with guest speakers, venue address, and live streaming links.
- [ ] **14.7: Distraction-Free In-App Islamic Video Feed (Watch / Reels)**
  - Dedicated vertical-swipe / immersive video player page (similar to Facebook Watch / Reels) playing directly inside Neki.
  - **YouTube In-App Integration**: Official `youtube_player_iframe` embedding curated Islamic channels and Shorts without kicking user out to YouTube app (avoids secular algorithms, distractions, and unwholesome ads).
  - **Direct Video Streams & HLS/MP4 CDN**: Support for direct scholar reels hosted on Supabase Storage / Cloudflare Stream via Flutter `video_player`.
  - **Facebook / Instagram Safe Fallback**: Rich social card embeds with in-app webview player fallback where permissible without login barriers.
  - Categorized video tags: *Tafsir, Seerah, Youth & Family, Daily Reminders, Heart-Softening Recitations*.
- [ ] **14.8: Communal Khatam & Shared Goals**
  - Collective Quran completion (*Khatam*) tracker for families and study circles with 30-Juz assignment slots.
  - Shared global daily Dhikr counter with live milestone celebration animations.
- [ ] **14.9: User Profile & Cloud Backup**
  - Customizable profile (display name, avatar selection, bio, verified badge status).
  - Cross-device favorites, saved posts, and bookmarks manager via Supabase sync.

### Milestone 15: Tools Expansion
- [ ] **15.1: Qibla Compass**
  - Device magnetometer sensor integration with tilt-compensated compass heading.
  - Kaaba bearing calculation from current GPS coordinates.
  - Visual compass ring with haptic feedback upon alignment with Mecca.
- [ ] **15.2: Lunar Hijri Calendar & Events**
  - Accurate lunar Hijri calendar with Gregorian conversion.
  - Important date highlights: Ramadan, Eid al-Fitr, Eid al-Adha, Day of Arafah, Ashura, Laylat al-Qadr, and White Days (*Ayyam al-Beed*).

### Milestone 16: Neki AI Islamic Assistant & App Agent
- [ ] **16.1: Conversational Chat Interface & Multimodal Engine**
  - Elegant sliding sheet or dedicated full-screen AI companion accessible via persistent quick-launch orb.
  - Real-time streaming response engine with markdown formatting, Uthmani Arabic script callouts, and translations.
  - Chat history persistence and session management via Riverpod.
- [ ] **16.2: In-App Action & Navigation Agent (Function Calling / Tool Use)**
  - Intelligent action parser mapping natural language user commands to in-app execution:
    - *"Open Surah Al-Kahf"* / *"Go to Surah 18"* ➔ `navigateToSurah(18)`
    - *"Find dua for anxiety and sadness"* ➔ `navigateToDua(category: 'hardship')`
    - *"Show me Bukhari hadiths about good manners"* ➔ `navigateToHadith(query: 'good manners')`
    - *"Open digital tasbih counter"* ➔ `navigateToTasbih()`
    - *"Show today's Janaza prayers"* ➔ `navigateToSocial(category: 'janaza')`
    - *"Play Ayat al-Kursi by Sheikh Mishary"* ➔ `playRecitation(surah: 2, ayah: 255)`
  - Visual action confirmation pills ("Navigating to Surah Al-Kahf...") with seamless screen transitions.
- [ ] **16.3: Voice Input & Hands-Free Interaction**
  - Real-time voice query recording utilizing existing Groq Whisper Large-v3 and on-device native speech recognition fallback.
  - Hands-free query support with audio playback response toggle (Azure Neural Arabic / English / Bangla TTS).
- [ ] **16.4: Grounded Islamic RAG Knowledge Engine**
  - In-app retrieval over authentic localized data stores:
    - Complete Quranic index & translations (`quran` package) for verse meaning, context, and cross-referencing.
    - Sahih al-Bukhari database (`bukhari_sections_data.dart`) for authentic Hadith inquiries.
    - 81 categorized Duas (`dua_data.dart`) for situational supplications (morning, evening, travel, sickness, rain).
  - Direct interactive citations: AI responses embed clickable chips that deep-link directly into the Quran reader or Hadith viewer.
- [ ] **16.5: Fiqh Guardrails & Scholarly Citation Standards**
  - Strict system prompt conditioning enforcing adherence to authentic Sunni consensus (Quran, Sahihain, reputable Tafsir).
  - Hallucination prevention: strict instructions to never invent Hadiths or attribute weak narrations without clear classification.
  - Fatwa safety boundary: automatically identifies legal/theological jurisprudence questions and advises consulting a qualified local Mufti or Islamic scholar.

---

## 📊 Feature Matrix & Status Summary

| # | Feature Domain | Status | Completion | Key Highlights |
| :---: | :--- | :---: | :---: | :--- |
| **01** | **Dynamic Theme & Sky** | 🟢 Done | **100%** | 6 prayer periods, dark/light modes, bilingual support |
| **02** | **Home Hub & Navigation** | 🟢 Done | **100%** | Two-tier layout, persistent navigation shell, quick action chips |
| **03** | **Quran Reading & Audio** | 🟢 Done | **100%** | 114 Surahs, Mushaf/Study view, Mishary audio, single-verse auto-stop |
| **04** | **Dua System & Audio** | 🟢 Done | **100%** | 81 Duas, EveryAyah + Azure Neural Arabic TTS, disk caching |
| **05** | **Hadith System & Audio** | 🟢 Done | **100%** | Bukhari index, text sanitizer, 22 voiced audio chapters |
| **06** | **Persistent Audio Player**| 🟢 Done | **100%** | 2-tier card, speed stepper, 5s skips, track mode toggle |
| **07** | **Digital Tasbih** | 🟢 Done | **100%** | Tap counter, haptic feedback, custom targets, presets |
| **08** | **Pronunciation Studio** | 🟢 Done | **100%** | Groq Whisper Large-v3, sticky top action bar, mistake diagnostics, [বাং/EN] |
| **09** | **Testing & Security** | 🟢 Done | **100%** | 143/143 tests passing, 0 analyzer issues, `.env` gitignored |
| **10** | **Namaz & Prayer Times** | 🟢 Done | **100%** | Offline GPS & 30+ cities, live Waqt, Asr Madhab, Azan previews, Farz/Sunnah tracker, Qaza counter |
| **11** | **Zakat Calculator** | 🟡 Next | **0%** | Multi-asset wealth calculator, live Nisab, recipient guide |
| **12** | **Education & Quiz** | ⚪ Planned | **0%** | Categorized Islamic trivia, timed challenges, score tracking |
| **13** | **Achievements & Streaks**| ⚪ Planned | **0%** | Consistency badges, reading streaks, trophy showcase |
| **14** | **Social Media & Video Feed**| ⚪ Planned | **0%** | Supabase feeds, Janaza alerts, Imam wisdom, distraction-free in-app video reels |
| **15** | **Qibla & Hijri Tools** | ⚪ Planned | **0%** | Magnetometer compass, lunar calendar with Islamic events |
| **16** | **Neki AI Islamic Agent** | ⚪ Planned | **0%** | Function calling navigation agent, RAG Quran/Hadith/Dua QA, voice input |

---

*Last Updated: September 2026 • Maintained for the Neki Development Team*

