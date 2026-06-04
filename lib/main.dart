import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/database/database_service.dart';
import 'core/database/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Database
  final databaseService = await DatabaseService.init();

  // Initialize Secure storage configs
  final secureStorage = SecureStorageService();
  await secureStorage.initDefaults();

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(databaseService),
      ],
      child: const EaseAshApp(),
    ),
  );
}

class EaseAshApp extends StatelessWidget {
  const EaseAshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ease ash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const NavigationShell(),
    );
  }
}
