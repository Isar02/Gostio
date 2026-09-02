import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/models/image_upload.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/validation/image_rules.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/api_image.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../data/news_draft.dart';
import '../data/news_item.dart';
import 'news_detail_notifier.dart';
import 'news_picture_field.dart';

class NewsForm extends StatefulWidget {
  const NewsForm({
    required this.notifier,
    required this.onSaved,
    required this.onDeleted,
    super.key,
  });

  final NewsDetailNotifier notifier;
  final ValueChanged<NewsItem> onSaved;
  final ValueChanged<NewsItem> onDeleted;

  static const String nothingChanged = 'Nothing has changed.';

  @override
  State<NewsForm> createState() => _NewsFormState();
}

class _NewsFormState extends State<NewsForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  ImageUpload? _picture;

  // A picture cannot fault itself through Form.
  String? _pictureFault;

  @override
  void initState() {
    super.initState();

    if (widget.notifier.item case final NewsItem article) {
      _title.text = article.title;
      _body.text = article.body;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NewsDetailNotifier notifier = widget.notifier;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (notifier.writeFailureMessage
                case final String message) ...<Widget>[
              AppNotice(message),
              const SizedBox(height: AppSpacing.lg),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _text(notifier)),
                const SizedBox(width: AppSpacing.xl),
                SizedBox(width: AppSizes.panel, child: _pictureField(notifier)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _Actions(
              notifier: notifier,
              onSave: _submit,
              onDelete: _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(NewsDetailNotifier notifier) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextFormField(
        controller: _title,
        enabled: !notifier.isSaving,
        decoration: InputDecoration(
          labelText: 'Title',
          helperText: 'What the article is listed under, in the app as well.',
          errorText: notifier.messageFor('title'),
        ),
        validator: Validators.title,
      ),
      const SizedBox(height: AppSpacing.lg),
      TextFormField(
        controller: _body,
        enabled: !notifier.isSaving,
        maxLines: _bodyLines,
        decoration: InputDecoration(
          labelText: 'Text',
          alignLabelWithHint: true,
          helperText:
              'At most ${Validators.newsBodyMaximum} characters. Guests read '
              'this as it is written here.',
          errorText: notifier.messageFor('body'),
        ),
        validator: Validators.newsBody,
      ),
    ],
  );

  // The article a write answered with is not the one an emptied form is for.
  Widget _pictureField(NewsDetailNotifier notifier) {
    final NewsItem? stored = notifier.isWriting ? null : notifier.item;

    return NewsPictureField(
      chosen: _picture,
      storedPath: stored?.imagePath,
      isBusy: notifier.isSaving,
      onChoose: _choose,
      onKeepStored: _picture == null || stored == null
          ? null
          : () => setState(() {
              _picture = null;
              _pictureFault = null;
            }),
      errorText: _pictureFault ?? notifier.messageFor('file'),
    );
  }

  Future<void> _choose() async {
    final List<PlatformFile> chosen = await FilePicker.pickFiles(
      dialogTitle: 'Choose a picture',
      type: FileType.custom,
      allowedExtensions: ImageRules.extensions,
    );

    if (chosen.isEmpty) {
      return;
    }

    ImageUpload picked;

    try {
      picked = ImageUpload(
        name: chosen.first.name,
        bytes: await chosen.first.readAsBytes(),
      );
    } on Exception catch (failure) {
      if (mounted) {
        setState(() => _pictureFault = 'That file could not be read. $failure');
      }

      return;
    }

    if (mounted) {
      setState(() {
        _picture = picked;
        _pictureFault = picked.refusal;
      });
    }
  }

  Future<void> _submit() async {
    final NewsDetailNotifier notifier = widget.notifier;
    final bool written = _form.currentState?.validate() ?? false;

    setState(() => _pictureFault = _refusedPicture(notifier));

    if (!written || _pictureFault != null) {
      return;
    }

    final NewsDraft draft = NewsDraft(
      title: _title.text.trim(),
      body: _body.text.trim(),
    );

    final bool carriedAPicture = _picture != null;
    final NewsWrite outcome = notifier.isWriting
        ? await notifier.publishArticle(draft, _picture!)
        : await notifier.saveChanges(draft, image: _picture);

    // Back during the save takes the screen the callback would reach for.
    if (!mounted) {
      return;
    }

    if (outcome == NewsWrite.unchanged) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(NewsForm.nothingChanged)));

      return;
    }

    if (outcome == NewsWrite.refused) {
      return;
    }

    final NewsItem saved = notifier.item!;

    // The bytes behind the article's own address have just been replaced.
    if (carriedAPicture) {
      await ApiImage.forget(context, saved.imagePath);
    }

    if (!mounted) {
      return;
    }

    if (notifier.isWriting) {
      _reset();
    } else {
      setState(() => _picture = null);
    }

    widget.onSaved(saved);
  }

  // The API's own words for an article written without a picture.
  String? _refusedPicture(NewsDetailNotifier notifier) {
    if (_picture case final ImageUpload picked) {
      return picked.refusal;
    }

    return notifier.isWriting ? 'Choose an image to upload.' : null;
  }

  // Emptied for the next one rather than left looking unsaved.
  void _reset() {
    _form.currentState?.reset();

    setState(() {
      _title.clear();
      _body.clear();
      _picture = null;
      _pictureFault = null;
    });
  }

  Future<void> _confirmDelete() async {
    final NewsItem? article = widget.notifier.item;
    if (article == null) {
      return;
    }

    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Delete this article?',
      message:
          '${article.title} goes, and so does its picture. Guests who have '
          'not read it will not see it at all. This cannot be undone.',
      confirmLabel: 'Delete article',
      isDestructive: true,
    );

    if (!agreed) {
      return;
    }

    final bool gone = await widget.notifier.delete();

    if (gone && mounted) {
      widget.onDeleted(article);
    }
  }

  static const int _bodyLines = 12;
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.notifier,
    required this.onSave,
    required this.onDelete,
  });

  final NewsDetailNotifier notifier;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (!notifier.isWriting)
          Tooltip(
            message: 'Delete this article and its picture.',
            child: OutlinedButton(
              onPressed: notifier.isSaving ? null : onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              child: const Text('Delete'),
            ),
          ),
        const Spacer(),
        FilledButton(
          onPressed: notifier.isSaving ? null : onSave,
          child: Text(_label(notifier)),
        ),
      ],
    );
  }

  static String _label(NewsDetailNotifier notifier) {
    if (notifier.isSaving) {
      return notifier.isWriting ? 'Publishing' : 'Saving';
    }

    return notifier.isWriting ? 'Publish article' : 'Save changes';
  }
}
