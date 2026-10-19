import 'package:flutter/material.dart';

import 'package:mailer/smtp_server.dart';

import '../main.dart';
import '../services/email_service.dart';
import '../services/firebase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _email = TextEditingController(text: store.senderEmail);
  late final _name = TextEditingController(text: store.senderName);
  late final _password = TextEditingController(text: store.appPassword);
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final password = _password.text.replaceAll(' ', '');
    if (email.isEmpty && password.isEmpty) {
      await store.saveSmtp('', _name.text, '');
      _snack('Saved — will use mail app');
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      _snack('Enter both Gmail address and App Password');
      return;
    }
    await _run(() async {
      await EmailService.verifyGmail(email, password);
      await store.saveSmtp(email, _name.text, password);
      _snack('Gmail verified — 1-tap sending & Firebase sync enabled');
    });
  }

  Future<void> _sendTest() async {
    await _run(() async {
      await EmailService.sendViaSmtp(
        server: gmail(store.senderEmail, store.appPassword),
        fromEmail: store.senderEmail,
        fromName: store.senderName,
        recipients: [store.senderEmail],
        subject: 'Quick Apply test email',
        body: 'Direct sending from Quick Apply works.',
        resume: store.defaultResume,
      );
      _snack('Test email sent to ${store.senderEmail}');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) await _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showError(Object e) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Gmail verification failed'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(EmailService.describeError(e)),
                const SizedBox(height: 16),
                Text('Details', style: Theme.of(c).textTheme.labelLarge),
                SelectableText('$e', style: Theme.of(c).textTheme.bodySmall),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _fmtTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('System')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (s) => store.setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: 24),
          Text('Gmail sending (1-tap)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'To send without opening any other app, enter your Gmail address and a Gmail App Password '
            '(Google Account → Security → 2-Step Verification → App passwords). '
            'Your normal Gmail password will not work. Leave empty to use your phone\'s mail app instead.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Your Gmail address', prefixIcon: Icon(Icons.alternate_email)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Sender name (optional)', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Gmail App Password',
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.verified_user_outlined),
            label: const Text('Verify & Save'),
          ),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => store.smtpConfigured
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _sendTest,
                      icon: const Icon(Icons.outgoing_mail),
                      label: const Text('Send test email to myself'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          Text('Firebase Realtime Database', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final configured = store.senderEmail.isNotEmpty;
              final emailKey = configured ? FirebaseService.emailToKey(store.senderEmail) : null;
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            configured ? Icons.cloud_done : Icons.cloud_off,
                            color: configured ? Colors.green : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              configured ? 'Connected & Synced' : 'Not Connected',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (store.isSyncing)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        configured
                            ? 'Primary key path: /$emailKey/\nStores: Templates, Cover letters, Mail sent history with status'
                            : 'Verify your Gmail address above to activate Firebase Realtime Database cloud sync.',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (configured) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (store.lastSyncedAt != null)
                              Text(
                                'Last synced: ${_fmtTime(store.lastSyncedAt!)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const Spacer(),
                            FilledButton.tonalIcon(
                              onPressed: store.isSyncing
                                  ? null
                                  : () async {
                                      await store.syncWithFirebase();
                                      _snack('Synced with Firebase!');
                                    },
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('Sync Now'),
                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

