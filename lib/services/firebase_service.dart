import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';

/// Service to sync app data with Firebase Realtime Database without Firebase Auth.
/// Uses the verified Gmail address as the primary key path: `/$encodedEmail/`.
class FirebaseService {
  static FirebaseDatabase? _database;
  static bool _initialized = false;
  static String? _configuredDatabaseUrl;

  /// Default RTDB URL for the project 'quick-sent-email'.
  static const String defaultDatabaseUrl =
      'https://quick-sent-email-default-rtdb.firebaseio.com';

  /// Sanitizes an email for use as a Firebase Realtime Database path key.
  /// Firebase keys cannot contain '.', '#', '$', '[', or ']'.
  static String emailToKey(String email) {
    return email.trim().toLowerCase().replaceAll('.', '_');
  }

  /// Initialize Firebase and Realtime Database with local offline persistence.
  static Future<void> init({String? databaseUrl}) async {
    try {
      await Firebase.initializeApp();
      _configuredDatabaseUrl = databaseUrl;
      _initDatabase(databaseUrl);
      _initialized = true;
    } catch (e) {
      debugPrint('FirebaseService.init error: $e');
    }
  }

  static void _initDatabase(String? databaseUrl) {
    try {
      if (databaseUrl != null && databaseUrl.trim().isNotEmpty) {
        _database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: databaseUrl.trim(),
        );
      } else {
        // Try default instance first, falling back to defaultDatabaseUrl
        try {
          _database = FirebaseDatabase.instance;
        } catch (_) {
          _database = FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: defaultDatabaseUrl,
          );
        }
      }
      _database?.setPersistenceEnabled(true);
    } catch (e) {
      debugPrint('FirebaseDatabase setup error: $e');
      try {
        _database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: defaultDatabaseUrl,
        );
        _database?.setPersistenceEnabled(true);
      } catch (err) {
        debugPrint('FirebaseDatabase fallback error: $err');
      }
    }
  }

  static FirebaseDatabase? get database {
    if (_database == null && _initialized) {
      _initDatabase(_configuredDatabaseUrl);
    }
    return _database;
  }

  static DatabaseReference? _userRef(String email) {
    final db = database;
    if (db == null || email.trim().isEmpty) return null;
    final key = emailToKey(email);
    return db.ref(key);
  }

  /// Save or update a single template in Firebase Realtime Database
  static Future<void> saveTemplate(String email, EmailTemplate template) async {
    final ref = _userRef(email);
    if (ref == null) return;
    try {
      await ref.child('templates/${template.id}').set(template.toJson());
      await ref.child('updatedAt').set(DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Firebase saveTemplate error: $e');
    }
  }

  /// Delete a template in Firebase
  static Future<void> deleteTemplate(String email, String templateId) async {
    final ref = _userRef(email);
    if (ref == null) return;
    try {
      await ref.child('templates/$templateId').remove();
      await ref.child('updatedAt').set(DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Firebase deleteTemplate error: $e');
    }
  }

  /// Save default template ID
  static Future<void> setDefaultTemplate(String email, String templateId) async {
    final ref = _userRef(email);
    if (ref == null) return;
    try {
      await ref.child('defaultTemplateId').set(templateId);
    } catch (e) {
      debugPrint('Firebase setDefaultTemplate error: $e');
    }
  }

  /// Save or update a cover letter in Firebase Realtime Database
  static Future<void> saveCoverLetter(String email, CoverLetter letter) async {
    final ref = _userRef(email);
    if (ref == null) return;
    try {
      await ref.child('coverLetters/${letter.id}').set(letter.toJson());
      await ref.child('updatedAt').set(DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Firebase saveCoverLetter error: $e');
    }
  }

  /// Delete a cover letter in Firebase
  static Future<void> deleteCoverLetter(String email, String letterId) async {
    final ref = _userRef(email);
    if (ref == null) return;
    try {
      await ref.child('coverLetters/$letterId').remove();
      await ref.child('updatedAt').set(DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Firebase deleteCoverLetter error: $e');
    }
  }

  /// Save a sent email record to history in Firebase
  static Future<void> saveHistoryRecord(String email, SentRecord record) async {
    final ref = _userRef(email);
    if (ref == null) return;
    try {
      await ref.child('history/${record.id}').set(record.toJson());
      await ref.child('updatedAt').set(DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Firebase saveHistoryRecord error: $e');
    }
  }

  /// Clear history in Firebase
  static Future<void> clearHistory(String email) async {
    final ref = _userRef(email);
    if (ref == null) return;
    try {
      await ref.child('history').remove();
      await ref.child('updatedAt').set(DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Firebase clearHistory error: $e');
    }
  }

  /// Pull all data for the user from Firebase
  static Future<Map<String, dynamic>?> fetchUserData(String email) async {
    final ref = _userRef(email);
    if (ref == null) return null;
    try {
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value != null) {
        return _deepConvert(snapshot.value);
      }
    } catch (e) {
      debugPrint('Firebase fetchUserData error: $e');
    }
    return null;
  }

  /// Push all local state to Firebase under `/$encodedEmail/`
  static Future<void> pushAllData(
    String email, {
    required List<EmailTemplate> templates,
    required List<CoverLetter> coverLetters,
    required List<SentRecord> history,
    String? defaultTemplateId,
  }) async {
    final ref = _userRef(email);
    if (ref == null) return;
    try {
      final Map<String, dynamic> templatesMap = {
        for (final t in templates) t.id: t.toJson()
      };
      final Map<String, dynamic> coverLettersMap = {
        for (final c in coverLetters) c.id: c.toJson()
      };
      final Map<String, dynamic> historyMap = {
        for (final h in history) h.id: h.toJson()
      };

      await ref.update({
        'email': email,
        'templates': templatesMap,
        'coverLetters': coverLettersMap,
        'history': historyMap,
        'defaultTemplateId': ?defaultTemplateId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Firebase pushAllData error: $e');
    }
  }

  /// Converts nested Object? maps/lists from Firebase snapshot to strongly-typed `Map<String, dynamic>`
  static Map<String, dynamic>? _deepConvert(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convertValue(v)));
    }
    return null;
  }

  static dynamic _convertValue(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convertValue(v)));
    } else if (value is List) {
      return value.map(_convertValue).toList();
    }
    return value;
  }
}
