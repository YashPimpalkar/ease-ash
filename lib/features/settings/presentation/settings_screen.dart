import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/secure_storage_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import 'ai_models_screen.dart';
import '../../auth/presentation/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final _mongoUriController = TextEditingController();
  final _balanceController = TextEditingController();
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _geminiKeyController.dispose();
    _mongoUriController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(secureStorageServiceProvider);
    final key = await storage.getGroqApiKey() ?? '';
    final geminiKey = await storage.getGeminiApiKey() ?? '';
    final uri = await storage.getMongoDbUri() ?? '';
    
    await ref.read(startingBalanceProvider.notifier).loadStartingBalance();
    final bal = ref.read(startingBalanceProvider);

    setState(() {
      _apiKeyController.text = key;
      _geminiKeyController.text = geminiKey;
      _mongoUriController.text = uri;
      _balanceController.text = bal.toStringAsFixed(2);
      _isLoading = false;
    });
  }

  Future<void> _saveApiKey() async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.saveGroqApiKey(_apiKeyController.text.trim());
    _showSnackBar('Groq API Key saved successfully');
  }

  Future<void> _saveGeminiApiKey() async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.saveGeminiApiKey(_geminiKeyController.text.trim());
    _showSnackBar('Gemini API Key saved successfully');
  }

  Future<void> _saveMongoUri() async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.saveMongoDbUri(_mongoUriController.text.trim());
    _showSnackBar('MongoDB connection details saved');
  }

  Future<void> _saveStartingBalance() async {
    final val = double.tryParse(_balanceController.text) ?? 0.0;
    await ref.read(startingBalanceProvider.notifier).updateStartingBalance(val);
    _showSnackBar('Starting balance configured');
  }

  Future<void> _triggerSync() async {
    setState(() {
      _isSyncing = true;
    });
    final syncService = ref.read(syncServiceProvider);
    final success = await syncService.syncAll();
    setState(() {
      _isSyncing = false;
    });

    if (success) {
      _showSnackBar('Database successfully synchronized with MongoDB!');
    } else {
      _showSnackBar('Sync failed. Check connection parameters and internet.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00E6FF),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E6FF)))
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (isAdmin) ...[
                      Text(
                        'AI Configuration',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        context,
                        title: 'Groq API Models Manager',
                        subtitle: 'Manage priorities, enable/disable & custom models fallback list',
                        icon: Icons.psychology,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AiModelsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Groq API Key',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _apiKeyController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Enter your API key',
                                hintStyle: TextStyle(color: Colors.white24),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _saveApiKey,
                                child: const Text('Save Key'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gemini API Key',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _geminiKeyController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Enter your API key',
                                hintStyle: TextStyle(color: Colors.white24),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _saveGeminiApiKey,
                                child: const Text('Save Key'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Data Synchronisation',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MongoDB Connection URI',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _mongoUriController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText: 'mongodb+srv://user:pass@cluster...',
                                hintStyle: TextStyle(color: Colors.white24),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00E676),
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: _isSyncing ? null : _triggerSync,
                                  icon: _isSyncing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.sync),
                                  label: Text(_isSyncing ? 'Syncing...' : 'Sync Database'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C63FF),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _saveMongoUri,
                                  child: const Text('Save URI'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Personalization',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Initial Account Balance (₹)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _balanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(color: Colors.white24),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E6FF))),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _saveStartingBalance,
                              child: const Text('Save Balance'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Security',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fingerprint / Biometric Login',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Enable fingerprint login',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            subtitle: Text(
                              authState.isBiometricAvailable
                                  ? 'Log in quickly using your device fingerprint scanner'
                                  : 'Biometrics not available or not set up on this device',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            value: authState.isBiometricEnabledForUser,
                            activeColor: const Color(0xFF00E6FF),
                            onChanged: authState.isBiometricAvailable
                                ? (value) async {
                                    final success = await ref
                                        .read(authProvider.notifier)
                                        .toggleBiometrics(value);
                                    if (success) {
                                      _showSnackBar(value
                                          ? 'Fingerprint login enabled successfully'
                                          : 'Fingerprint login disabled');
                                    } else {
                                      _showSnackBar('Failed to update fingerprint settings');
                                    }
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        ref.read(authProvider.notifier).logout();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
          ),
        ),
      );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCardDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF00E6FF), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}
