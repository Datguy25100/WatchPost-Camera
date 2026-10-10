import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';

/// People you want the camera to recognise ("Ada, wife"). Photos go to n8n,
/// and edge.py downloads them within about a minute.
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  Future<void> _remove(BuildContext context, PersonModel p) async {
    final ok = await confirmDestructive(
      context,
      title: 'Remove ${p.name}?',
      message: 'The camera will stop recognising ${p.name} and their photos '
          'are deleted from the camera computer.',
      confirmLabel: 'Remove',
    );
    if (ok && context.mounted) context.read<AppState>().deletePerson(p.id);
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddPersonSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final people = context.watch<AppState>().people;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'People',
            subtitle: people.isEmpty
                ? 'Teach the camera who lives here'
                : '${people.length} saved',
            actions: [
              RoundIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Add person',
                filled: true,
                onPressed: () => _openAddSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: people.isEmpty
                ? const SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No people yet',
                      text: 'Tap + and add a few photos. Alerts will then say '
                          '"Your wife, Ada, is at the front door".',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _PersonRow(
                      person: people[i],
                      onRemove: () => _remove(context, people[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onRemove});

  final PersonModel person;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ready = person.enrolled;
    final initial =
        person.name.isEmpty ? '?' : person.name.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.tint,
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(person.relation.isEmpty ? 'Saved person' : person.relation,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: ready ? AppColors.greenBg : AppColors.amberBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ready ? 'Camera knows them' : 'Waiting for camera',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ready ? AppColors.green : AppColors.amber),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

const _relations = <String>[
  'wife',
  'husband',
  'mum',
  'dad',
  'son',
  'daughter',
  'brother',
  'sister',
  'friend',
  'other',
];

const _maxPhotos = 5;
const _maxPhotoBytes = 140 * 1024; // base64 must stay under the server's 200k-char limit

class _AddPersonSheet extends StatefulWidget {
  const _AddPersonSheet();

  @override
  State<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<_AddPersonSheet> {
  final _name = TextEditingController();
  final _otherRelation = TextEditingController();
  final _picker = ImagePicker();
  final List<Uint8List> _photos = [];
  String _relation = 'wife';
  String? _nameError;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _otherRelation.dispose();
    super.dispose();
  }

  Future<void> _addFrom(ImageSource source) async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) return;
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final f = await _picker.pickImage(
            source: source, maxWidth: 640, maxHeight: 640, imageQuality: 65);
        picked = f == null ? [] : [f];
      } else {
        picked = await _picker.pickMultiImage(
            maxWidth: 640, maxHeight: 640, imageQuality: 65);
      }
      var skipped = 0;
      final added = <Uint8List>[];
      for (final f in picked.take(room)) {
        final bytes = await f.readAsBytes();
        if (bytes.length > _maxPhotoBytes) {
          skipped++;
        } else {
          added.add(bytes);
        }
      }
      if (!mounted) return;
      setState(() {
        _photos.addAll(added);
        _error = skipped > 0
            ? '$skipped photo(s) were too large and skipped. Try another.'
            : (picked.length > room ? 'Only $_maxPhotos photos are allowed.' : null);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the photo picker.');
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _addFrom(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _addFrom(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final relation =
        _relation == 'other' ? _otherRelation.text.trim().toLowerCase() : _relation;
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter their name');
      return;
    }
    if (relation.isEmpty) {
      setState(() => _error = 'Say how they are related to you');
      return;
    }
    if (_photos.isEmpty) {
      setState(() => _error = 'Add at least one clear photo of their face');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await context.read<AppState>().addPerson(
          name: name,
          relation: relation,
          photos: [for (final p in _photos) base64Encode(p)],
        );
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Add person',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Name',
              hint: 'e.g. Ada',
              icon: Icons.person_outline_rounded,
              controller: _name,
              error: _nameError,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 16),
            const Text('Relationship',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _relations)
                  ChoiceChip(
                    label: Text(r),
                    selected: _relation == r,
                    onSelected: (_) => setState(() => _relation = r),
                    selectedColor: AppColors.blue,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color: _relation == r ? AppColors.blue : AppColors.border),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _relation == r ? Colors.white : AppColors.muted),
                  ),
              ],
            ),
            if (_relation == 'other') ...[
              const SizedBox(height: 12),
              AppTextField(
                label: 'Relationship (your words)',
                hint: 'e.g. neighbour',
                icon: Icons.favorite_border_rounded,
                controller: _otherRelation,
                textInputAction: TextInputAction.done,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Photos',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${_photos.length}/$_maxPhotos',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '3-5 clear, front-facing photos in different light work best.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_photos[i],
                                width: 72, height: 72, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: _saving
                                  ? null
                                  : () => setState(() => _photos.removeAt(i)),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                    color: AppColors.navy,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_photos.length < _maxPhotos)
                    GestureDetector(
                      onTap: _saving ? null : _chooseSource,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.tint,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.add_a_photo_outlined,
                            color: AppColors.blue),
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
            const SizedBox(height: 20),
            AppButton(
              label: _saving ? 'Uploading…' : 'Save person',
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
