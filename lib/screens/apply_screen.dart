import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../services/email_service.dart';

class ApplyScreen extends StatefulWidget {
  const ApplyScreen({super.key});

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  List<String> _emails = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(
        () => setState(() => _emails = extractEmails(_controller.text)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) _controller.text = data!.text!.trim();
  }

  Future<void> _send() async {
    final template = store.defaultTemplate;
    if (template == null) {
      _snack('Add an application template first');
      return;
    }
    if (store.defaultResume == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('No resume attached'),
          content: const Text('Send the application without a resume?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Send anyway')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _sending = true);
    try {
      final mode = await EmailService.send(
        store: store,
        recipients: _emails,
        template: template,
        resume: store.defaultResume,
      );
      await store.addHistory(SentRecord(
          to: _emails.join(', '), subject: template.subject, sentAt: DateTime.now()));
      _controller.clear();
      _snack(mode == SendMode.direct
          ? 'Application sent!'
          : 'Opened in mail app — tap send there');
    } catch (e) {
      _snack('Failed to send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
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
      appBar: AppBar(title: const Text('Quick Apply')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final template = store.defaultTemplate;
          final resume = store.defaultResume;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'HR / company email',
                  hintText: 'Paste an email (or the whole job post)',
                  suffixIcon: _controller.text.isEmpty
                      ? IconButton(icon: const Icon(Icons.content_paste), tooltip: 'Paste', onPressed: _paste)
                      : IconButton(icon: const Icon(Icons.clear), onPressed: _controller.clear),
                ),
              ),
              if (_emails.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final e in _emails) Chip(avatar: const Icon(Icons.mail, size: 16), label: Text(e))],
                ),
              ] else if (_controller.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('No valid email found', style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _emails.isEmpty || _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: Text(_sending ? 'Sending...' : 'Send Application', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                store.smtpConfigured
                    ? 'Sends directly from ${store.senderEmail}'
                    : 'Gmail not set up — will open your mail app. Set up in Settings for true 1-tap sending.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              _SummaryTile(
                icon: Icons.description,
                title: template?.name ?? 'No template',
                subtitle: template?.subject ?? 'Add one in Templates',
                onTap: template == null ? null : () => _preview(template),
              ),
              _SummaryTile(
                icon: Icons.picture_as_pdf,
                title: resume?.name ?? 'No resume',
                subtitle: resume == null ? 'Add one in Resumes' : 'Attached resume',
              ),
              if (store.history.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Recently sent', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    TextButton(onPressed: store.clearHistory, child: const Text('Clear')),
                  ],
                ),
                for (final h in store.history.take(20))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                    title: Text(h.to),
                    subtitle: Text('${h.subject} • ${_fmt(h.sentAt)}'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _preview(EmailTemplate t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (c, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text(t.subject, style: Theme.of(c).textTheme.titleMedium),
            const Divider(),
            SelectableText(t.body),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SummaryTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: onTap == null ? null : const Icon(Icons.visibility_outlined),
        onTap: onTap,
      ),
    );
  }
}
