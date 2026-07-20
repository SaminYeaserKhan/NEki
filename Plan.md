# Project Neki: Product & Technical Master Plan

This document serves as the foundational blueprint for developing **Neki**. It outlines the core product features, technical architecture, data sourcing, database schema, and UI/UX guidelines required to build a modern, cross-generational Islamic educational platform.

---

## 1. Executive Summary & Core Identity

**Neki** is a comprehensive, distraction-free Islamic mobile application designed to bridge the gap between modern aesthetics and accessible functionality. It caters to all age groups by pairing a highly intuitive, high-contrast interface with advanced features like real-time Tajweed correction, location-based Janaza alerts, and a parent-child gamified learning environment.

### Core Objectives

- Maintain a **zero-cost development environment**.
- Ensure seamless **accessibility for older demographics** (scalable fonts, clear navigation).
- Implement **cinematic, modern design elements** (Bento grid, fluid animations) to engage younger users.
- Build a **scalable, relational architecture** capable of transitioning into a production-ready startup.

---

## 2. Technical Stack & Infrastructure

| Component              | Technology                          | Rationale                                                                                                          |
|------------------------|-------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| **Frontend Framework** | Flutter (Dart)                      | Single codebase for iOS & Android, exceptional UI rendering, hardware access (mic, GPS), dynamic text scaling.    |
| **State Management**   | Riverpod (`flutter_riverpod ^3.3.1`)| Compile-time safety, async APIs (`FutureProvider`), real-time audio/GPS streams (`StreamProvider`).               |
| **Backend / Database** | Supabase Cloud (PostgreSQL)         | Robust relational data, PostGIS for geolocation (Janaza radius queries), generous free tier for later CLI migration.|
| **Push Notifications** | Firebase Cloud Messaging (FCM)      | Industry standard, 100% free, clean Flutter integration for prayer & Janaza alerts.                               |

### Flutter Package Dependencies (`pubspec.yaml`)

| Package                  | Version    | Purpose                                         | Status      |
|--------------------------|------------|-------------------------------------------------|-------------|
| `flutter_riverpod`       | `^3.3.1`   | State management                                | ✅ Installed |
| `supabase_flutter`       | `^2.12.0`  | Supabase client (auth, DB, realtime)            | ✅ Installed |
| `just_audio`             | `^0.10.5`  | Quran audio streaming with playback controls    | ✅ Installed |
| `quran`                  | `^1.4.1`   | Local Quran text, verse data, and Uthmanic script| ✅ Installed |
| `geolocator`             | `^14.0.2`  | Live GPS coordinates for Aladhan API & Qibla   | ✅ Installed |
| `google_fonts`           | `^8.0.2`   | Modern typography (Inter)                       | ✅ Installed |
| `http`                   | `^1.2.x`   | REST API calls (Aladhan, Hadith, Google STT)    | ⚠️ **TODO: Add** |
| `firebase_messaging`     | `^15.x`    | FCM push notifications                          | ⚠️ **TODO: Add** |
| `speech_to_text`         | `^7.x`     | Microphone input for Tajweed pronunciation      | ⚠️ **TODO: Add** |

> **Note:** The `quran` Flutter package (local data) is used as the primary Quran text source. The Quran.com API v4 may be used supplementally for extended audio streaming URLs not bundled in the package.

---

## 3. External API & Data Sourcing

To keep database storage costs at zero and ensure maximum accuracy, Neki relies on the following external engines:

