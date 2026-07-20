import 'package:flutter_riverpod/legacy.dart';

/// Active bottom-nav tab index (0=Home, 1=Recitations, 2=Social, 3=Profile).
final navigationIndexProvider = StateProvider<int>((ref) => 0);

/// Which sub-tab is active in the Recitations screen (0=Quran, 1=Dua, 2=Hadith).
final recitationsTabProvider = StateProvider<int>((ref) => 0);
