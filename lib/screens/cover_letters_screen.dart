import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../services/app_store.dart';
import '../widgets/verification_banner.dart';

class CoverLettersScreen extends StatefulWidget {
  const CoverLettersScreen({super.key});

  @override
  State<CoverLettersScreen> createState() => _CoverLettersScreenState();
}

class _CoverLettersScreenState extends State<CoverLettersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditor(BuildContext context, [CoverLetter? letter]) {
    if (!store.isEmailVerified) {
      showVerificationRequiredDialog(
        context,
        title: 'Email Verification Required',
        message:
            'You must verify your Gmail in Settings before adding or editing cover letters so they can be saved to your database account.',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoverLetterEditor(letter: letter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cover Letters'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'coverLettersFab',
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('New cover letter'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final letters = store.coverLetters.where((l) {
            if (_searchQuery.isEmpty) return true;
            return l.title.toLowerCase().contains(_searchQuery) ||
                l.content.toLowerCase().contains(_searchQuery);
          }).toList();

          if (store.coverLetters.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No cover letters saved yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add cover letters with title and text to easily read, expand, copy, and use anytime.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Cover Letter'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 96, top: 8),
            children: [
              if (!store.isEmailVerified)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: VerificationRequiredBanner(
                    message:
                        'Verify your Gmail in Settings before adding or editing cover letters. Data saving requires email verification.',
                  ),
                ),
              if (store.coverLetters.length > 2 || _searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search cover letters...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _searchController.clear,
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (letters.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No matching cover letters found')),
                )
              else
                for (final letter in letters)
                  CoverLetterCard(
                    key: ValueKey(letter.id),
                    letter: letter,
                    onEdit: () => _openEditor(context, letter),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class CoverLetterCard extends StatefulWidget {
  final CoverLetter letter;
  final VoidCallback onEdit;

  const CoverLetterCard({
    super.key,
    required this.letter,
    required this.onEdit,
  });

  @override
  State<CoverLetterCard> createState() => _CoverLetterCardState();
}

class _CoverLetterCardState extends State<CoverLetterCard> {
  bool _isExpanded = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.letter.content));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Copied "${widget.letter.title}" to clipboard!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int _getWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letter = widget.letter;
    final wordCount = _getWordCount(letter.content);
    final isLong = letter.content.length > 250 || letter.content.contains('\n\n');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Action buttons (Copy + Edit)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        letter.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$wordCount words • ${letter.content.length} chars',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Prominent Copy Button (as specifically requested)
                FilledButton.tonalIcon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: 4),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit cover letter',
                  onPressed: widget.onEdit,
                ),
              ],
            ),
            const Divider(height: 20),

            // Content section: visible 5-6 lines when collapsed, or full text when expanded
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? SelectableText(
                      letter.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                    )
                  : Text(
                      letter.content,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                    ),
            ),

            // Expand / Collapse toggle button ("Read more / See all")
            if (isLong) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    icon: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _isExpanded ? 'Show less' : 'Read more / See all',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if (_isExpanded)
                    TextButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy full text'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CoverLetterEditor extends StatefulWidget {
  final CoverLetter? letter;

  const CoverLetterEditor({super.key, this.letter});

  @override
  State<CoverLetterEditor> createState() => _CoverLetterEditorState();
}

class _CoverLetterEditorState extends State<CoverLetterEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.letter?.title);
  late final TextEditingController _content =
      TextEditingController(text: widget.letter?.content);

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        if (_content.text.isEmpty) {
          _content.text = data.text!.trim();
        } else {
          _content.text = '${_content.text}\n\n${data.text!.trim()}';
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted from clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _copyContent() {
    if (_content.text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _content.text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied content to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _save() async {
    if (!store.isEmailVerified) {
      showVerificationRequiredDialog(
        context,
        title: 'Email Verification Required',
        message:
            'You cannot save cover letters until your email is verified in Settings.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final letter = CoverLetter(
      id: widget.letter?.id ?? AppStore.newId(),
      title: _title.text.trim(),
      content: _content.text.trim(),
      updatedAt: DateTime.now(),
    );
    await store.saveCoverLetter(letter);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete cover letter?'),
        content: Text('Are you sure you want to delete "${widget.letter?.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.deleteCoverLetter(widget.letter!.id);
    if (mounted) Navigator.pop(context);
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.letter != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit Cover Letter' : 'New Cover Letter'),
        actions: [
          if (editing) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy content',
              onPressed: _copyContent,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Cover letter title',
                hintText: 'e.g. Senior Flutter Developer, Frontend Pitch',
                prefixIcon: Icon(Icons.title),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Cover letter content',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste, size: 16),
                  label: const Text('Paste'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _content,
              decoration: const InputDecoration(
                hintText: 'Write or paste your cover letter text here...',
                alignLabelWithHint: true,
              ),
              minLines: 14,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              validator: _required,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(editing ? 'Save Changes' : 'Save Cover Letter'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
