import 'package:flutter_riverpod/flutter_riverpod.dart';

// StateProvider to track the active bottom navigation tab
final navigationIndexProvider = StateProvider<int>((ref) => 0);
