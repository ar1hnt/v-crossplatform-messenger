import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../ai/data/ai_repository.dart';
import '../../auth/state/auth_controller.dart';
import '../data/profile_repository.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../posts/state/posts_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _postController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _pendingAvatarFileId;
  Uint8List? _pendingAvatarPreviewBytes;
  bool _isAvatarUploading = false;
  bool _isGeneratingPost = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final user = session?.user;
    final postsState = ref.watch(postsControllerProvider);
    final accessToken = session?.accessToken;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _nameController.value = TextEditingValue(text: user.fullName);
    _phoneController.value = TextEditingValue(text: user.phone ?? '');
    _bioController.value = TextEditingValue(text: user.bio ?? '');
    final bioText = user.bio?.trim();

    return AppScaffold(
      title: 'Профиль',
      actions: [
        IconButton(
          tooltip: 'Настройки',
          onPressed: () => _showSettings(context),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: ListView(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  AppTheme.neonCyan.withValues(alpha: 0.24),
                  AppTheme.neonPink.withValues(alpha: 0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppTheme.neonCyan.withValues(alpha: 0.24),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UserAvatar(
                    fullName: user.fullName,
                    avatarFileId: user.avatarFileId,
                    avatarUrl: user.avatarUrl,
                    accessToken: accessToken,
                    radius: 38,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.presenceStatus,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('О себе', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text(
                    bioText == null || bioText.isEmpty
                        ? 'Пользователь пока ничего не написал о себе.'
                        : bioText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: bioText == null || bioText.isEmpty
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Новый пост',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _postController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(hintText: 'Что нового?'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isGeneratingPost
                              ? null
                              : () async {
                                  final draft = _postController.text.trim();
                                  if (draft.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Напиши тему или черновик для ИИ',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => _isGeneratingPost = true);
                                  try {
                                    final suggestion = await ref
                                        .read(aiRepositoryProvider)
                                        .suggestPost(topicOrDraft: draft);
                                    _postController.text = suggestion;
                                    _postController.selection =
                                        TextSelection.collapsed(
                                          offset: _postController.text.length,
                                        );
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Не удалось сгенерировать пост: $error',
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isGeneratingPost = false);
                                    }
                                  }
                                },
                          icon: _isGeneratingPost
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(
                            _isGeneratingPost ? 'Генерирую...' : 'Через ИИ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final text = _postController.text.trim();
                            if (text.isEmpty) {
                              return;
                            }
                            await ref
                                .read(postsControllerProvider.notifier)
                                .createPost(text);
                            _postController.clear();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Опубликовать'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Мои посты', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...postsState.when(
            data: (posts) {
              if (posts.isEmpty) {
                return const [
                  Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: Text('Постов пока нет')),
                  ),
                ];
              }
              return posts
                  .map(
                    (post) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PostCard(
                        post: post,
                        authorName: user.fullName,
                        onLikePressed: ref
                            .read(postsControllerProvider.notifier)
                            .toggleLike,
                        onCommentCreated: (post, text) => ref
                            .read(postsControllerProvider.notifier)
                            .addComment(post: post, text: text),
                      ),
                    ),
                  )
                  .toList();
            },
            loading: () => const [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
            error: (error, _) => [
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text('Не удалось загрузить посты: $error'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    _pendingAvatarFileId = null;
    _pendingAvatarPreviewBytes = null;
    _isAvatarUploading = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.panelStrong,
      builder: (context) {
        final user = ref.read(authControllerProvider).asData?.value?.user;
        final accessToken = ref
            .read(authControllerProvider)
            .asData
            ?.value
            ?.accessToken;
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Настройки профиля',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      UserAvatar(
                        fullName: _nameController.text.trim().isEmpty
                            ? user?.fullName ?? 'Пользователь'
                            : _nameController.text.trim(),
                        avatarFileId:
                            _pendingAvatarFileId ?? user?.avatarFileId,
                        avatarUrl: user?.avatarUrl,
                        accessToken: accessToken,
                        localImageBytes: _pendingAvatarPreviewBytes,
                        radius: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isAvatarUploading
                              ? null
                              : () async {
                                  final image = await _imagePicker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 86,
                                    maxWidth: 1200,
                                  );
                                  if (image == null) {
                                    return;
                                  }
                                  final previewBytes = await image
                                      .readAsBytes();
                                  setSheetState(() {
                                    _isAvatarUploading = true;
                                    _pendingAvatarPreviewBytes = previewBytes;
                                  });
                                  try {
                                    final fileId = await ref
                                        .read(profileRepositoryProvider)
                                        .uploadAvatar(image.path);
                                    setSheetState(() {
                                      _pendingAvatarFileId = fileId;
                                      _isAvatarUploading = false;
                                    });
                                  } catch (_) {
                                    setSheetState(() {
                                      _isAvatarUploading = false;
                                      _pendingAvatarPreviewBytes = null;
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Не удалось загрузить аватарку',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: _isAvatarUploading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_camera_outlined),
                          label: Text(
                            _isAvatarUploading
                                ? 'Загружаю...'
                                : 'Загрузить аватарку',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'ФИО'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Телефон'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bioController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'О себе'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await ref
                                .read(authControllerProvider.notifier)
                                .updateProfile(
                                  fullName: _nameController.text.trim(),
                                  phone: _phoneController.text.trim().isEmpty
                                      ? null
                                      : _phoneController.text.trim(),
                                  bio: _bioController.text.trim().isEmpty
                                      ? null
                                      : _bioController.text.trim(),
                                  avatarFileId: _pendingAvatarFileId,
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text('Сохранить'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                        },
                        child: const Text('Выйти'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
