import 'package:flutter/material.dart';

import 'package:mailer/smtp_server.dart';

import '../main.dart';
import '../services/email_service.dart';

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
      _snack('Gmail verified — 1-tap sending enabled');
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
      _snack('Failed: ${EmailService.describeError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        ],
      ),
    );
  }
}
