import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Single source of app state, persisted to SharedPreferences (and secure
/// storage for the Gmail app password).
class AppStore extends ChangeNotifier {
  static const _kTemplates = 'templates';
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
  List<Resume> resumes = [];
  List<SentRecord> history = [];
  String? defaultTemplateId;
  String? defaultResumeId;
  String senderEmail = '';
  String senderName = '';
  String appPassword = '';
  ThemeMode themeMode = ThemeMode.system;

  bool get smtpConfigured => senderEmail.isNotEmpty && appPassword.isNotEmpty;

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

    // Seed the starter template on first launch.
    if (!_prefs.containsKey(_kTemplates)) {
      await saveTemplate(const EmailTemplate(
        id: 'default',
        name: 'Senior Flutter Developer',
        subject: defaultTemplateSubject,
        body: defaultTemplateBody,
      ));
    }
    notifyListeners();
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

  // ---- Templates ----

  Future<void> saveTemplate(EmailTemplate t) async {
    final i = templates.indexWhere((e) => e.id == t.id);
    i >= 0 ? templates[i] = t : templates.add(t);
    await _writeList(_kTemplates, templates);
    if (templates.length == 1) await setDefaultTemplate(t.id);
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    templates.removeWhere((e) => e.id == id);
    await _writeList(_kTemplates, templates);
    notifyListeners();
  }

  Future<void> setDefaultTemplate(String id) async {
    defaultTemplateId = id;
    await _prefs.setString(_kDefaultTemplate, id);
    notifyListeners();
  }

  // ---- Resumes ----

  /// Copies the picked file into app storage so it survives cache clearing.
  Future<void> addResume(Uint8List bytes, String fileName) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/resumes');
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
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _prefs.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  // ---- History ----

  Future<void> addHistory(SentRecord r) async {
    history.insert(0, r);
    if (history.length > 100) history = history.sublist(0, 100);
    await _writeList(_kHistory, history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history.clear();
    await _writeList(_kHistory, history);
    notifyListeners();
  }
}
