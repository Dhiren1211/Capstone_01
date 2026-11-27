import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../matching/match_engine.dart';
import '../models/item_model.dart';
import '../services/firestore_service.dart';
import '../services/geocoding_service.dart';
import '../services/image_upload_service.dart';
import '../services/matching_service.dart';
import '../state/auth_state.dart';
import '../state/items_state.dart';
import '../state/settings_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../utils/contact_method.dart';
import '../utils/formatters.dart';
import '../utils/ksu_buildings.dart';
import '../utils/validators.dart';
import '../widgets/building_picker.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/info_banner.dart';
import '../widgets/item_card.dart';
import '../widgets/motion.dart';
import '../widgets/primary_button.dart';

enum ReportMode { lost, found }

/// Form for "I lost something" / "I found something".
///
/// Three parts: the item (photo, name, category, description), the place and
/// day it happened, and - new - "Where can you be found?": the building, room
/// and times where the other person can meet the reporter, plus how the
/// reporter wants to be contacted.
class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key, required this.mode, this.initialBuilding});

  final ReportMode mode;

  /// Pre-selects the place (used by "Report here" on a building page).
  final String? initialBuilding;

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  static const _availabilityPresets = [
    'Weekdays 09:00-12:00',
    'Weekdays 13:00-18:00',
    'Evenings',
    'Weekends',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _spotCtrl = TextEditingController();
  final _availabilityCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  String _category = 'electronics';
  String _location = '';
  String _meetBuilding = '';
  String _contactMethod = 'chat';
  DateTime _date = DateTime.now();

  XFile? _photo;
  Uint8List? _photoBytes;

  bool _submitting = false;
  bool _locating = false;
  bool _autovalidate = false;

  /// GPS fix used when the place is not one of the listed buildings.
  double? _gpsLat;
  double? _gpsLng;

  Timer? _hintTimer;
  List<ScoredMatch> _hints = const [];

  bool get _isLost => widget.mode == ReportMode.lost;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialBuilding;
    if (seed != null && seed.isNotEmpty) {
      _location = seed;
      _meetBuilding = seed;
    }
    _titleCtrl.addListener(_scheduleHints);
    _descriptionCtrl.addListener(_scheduleHints);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _spotCtrl.dispose();
    _availabilityCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------- helpers

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : null,
        ),
      );
  }

  (double, double) _coordinates() {
    final b = findKsuBuildingByName(_location);
    if (b != null) return (b.latitude, b.longitude);
    if (_gpsLat != null && _gpsLng != null) return (_gpsLat!, _gpsLng!);
    return (AppConstants.defaultMapCenterLat, AppConstants.defaultMapCenterLng);
  }

  // ----------------------------------------------- "already reported?" hint

  void _scheduleHints() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 500), _computeHints);
  }

  void _computeHints() {
    if (!mounted) return;
    final user = context.read<AuthState>().user;
    final title = _titleCtrl.text.trim();
    if (user == null || title.length < 3) {
      if (_hints.isNotEmpty) setState(() => _hints = const []);
      return;
    }
    final (lat, lng) = _coordinates();
    final draft = ItemModel(
      id: 'draft',
      title: title,
      description: _descriptionCtrl.text.trim(),
      category: _category,
      status: _isLost ? 'lost' : 'found',
      location: _location,
      latitude: lat,
      longitude: lng,
      reporterId: user.id,
      reporterName: user.displayName,
      contactInfo: '',
      imageUrl: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      eventDate: _date,
    );
    final found = MatchingService.instance.rank(
      draft,
      context.read<ItemsState>().items,
      minScore: 60,
      limit: 2,
    );
    setState(() => _hints = found);
  }

  // ----------------------------------------------------------------- photo

  Future<void> _pickPhoto() async {
    if (_submitting) return;
    if (!ImageUploadService.instance.isConfigured) {
      _toast(
        'Photo upload is not set up yet (see README, Cloudinary). '
        'You can still post without a photo.',
        error: true,
      );
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = picked;
        _photoBytes = bytes;
      });
    } catch (e) {
      debugPrint('[report] photo picker failed: $e');
      _toast('Could not open the camera or gallery.', error: true);
    }
  }

  void _removePhoto() {
    if (_submitting) return;
    setState(() {
      _photo = null;
      _photoBytes = null;
    });
  }

  // ------------------------------------------------------------ date, place

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
      _scheduleHints();
    }
  }

  Future<Position?> _currentPosition() async {
    if (!SettingsStore.instance.locationEnabled) {
      _toast('Location is switched off in Settings.', error: true);
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 20));
  }

  /// Picks the closest listed building when it is within 150 m, otherwise
  /// keeps the GPS fix with a readable address.
  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final pos = await _currentPosition();
      if (pos == null) {
        _toast(
          'Could not get your location. Turn on location services and allow '
          'access, or choose the building from the list.',
          error: true,
        );
        return;
      }
      KsuBuilding? nearest;
      var best = double.infinity;
      for (final b in ksuBuildings) {
        final d = MatchEngine.distanceMeters(
          pos.latitude,
          pos.longitude,
          b.latitude,
          b.longitude,
        );
        if (d < best) {
          best = d;
          nearest = b;
        }
      }
      if (nearest != null && best <= 150) {
        if (!mounted) return;
        setState(() {
          _location = nearest!.name;
          _gpsLat = null;
          _gpsLng = null;
        });
        _toast('Nearest building: ${nearest.numberLabel} ${nearest.name}');
      } else {
        final address = await GeocodingService.instance.reverse(
          pos.latitude,
          pos.longitude,
        );
        if (!mounted) return;
        final raw =
            address ??
            'GPS ${pos.latitude.toStringAsFixed(5)}, '
                '${pos.longitude.toStringAsFixed(5)}';
        setState(() {
          _location = raw.length > AppValidators.maxLocation
              ? raw.substring(0, AppValidators.maxLocation)
              : raw;
          _gpsLat = pos.latitude;
          _gpsLng = pos.longitude;
        });
        _toast('No campus building within 150 m. Using your GPS position.');
      }
      _scheduleHints();
    } catch (e) {
      debugPrint('[report] location failed: $e');
      _toast('Could not get your location. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ---------------------------------------------------------------- submit

  String? _contactValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return _contactMethod == 'chat'
          ? null
          : _contactMethod == 'email'
          ? 'Enter the e-mail address people should write to'
          : 'Enter the phone number people should call';
    }
    return AppValidators.contactInfo(v);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final user = context.read<AuthState>().user;
    if (user == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = true);
      _toast('Please check the highlighted fields.', error: true);
      return;
    }
    final feed = context.read<ItemsState>().items;

    setState(() => _submitting = true);
    try {
      var imageUrl = '';
      if (_photo != null) {
        try {
          imageUrl = await ImageUploadService.instance.uploadXFile(_photo!);
        } on ImageUploadException catch (e) {
          _toast(
            '${e.message} Try again, or remove the photo to post without it.',
            error: true,
          );
          return;
        }
      }

      final (lat, lng) = _coordinates();
      final now = DateTime.now();
      final item = ItemModel(
        id: '',
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        category: _category,
        status: _isLost ? 'lost' : 'found',
        location: _location.trim(),
        latitude: lat,
        longitude: lng,
        reporterId: user.id,
        reporterName: user.displayName,
        contactInfo: _contactCtrl.text.trim(),
        imageUrl: imageUrl,
        availabilitySchedule: _availabilityCtrl.text.trim(),
        pickupLocation: _spotCtrl.text.trim(),
        meetBuilding: _meetBuilding.trim(),
        preferredContactMethod: _contactMethod,
        createdAt: now,
        updatedAt: now,
        eventDate: _date,
      );

      await FirestoreService.instance.createItem(item, feed: feed);

      _toast(
        _isLost
            ? 'Report posted. You will be alerted when something matches.'
            : 'Report posted. Thank you for helping.',
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('[report] submit failed: $e');
      _toast(
        'Could not post the report. Check your connection and try again.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final title = _isLost ? 'Report lost item' : 'Report found item';
    final placeLabel = _isLost ? 'Where did you lose it?' : 'Where did you find it?';
    final dateLabel = _isLost ? 'Date lost' : 'Date found';

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidate
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: FadeSlideIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isLost
                            ? 'The more precisely you describe it, the better the '
                                  'match. We compare title, description, category '
                                  'and place.'
                            : 'Describe what you found without the one detail only '
                                  'the owner would know. We compare it with every '
                                  'lost report.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      const _Heading('Photo'),
                      _PhotoBox(
                        bytes: _photoBytes,
                        onTap: _pickPhoto,
                        onRemove: _removePhoto,
                      ),
                      const _Heading('The item'),
                      CustomTextField(
                        controller: _titleCtrl,
                        label: 'Item name',
                        hint: 'Black Samsung phone with blue case',
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: AppValidators.maxItemName,
                        validator: AppValidators.itemName,
                      ),
                      const SizedBox(height: 16),
                      const _Label('Category'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in AppConstants.categories.where(
                            (c) => c.value != 'all',
                          ))
                            _ChoiceChip(
                              label: c.label,
                              icon: c.icon,
                              selected: _category == c.value,
                              onTap: () {
                                setState(() => _category = c.value);
                                _scheduleHints();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _descriptionCtrl,
                        label: 'Description',
                        hint:
                            'Colour, brand, size, stickers, scratches, what is '
                            'inside...',
                        helper: 'At least 10 characters. Used for matching.',
                        minLines: 3,
                        maxLines: 6,
                        maxLength: AppValidators.maxDescription,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        validator: AppValidators.description,
                      ),
                      if (_hints.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SimilarHint(
                          lost: _isLost,
                          matches: _hints,
                          onOpen: (m) => Navigator.of(context).pushNamed(
                            AppConstants.routeItemDetail,
                            arguments: m.item,
                          ),
                        ),
                      ],
                      const _Heading('Where and when'),
                      BuildingField(
                        label: placeLabel,
                        value: _location,
                        validator: (_) => _location.trim().isEmpty
                            ? 'Choose the building or place'
                            : AppValidators.optionalMax(
                                _location,
                                AppValidators.maxLocation,
                                label: 'Place',
                              ),
                        onChanged: (choice) {
                          setState(() {
                            _location = choice.label;
                            if (choice.building != null) {
                              _gpsLat = null;
                              _gpsLng = null;
                            }
                          });
                          _scheduleHints();
                        },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _locating ? null : _useMyLocation,
                          icon: _locating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location_rounded, size: 18),
                          label: Text(
                            _locating ? 'Finding you...' : 'Use my location',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _Label(dateLabel),
                      _DateField(
                        text: AppFormatters.shortDate(_date),
                        onTap: _pickDate,
                      ),
                      const _Heading('Where can you be found?'),
                      Text(
                        _isLost
                            ? 'If someone finds your item, this tells them where '
                                  'to bring it or meet you.'
                            : 'Tell the owner where to collect it. Say where you '
                                  'keep it, or where you will be.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      BuildingField(
                        label: 'Building',
                        value: _meetBuilding,
                        hint: 'Select a building (optional)',
                        onChanged: (c) => setState(() => _meetBuilding = c.label),
                      ),
                      if (_location.isNotEmpty && _meetBuilding != _location)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _meetBuilding = _location),
                            child: const Text('Same building as above'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _spotCtrl,
                        label: 'Room or spot',
                        hint: 'Room 301, front desk, cafe on the 1st floor',
                        maxLength: 120,
                        validator: (v) => AppValidators.optionalMax(
                          v,
                          120,
                          label: 'Room or spot',
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _availabilityCtrl,
                        label: 'When you are usually there',
                        hint: 'Weekdays after 3 pm',
                        maxLength: 120,
                        onChanged: (_) => setState(() {}),
                        validator: (v) => AppValidators.optionalMax(
                          v,
                          120,
                          label: 'Availability',
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in _availabilityPresets)
                            _ChoiceChip(
                              label: p,
                              selected: _availabilityCtrl.text == p,
                              onTap: () => setState(
                                () => _availabilityCtrl.text = p,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _Label('How should people contact you?'),
                      Row(
                        children: [
                          for (var i = 0; i < contactMethods.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _MethodTile(
                                method: contactMethods[i],
                                selected: _contactMethod == contactMethods[i].value,
                                onTap: () => setState(
                                  () => _contactMethod = contactMethods[i].value,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_contactMethod != 'chat') ...[
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _contactCtrl,
                          label: _contactMethod == 'email'
                              ? 'E-mail address'
                              : 'Phone number',
                          hint: _contactMethod == 'email'
                              ? 'you@ks.ac.kr'
                              : '010-1234-5678',
                          keyboardType: _contactMethod == 'email'
                              ? TextInputType.emailAddress
                              : TextInputType.phone,
                          maxLength: AppValidators.maxContact,
                          validator: _contactValidator,
                        ),
                        const SizedBox(height: 8),
                        const InfoBanner(
                          message:
                              'This is visible to every signed-in student who '
                              'opens your report.',
                        ),
                      ],
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: _isLost ? 'Post lost report' : 'Post found report',
                        isLoading: _submitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppTextStyles.h3Bold.copyWith(
            color: AppColors.textPrimaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.captionMedium.copyWith(
          color: AppColors.textSecondaryOf(context),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.onPrimaryOf(context)
        : AppColors.textPrimaryOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryOf(context)
                : AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primaryOf(context)
                  : AppColors.borderOf(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? fg : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.captionMedium.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final ContactMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primaryOf(context)
        : AppColors.textSecondaryOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: method.label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primarySurfaceOf(context)
                : AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primaryOf(context)
                  : AppColors.borderOf(context),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(method.icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                method.label,
                textAlign: TextAlign.center,
                style: AppTextStyles.captionMedium.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Date, $text',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primarySurfaceOf(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 20,
                color: AppColors.textTertiaryOf(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                color: AppColors.textTertiaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({
    required this.bytes,
    required this.onTap,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Semantics(
        button: true,
        label: data == null ? 'Add a photo' : 'Change photo',
        child: Pressable(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppColors.softShadowOf(context),
            ),
            clipBehavior: Clip.antiAlias,
            child: data == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 36,
                        color: AppColors.primaryOf(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Add a photo',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Optional, but it helps a lot',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(data, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton.filled(
                          tooltip: 'Remove photo',
                          onPressed: onRemove,
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SimilarHint extends StatelessWidget {
  const _SimilarHint({
    required this.lost,
    required this.matches,
    required this.onOpen,
  });

  final bool lost;
  final List<ScoredMatch> matches;
  final ValueChanged<ScoredMatch> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(
          tone: BannerTone.warning,
          title: lost ? 'This may already be found' : 'The owner may be looking',
          message: lost
              ? 'These found reports look similar. Check them before you post.'
              : 'These lost reports look similar. If it is the same item, '
                    'message the owner instead of posting again.',
        ),
        const SizedBox(height: 12),
        for (final m in matches) ...[
          ItemCard(
            item: m.item,
            matchConfidence: m.score,
            onTap: () => onOpen(m),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
