import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/image_upload_service.dart';
import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/auth_layout.dart' show showAppSnack;
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/user_avatar.dart';

/// Edit profile: display name and photo.
///
/// The photo is uploaded to Cloudinary ([ImageUploadService]); the returned
/// URL and the name are stored on the Firestore user document by
/// [AuthService]. [AuthState] listens to that document, so the rest of the app
/// updates by itself once the save finishes.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  final _formKey = GlobalKey<FormState>();
  Uint8List? _newAvatarBytes;
  XFile? _newAvatar;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthState>().user;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_isSaving) return;
    if (!ImageUploadService.instance.isConfigured) {
      showAppSnack(
        context,
        'Photo uploads are not set up yet. You can still change your name.',
        error: true,
      );
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newAvatar = picked;
        _newAvatarBytes = bytes;
      });
    } catch (e) {
      debugPrint('[edit-profile] picker failed: $e');
      if (mounted) {
        showAppSnack(context, 'Could not open your photos.', error: true);
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = context.read<AuthState>().user;
    if (user == null) return;
    final name = _nameCtrl.text.trim();
    final nothingChanged = _newAvatar == null && name == user.displayName;
    if (nothingChanged) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Upload first: if that fails nothing has changed.
      if (_newAvatar != null) {
        final url = await ImageUploadService.instance.uploadXFile(_newAvatar!);
        await AuthService.instance.updateAvatarUrl(url);
      }
      if (name != user.displayName) {
        await AuthService.instance.updateDisplayName(name);
      }
      if (!mounted) return;
      showAppSnack(context, 'Profile updated');
      Navigator.of(context).maybePop();
    } on ImageUploadException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } on AuthFailure catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (e) {
      debugPrint('[edit-profile] save failed: $e');
      if (mounted) {
        showAppSnack(
          context,
          'Could not update your profile. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final name = user?.displayName ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Semantics(
                        button: true,
                        label: 'Change profile photo',
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              if (_newAvatarBytes != null)
                                ClipOval(
                                  child: Image.memory(
                                    _newAvatarBytes!,
                                    width: 112,
                                    height: 112,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                UserAvatar(
                                  name: name,
                                  imageUrl: user?.avatarUrl,
                                  size: 112,
                                ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOf(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.backgroundOf(context),
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  size: 17,
                                  color: cs.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _isSaving ? null : _pickAvatar,
                        child: const Text('Change photo'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _nameCtrl,
                      label: 'Display name',
                      hint: 'Your name as others see it',
                      prefixIcon: Icons.person_outline,
                      validator: AppValidators.displayName,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 16),
                    // The e-mail address is the account identity and cannot be
                    // edited here.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.chipIdleOf(context),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                            color: AppColors.textTertiaryOf(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email (cannot be changed)',
                                  style: AppTextStyles.micro.copyWith(
                                    color: AppColors.textTertiaryOf(context),
                                  ),
                                ),
                                Text(
                                  user?.email ?? '',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'Save changes',
                      isLoading: _isSaving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
