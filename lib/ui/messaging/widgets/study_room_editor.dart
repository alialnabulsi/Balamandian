import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/models/academic.dart';
import '../../../domain/models/community.dart';
import '../../community/view_models/community_composer_model.dart';
import '../../community/widgets/community_actions.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/academic_model.dart';
import 'messaging_inbox.dart';
import 'messaging_scope.dart';

class StudyRoomEditor extends StatefulWidget {
  const StudyRoomEditor({super.key});
  @override
  State<StudyRoomEditor> createState() => _StudyRoomEditorState();
}

class _StudyRoomEditorState extends State<StudyRoomEditor> {
  late final model = AcademicModel(
    MessagingScope.of(context, listen: false).session.repository,
  );
  final title = TextEditingController();
  final description = TextEditingController();
  final form = GlobalKey<FormState>();
  final id = AcademicModel.newId();
  AcademicCourse? course;
  Uint8List? photo;
  String? image, type;
  bool busy = false, picking = false;
  double? progress;

  Future<void> selectCourse() async {
    final result = await showModalBottomSheet<AcademicCourse>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AcademicCoursePicker(model: model),
    );
    if (mounted && result != null) setState(() => course = result);
  }

  Future<void> pickPhoto() async {
    if (picking) return;
    setState(() => picking = true);
    await communityCommand(context, () async {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (selected == null || !mounted) return;
      if (await selected.length() > 8000000) {
        throw const CommunityFailure('Choose a photo smaller than 8 MB.');
      }
      final bytes = await selected.readAsBytes();
      final mime = CommunityComposerModel.imageType(bytes);
      if (mime == null) {
        throw const CommunityFailure('Choose a JPEG, PNG or WebP photo.');
      }
      if (mounted) {
        setState(() {
          photo = bytes;
          type = mime;
          image = null;
        });
      }
    });
    if (mounted) setState(() => picking = false);
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    final selection = course;
    if (selection == null) {
      communityFeedback(context, 'Select a course first.');
      return;
    }
    setState(() => busy = true);
    await communityCommand(context, () async {
      if (photo != null && image == null) {
        image = (await model.repository.media.upload(photo!, type!, (value) {
          if (mounted) setState(() => progress = value);
        })).id;
      }
      await model.create(id, selection, title.text, description.text, image);
      if (mounted) context.pushReplacement('/messages/$id');
    });
    if (mounted) {
      setState(() {
        busy = false;
        progress = null;
      });
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New study room')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                children: [
                  Text(
                    'Set up your course space',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Anyone at Balamandian can discover and join the room.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.school_outlined),
                    onPressed: busy ? null : selectCourse,
                    label: Text(
                      course == null
                          ? 'Select a university course'
                          : '${course!.code} · ${course!.name}',
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: title,
                    enabled: !busy,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Room name'),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter a room name.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: description,
                    enabled: !busy,
                    maxLength: 420,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  if (photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(
                        photo!,
                        height: 145,
                        fit: BoxFit.cover,
                        semanticLabel: 'Room photo',
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: busy || picking ? null : pickPhoto,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        photo == null ? 'Add room photo' : 'Change room photo',
                      ),
                    ),
                  ),
                  if (progress != null)
                    LinearProgressIndicator(
                      value: progress,
                      semanticsLabel: 'Uploading room photo',
                    ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: busy || picking ? null : submit,
                    child: Text(busy ? 'Creating room…' : 'Create study room'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AcademicCoursePicker extends StatefulWidget {
  const AcademicCoursePicker({super.key, required this.model});
  final AcademicModel model;
  @override
  State<AcademicCoursePicker> createState() => _AcademicCoursePickerState();
}

class _AcademicCoursePickerState extends State<AcademicCoursePicker> {
  late final listing = widget.model.courses();
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    unawaited(listing.load());
  }

  @override
  void dispose() {
    search.dispose();
    listing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: .86,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'University courses',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: MessagingSearch(
              controller: search,
              label: 'Search courses or departments',
              onChanged: listing.search,
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: listing,
              builder: (context, _) => ListView(
                children: [
                  if (listing.loading && listing.items.isEmpty)
                    const MessagingSkeleton(),
                  if (listing.error != null)
                    ContentState(
                      title: 'Catalog unavailable',
                      message: listing.error.toString(),
                      onRetry: listing.load,
                      compact: true,
                    ),
                  if (!listing.loading &&
                      listing.error == null &&
                      listing.items.isEmpty)
                    const ContentState(
                      title: 'No matching courses',
                      message: 'Try a course code, name or department.',
                      compact: true,
                    ),
                  for (final course in listing.items)
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text('${course.code} · ${course.name}'),
                      subtitle: course.department.isEmpty
                          ? null
                          : Text(course.department),
                      onTap: () => Navigator.pop(context, course),
                    ),
                  if (listing.next != null)
                    TextButton(
                      onPressed: listing.loadingMore
                          ? null
                          : () => listing.load(more: true),
                      child: const Text('Show more courses'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
