import 'package:flutter/material.dart';

import '../main.dart';

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

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await store.saveSmtp(_email.text, _name.text, _password.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(store.smtpConfigured ? 'Saved — 1-tap sending enabled' : 'Saved — will use mail app'),
    ));
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
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
