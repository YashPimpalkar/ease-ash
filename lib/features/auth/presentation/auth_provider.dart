import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import '../../../core/database/secure_storage_service.dart';

enum AuthStatus { authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? role;
  final String? error;
  final bool isBiometricAvailable;
  final bool isBiometricEnabledForUser;

  AuthState({
    required this.status,
    this.email,
    this.role,
    this.error,
    this.isBiometricAvailable = false,
    this.isBiometricEnabledForUser = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? role,
    String? error,
    bool? isBiometricAvailable,
    bool? isBiometricEnabledForUser,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      role: role ?? this.role,
      error: error ?? this.error,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
      isBiometricEnabledForUser: isBiometricEnabledForUser ?? this.isBiometricEnabledForUser,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SecureStorageService _storage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  AuthNotifier(this._storage) : super(AuthState(status: AuthStatus.unauthenticated)) {
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    try {
      final email = await _storage.getCurrentUserEmail();
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final bool isBioAvailable = canAuthenticateWithBiometrics && isDeviceSupported;

      if (email != null && email.isNotEmpty) {
        String role = 'user';
        if (email.toLowerCase() == 'yashpimpalkar214@gmail.com') {
          role = 'admin';
        } else {
          role = await _storage.getUserRole(email) ?? 'user';
        }

        final isBioEnabled = await _storage.isBiometricEnabled(email);

        state = AuthState(
          status: AuthStatus.authenticated,
          email: email,
          role: role,
          isBiometricAvailable: isBioAvailable,
          isBiometricEnabledForUser: isBioEnabled,
        );
      } else {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          isBiometricAvailable: isBioAvailable,
        );
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(error: null);
    final cleanEmail = email.trim().toLowerCase();
    
    if (cleanEmail.isEmpty || password.trim().isEmpty) {
      state = state.copyWith(error: 'Email and password cannot be empty');
      return false;
    }

    try {
      if (cleanEmail == 'yashpimpalkar214@gmail.com') {
        if (password == 'Yash##786') {
          await _storage.saveCurrentUserEmail(cleanEmail);
          await _storage.saveUserRole(cleanEmail, 'admin');
          final isBioEnabled = await _storage.isBiometricEnabled(cleanEmail);
          
          state = state.copyWith(
            status: AuthStatus.authenticated,
            email: cleanEmail,
            role: 'admin',
            isBiometricEnabledForUser: isBioEnabled,
          );
          return true;
        } else {
          state = state.copyWith(error: 'Invalid email or password');
          return false;
        }
      }

      // Normal user lookup
      final storedHash = await _storage.getUserPasswordHash(cleanEmail);
      if (storedHash == null) {
        state = state.copyWith(error: 'User account does not exist');
        return false;
      }

      final enteredHash = sha256.convert(utf8.encode(password)).toString();
      if (storedHash == enteredHash) {
        await _storage.saveCurrentUserEmail(cleanEmail);
        final role = await _storage.getUserRole(cleanEmail) ?? 'user';
        final isBioEnabled = await _storage.isBiometricEnabled(cleanEmail);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          email: cleanEmail,
          role: role,
          isBiometricEnabledForUser: isBioEnabled,
        );
        return true;
      } else {
        state = state.copyWith(error: 'Invalid email or password');
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Authentication failed: $e');
      return false;
    }
  }

  Future<bool> signup(String email, String password) async {
    state = state.copyWith(error: null);
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || password.trim().isEmpty) {
      state = state.copyWith(error: 'Email and password cannot be empty');
      return false;
    }

    if (cleanEmail == 'yashpimpalkar214@gmail.com') {
      state = state.copyWith(error: 'Admin account cannot be re-registered');
      return false;
    }

    if (password.length < 6) {
      state = state.copyWith(error: 'Password must be at least 6 characters long');
      return false;
    }

    try {
      final existingHash = await _storage.getUserPasswordHash(cleanEmail);
      if (existingHash != null) {
        state = state.copyWith(error: 'User already exists with this email');
        return false;
      }

      final hash = sha256.convert(utf8.encode(password)).toString();
      await _storage.saveUserPasswordHash(cleanEmail, hash);
      await _storage.saveUserRole(cleanEmail, 'user');
      await _storage.saveCurrentUserEmail(cleanEmail);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        email: cleanEmail,
        role: 'user',
        isBiometricEnabledForUser: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Sign up failed: $e');
      return false;
    }
  }

  Future<bool> loginWithBiometrics() async {
    state = state.copyWith(error: null);
    
    try {
      final bioUser = await _storage.getBiometricUserEmail();
      if (bioUser == null || bioUser.isEmpty) {
        state = state.copyWith(error: 'Biometric login is not configured');
        return false;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Ease Ash',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        await _storage.saveCurrentUserEmail(bioUser);
        String role = 'user';
        if (bioUser.toLowerCase() == 'yashpimpalkar214@gmail.com') {
          role = 'admin';
        } else {
          role = await _storage.getUserRole(bioUser) ?? 'user';
        }

        state = state.copyWith(
          status: AuthStatus.authenticated,
          email: bioUser,
          role: role,
          isBiometricEnabledForUser: true,
        );
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      state = state.copyWith(error: 'Biometric error: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Biometric login failed');
      return false;
    }
  }

  Future<bool> toggleBiometrics(bool enable) async {
    final currentUser = state.email;
    if (currentUser == null) return false;

    try {
      if (enable) {
        // Authenticate user to verify biometrics are active before enabling
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Confirm fingerprint to enable biometric login',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (didAuthenticate) {
          await _storage.saveBiometricEnabled(currentUser, true);
          await _storage.saveBiometricUserEmail(currentUser);
          state = state.copyWith(isBiometricEnabledForUser: true);
          return true;
        }
        return false;
      } else {
        await _storage.saveBiometricEnabled(currentUser, false);
        final bioUser = await _storage.getBiometricUserEmail();
        if (bioUser == currentUser) {
          await _storage.saveBiometricUserEmail(null);
        }
        state = state.copyWith(isBiometricEnabledForUser: false);
        return true;
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to configure biometrics');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _storage.saveCurrentUserEmail(null);
      state = AuthState(
        status: AuthStatus.unauthenticated,
        isBiometricAvailable: state.isBiometricAvailable,
      );
    } catch (e) {
      state = state.copyWith(error: 'Logout failed');
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return AuthNotifier(storage);
});
