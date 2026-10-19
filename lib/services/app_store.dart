import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'firebase_service.dart';

/// Single source of app state, persisted to SharedPreferences (and secure
/// storage for the Gmail app password), and synced to Firebase Realtime Database
/// under the user's verified Gmail key (`/$encodedEmail/`).
class AppStore extends ChangeNotifier {
  static const _kTemplates = 'templates';
  static const _kCoverLetters = 'coverLetters';
  static const _kResumes = 'resumes';
  static const _kDefaultTemplate = 'defaultTemplateId';
  static const _kDefaultResume = 'defaultResumeId';
  static const _kHistory = 'history';
  static const _kSenderEmail = 'senderEmail';
  static const _kSenderName = 'senderName';
  static const _kAppPassword = 'appPassword';
  static const _kThemeMode = 'themeMode';

  late SharedPreferences _prefs;
  final _secure = const FlutterSecureStorage();

  List<EmailTemplate> templates = [];
  List<CoverLetter> coverLetters = [];
  List<Resume> resumes = [];
  List<SentRecord> history = [];
  String? defaultTemplateId;
  String? defaultResumeId;
  String senderEmail = '';
  String senderName = '';
  String appPassword = '';
  ThemeMode themeMode = ThemeMode.system;

  bool isSyncing = false;
  DateTime? lastSyncedAt;
  String? syncStatusMessage;

  bool get smtpConfigured => senderEmail.isNotEmpty && appPassword.isNotEmpty;

  bool get isEmailVerified => smtpConfigured;

  EmailTemplate? get defaultTemplate =>
      _byId(templates, defaultTemplateId, (t) => t.id);

  Resume? get defaultResume => _byId(resumes, defaultResumeId, (r) => r.id);

