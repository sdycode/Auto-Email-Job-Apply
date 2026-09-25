import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../services/app_store.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  void _edit(BuildContext context, [EmailTemplate? t]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditor(template: t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Templates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('New template'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.templates.isEmpty) {
            return const Center(child: Text('No templates yet'));
          }
          final defaultId = store.defaultTemplate?.id;
          return RadioGroup<String>(
            groupValue: defaultId,
            onChanged: (id) => store.setDefaultTemplate(id!),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final t in store.templates)
                  ListTile(
                    leading: Radio<String>(value: t.id),
                    title: Text(t.name),
                    subtitle: Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _edit(context, t),
                    trailing: t.id == defaultId
                        ? const Chip(label: Text('Default'), visualDensity: VisualDensity.compact)
                        : null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TemplateEditor extends StatefulWidget {
  final EmailTemplate? template;

  const TemplateEditor({super.key, this.template});

  @override
  State<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<TemplateEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.template?.name);
  late final _subject = TextEditingController(text: widget.template?.subject);
  late final _body = TextEditingController(text: widget.template?.body);

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await store.saveTemplate(EmailTemplate(
      id: widget.template?.id ?? AppStore.newId(),
      name: _name.text.trim(),
      subject: _subject.text.trim(),
      body: _body.text.trim(),
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete template?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await store.deleteTemplate(widget.template!.id);
    if (mounted) Navigator.pop(context);
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.template != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit template' : 'New template'),
        actions: [
          if (editing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Template name', hintText: 'e.g. Senior Flutter Dev'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Email subject'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              decoration: const InputDecoration(labelText: 'Email body', alignLabelWithHint: true),
              minLines: 12,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              validator: _required,
            ),
          ],
        ),
      ),
    );
  }
}
