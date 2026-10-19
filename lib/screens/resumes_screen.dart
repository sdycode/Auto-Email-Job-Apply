import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../main.dart';

class ResumesScreen extends StatelessWidget {
  const ResumesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (files.isEmpty) return;
    await store.addResume(await files.first.readAsBytes(), files.first.name);
  }

  Future<void> _delete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove resume?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await store.deleteResume(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resumes')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'resumesFab',
        onPressed: () => _add(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Add resume'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.resumes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No resumes yet.\nAdd a PDF to attach it to every application.', textAlign: TextAlign.center),
              ),
            );
          }
          final defaultId = store.defaultResume?.id;
          return RadioGroup<String>(
            groupValue: defaultId,
            onChanged: (id) => store.setDefaultResume(id!),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final r in store.resumes)
                  ListTile(
                    leading: Radio<String>(value: r.id),
                    title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: r.id == defaultId ? const Text('Default') : null,
                    onTap: () => OpenFilex.open(r.path),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, r.id),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