| Service                     | API / Source                                    | Data Provided                                                               |
|-----------------------------|------------------------------------------------|-----------------------------------------------------------------------------|
| **Quran Text & Audio**      | `quran` Flutter package + Quran.com API (v4)  | Uthmanic script, Bangla/English translations, MP3 streaming URLs            |
| **Hadith Collection**       | Bangla-Hadith GitHub JSON (static)            | Authentic Hadiths with parallel Arabic, English, and Bangla text            |
| **Prayer Times & Qibla**   | [Aladhan API](https://aladhan.com/prayer-times-api) | No-auth GPS-based prayer timings and Mecca compass bearings            |
| **Tajweed Voice Recognition**| Google Cloud Speech-to-Text API (`ar-SA`)    | Arabic transcription of mic input for comparison against Quranic verses     |

---

## 4. Database Schema (Supabase / PostgreSQL)

The database is strictly reserved for **user states, relational logic, and community features**. All static Islamic content (Quran, Hadith) is sourced externally or from local packages.

```sql
-- User accounts and role system
users:           id (UUID PK), full_name, role ('standard'|'moderator'|'parent'|'child'), parent_id (FK → users.id)

-- Reading & listening progress
user_progress:   id, user_id (FK → users), last_surah_read, last_ayah_read, favorite_reciter_id

-- Gamification: parent assigns tasks to child
tasks:           id, assigned_by (FK → users [parent]), assigned_to (FK → users [child]),
                 description, reward_title, status ('pending'|'completed'|'verified')

-- Community: Janaza geolocation alerts
janaza_alerts:   id, reported_by (FK → users), deceased_name,
                 location_coordinates (PostGIS GEOMETRY POINT), janaza_time, mosque_name,
                 status ('pending_moderation'|'active')

-- Community: Islamic discussion forum
forum_posts:     id, author_id (FK → users), title, content, moderation_status ('pending'|'approved'|'rejected')
forum_comments:  id, post_id (FK → forum_posts), author_id (FK → users), content, moderation_status
```

---

## 5. UI/UX Architecture & Accessibility

The interface balances striking modern aesthetics with strict usability protocols.

### Navigation
A persistent **Bottom Navigation Bar** with labeled icons:
`Home` | `Read/Listen` | `Community` | `Family/Profile`

No deep side-drawers — flat navigation only.

### The Bento Grid (Home Screen)
A modular card layout featuring:
- **Hero Card** (large): Next Prayer countdown with time-of-day gradient background.
- **Medium Cards**: "Resume Quran" and "Qibla Compass".
- **Small Quick-Action Modules**: Tasbih counter, Hadith of the Day.

### Accessibility Standards
- Minimum **4.5:1 contrast ratio** for all text elements.
- `FittedBox` and `Text.rich` to support system font scaling up to **150%** without layout breakage.
- Minimum **48×48px touch targets** on all interactive elements.

### Micro-Interactions
- Subtle **2–3% scale-down** tap physics with soft shadow bloom for tactile feedback.
- Seamless **Hero transitions** from Bento cards to full-screen feature views.

---

## 6. Phased Development Roadmap

### ✅ Phase 0: Project Bootstrap *(Complete)*
- [x] Initialize Flutter project (`neki`).
- [x] Configure Riverpod (`ProviderScope` in `main.dart`).
- [x] Set up 4-tab `NavigationBar` shell with `AnimatedSwitcher` transitions.
- [x] Apply `google_fonts` (Inter) and Material 3 theme.

### 🔲 Phase 1: Foundation & Home Screen
- [ ] Add missing packages: `http`, `firebase_messaging`, `speech_to_text`.
- [ ] Set up Supabase Cloud project and define all SQL tables (see Section 4).
- [ ] Build the **Bento Home Screen** with live prayer time Hero Card (Aladhan API + `geolocator`).
- [ ] Build the **Qibla Compass** screen.

### 🔲 Phase 2: Content & Media
- [ ] Integrate the `quran` package for verse display (Uthmanic script + translations).
- [ ] Build the `just_audio` media player with custom playback controls (speed, seek, reciter selection).
- [ ] Implement **user progress saving** to Supabase (`user_progress` table).
- [ ] Integrate the Bangla-Hadith JSON for Hadith of the Day.

### 🔲 Phase 3: Family & Geolocation
- [ ] Build **parent-child role logic** (registration flow, `parent_id` linking).
- [ ] Build the **Task/Reward Dashboard** (gamification UI for parent and child views).
- [ ] Integrate **PostGIS** in Supabase for Janaza alert submission and radius queries.
- [ ] Connect **Firebase Cloud Messaging** for localized prayer and Janaza push notifications.

### 🔲 Phase 4: AI & Moderation
- [ ] Build the **Moderator Dashboard** for approving forum posts and Janaza alerts.
- [ ] Implement **Tajweed Pronunciation Checker** using Google Speech-to-Text (mic → Arabic string → verse comparison).
- [ ] Set up backend script to curate YouTube/Facebook Islamic advice links.