  static T? _byId<T>(List<T> items, String? id, String Function(T) getId) {
    if (items.isEmpty) return null;
    return items.firstWhere((e) => getId(e) == id, orElse: () => items.first);
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    templates = _readList(_kTemplates, EmailTemplate.fromJson);
    coverLetters = _readList(_kCoverLetters, CoverLetter.fromJson);
    resumes = _readList(_kResumes, Resume.fromJson);
    history = _readList(_kHistory, SentRecord.fromJson);
    defaultTemplateId = _prefs.getString(_kDefaultTemplate);
    defaultResumeId = _prefs.getString(_kDefaultResume);
    senderEmail = _prefs.getString(_kSenderEmail) ?? '';
    senderName = _prefs.getString(_kSenderName) ?? '';
    appPassword = await _secure.read(key: _kAppPassword) ?? '';
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_kThemeMode),
      orElse: () => ThemeMode.system,
    );

    // Seed starter template on first launch if empty.
    if (!_prefs.containsKey(_kTemplates)) {
      await saveTemplate(
        const EmailTemplate(
          id: 'default',
          name: 'Senior Flutter Developer',
          subject: defaultTemplateSubject,
          body: defaultTemplateBody,
        ),
        allowUnverified: true,
      );
    }

    // Seed starter cover letter on first launch if empty.
    if (!_prefs.containsKey(_kCoverLetters)) {
      await saveCoverLetter(
        CoverLetter(
          id: 'default_cover_letter',
          title: defaultCoverLetterTitle,
          content: defaultCoverLetterBody,
          updatedAt: DateTime.now(),
        ),
        allowUnverified: true,
      );
    }

    notifyListeners();

    // If email is already verified/saved, sync with Firebase in background
    if (senderEmail.isNotEmpty) {
      unawaited(syncWithFirebase(silent: true));
    }
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeList(String key, List<dynamic> items) =>
      _prefs.setString(key, jsonEncode(items.map((e) => e.toJson()).toList()));

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ---- Firebase Cloud Sync ----

  Future<void> syncWithFirebase({bool silent = false}) async {
    if (senderEmail.isEmpty) return;
    isSyncing = true;
    if (!silent) notifyListeners();

    try {
      final remoteData = await FirebaseService.fetchUserData(senderEmail);
      if (remoteData != null) {
        // Sync templates
        if (remoteData['templates'] is Map) {
          final remoteMap = remoteData['templates'] as Map;
          final remoteTemplates = remoteMap.values
              .map((e) =>
                  EmailTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (remoteTemplates.isNotEmpty) {
            templates = remoteTemplates;
            await _writeList(_kTemplates, templates);
          }
        }

        // Sync cover letters
        if (remoteData['coverLetters'] is Map) {
          final remoteMap = remoteData['coverLetters'] as Map;
          final remoteCoverLetters = remoteMap.values
              .map((e) =>
                  CoverLetter.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (remoteCoverLetters.isNotEmpty) {
            coverLetters = remoteCoverLetters;
            await _writeList(_kCoverLetters, coverLetters);
          }
        }

        // Sync history
        if (remoteData['history'] is Map) {
          final remoteMap = remoteData['history'] as Map;
          final remoteHistory = remoteMap.values
              .map((e) =>
                  SentRecord.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
            ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
          if (remoteHistory.isNotEmpty) {
            history = remoteHistory;
            await _writeList(_kHistory, history);
          }
        }

        // Sync default template ID
        if (remoteData['defaultTemplateId'] is String) {
          defaultTemplateId = remoteData['defaultTemplateId'] as String;
          await _prefs.setString(_kDefaultTemplate, defaultTemplateId!);
        }

        // Push any local items to Firebase to keep both fully in sync
        await FirebaseService.pushAllData(
          senderEmail,
          templates: templates,
          coverLetters: coverLetters,
          history: history,
          defaultTemplateId: defaultTemplateId,
        );
      } else {
        // Initial sync: push all local data to Firebase
        await FirebaseService.pushAllData(
          senderEmail,
          templates: templates,
          coverLetters: coverLetters,
          history: history,
          defaultTemplateId: defaultTemplateId,
        );
      }
      lastSyncedAt = DateTime.now();
      syncStatusMessage = 'Synced with Firebase';
    } catch (e) {
      debugPrint('Sync with Firebase error: $e');
      syncStatusMessage = 'Sync error: $e';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  // ---- Templates ----

  Future<bool> saveTemplate(EmailTemplate t, {bool allowUnverified = false}) async {
    if (!isEmailVerified && !allowUnverified) {
      return false;
    }
    final i = templates.indexWhere((e) => e.id == t.id);
    i >= 0 ? templates[i] = t : templates.add(t);
    await _writeList(_kTemplates, templates);
    if (templates.length == 1) await setDefaultTemplate(t.id);
    notifyListeners();

    if (senderEmail.isNotEmpty) {
      unawaited(FirebaseService.saveTemplate(senderEmail, t));
    }
    return true;
  }

  Future<void> deleteTemplate(String id) async {
    templates.removeWhere((e) => e.id == id);
    await _writeList(_kTemplates, templates);
    notifyListeners();

    if (senderEmail.isNotEmpty) {
      unawaited(FirebaseService.deleteTemplate(senderEmail, id));
    }
  }

  Future<void> setDefaultTemplate(String id) async {
    defaultTemplateId = id;
    await _prefs.setString(_kDefaultTemplate, id);
    notifyListeners();

    if (senderEmail.isNotEmpty) {
      unawaited(FirebaseService.setDefaultTemplate(senderEmail, id));
    }
  }

  // ---- Cover Letters ----

  Future<bool> saveCoverLetter(CoverLetter letter, {bool allowUnverified = false}) async {
    if (!isEmailVerified && !allowUnverified) {
      return false;
    }
    final i = coverLetters.indexWhere((e) => e.id == letter.id);
    if (i >= 0) {
      coverLetters[i] = letter;
    } else {
      coverLetters.insert(0, letter);
    }
    await _writeList(_kCoverLetters, coverLetters);
    notifyListeners();

    if (senderEmail.isNotEmpty) {
      unawaited(FirebaseService.saveCoverLetter(senderEmail, letter));
    }
    return true;
  }

  Future<void> deleteCoverLetter(String id) async {
    coverLetters.removeWhere((e) => e.id == id);
    await _writeList(_kCoverLetters, coverLetters);
    notifyListeners();

    if (senderEmail.isNotEmpty) {
      unawaited(FirebaseService.deleteCoverLetter(senderEmail, id));
    }
  }

  // ---- Resumes (local storage only, as requested) ----

  /// Copies the picked file into app storage so it survives cache clearing.
  Future<void> addResume(Uint8List bytes, String fileName) async {
    final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/resumes');
    await dir.create(recursive: true);
    final id = newId();
    final dest = await File('${dir.path}/${id}_$fileName').writeAsBytes(bytes);
    resumes.add(Resume(id: id, name: fileName, path: dest.path));
    await _writeList(_kResumes, resumes);
    if (resumes.length == 1) await setDefaultResume(id);
    notifyListeners();
  }

  Future<void> deleteResume(String id) async {
    final r = resumes.firstWhere((e) => e.id == id);
    final f = File(r.path);
    if (await f.exists()) await f.delete();
    resumes.removeWhere((e) => e.id == id);
    await _writeList(_kResumes, resumes);
    notifyListeners();
  }

  Future<void> setDefaultResume(String id) async {
    defaultResumeId = id;
    await _prefs.setString(_kDefaultResume, id);
    notifyListeners();
  }

  // ---- Settings ----

  Future<void> saveSmtp(String email, String name, String password) async {
    senderEmail = email.trim();
    senderName = name.trim();
    appPassword = password.replaceAll(' ', '');
    await _prefs.setString(_kSenderEmail, senderEmail);
    await _prefs.setString(_kSenderName, senderName);
    await _secure.write(key: _kAppPassword, value: appPassword);
    notifyListeners();

    if (senderEmail.isNotEmpty) {
      unawaited(syncWithFirebase());
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _prefs.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  // ---- History ----

  Future<bool> addHistory(SentRecord r) async {
    if (!isEmailVerified) return false;
    history.insert(0, r);
    if (history.length > 100) history = history.sublist(0, 100);
    await _writeList(_kHistory, history);
    notifyListeners();

    if (senderEmail.isNotEmpty) {
      unawaited(FirebaseService.saveHistoryRecord(senderEmail, r));
    }
    return true;
  }

  Future<void> clearHistory() async {
    history.clear();
    await _writeList(_kHistory, history);
    notifyListeners();

    if (senderEmail.isNotEmpty) {
      unawaited(FirebaseService.clearHistory(senderEmail));
    }
  }
}
