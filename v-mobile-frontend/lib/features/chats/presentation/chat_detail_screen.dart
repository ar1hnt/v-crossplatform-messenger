import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../ai/data/ai_repository.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/message.dart';
import 'media_viewer_screen.dart';
import '../state/chat_messages_controller.dart';
import '../state/realtime_controller.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.peer,
  });

  final String chatId;
  final String title;
  final UserProfile? peer;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  ProviderSubscription<Map<String, dynamic>?>? _realtimeSubscription;
  int _lastMessageCount = 0;
  int _newMessagesBelowCount = 0;
  bool _stickToBottom = true;
  bool _showScrollToBottomButton = false;
  bool _isGeneratingReply = false;
  bool _isSendingMessage = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _realtimeSubscription = ref.listenManual(realtimeEventProvider, (
      previous,
      next,
    ) {
      if (next == null) {
        return;
      }
      if (next['event'] == 'message.created') {
        final data = next['data'] as Map<String, dynamic>;
        final message = Message.fromJson(data);
        if (message.chatId == widget.chatId) {
          ref
              .read(chatMessagesControllerProvider(widget.chatId).notifier)
              .addIncomingMessage(message);
        }
      }
      if (next['event'] == 'message.read') {
        final data = next['data'] as Map<String, dynamic>;
        if (data['chat_id'] == widget.chatId) {
          ref
              .read(chatMessagesControllerProvider(widget.chatId).notifier)
              .markCurrentChatRead();
        }
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.close();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final isAtBottom = _isNearBottom();
    if (_stickToBottom != isAtBottom ||
        _showScrollToBottomButton == isAtBottom) {
      setState(() {
        _stickToBottom = isAtBottom;
        _showScrollToBottomButton = !isAtBottom;
        if (isAtBottom) {
          _newMessagesBelowCount = 0;
        }
      });
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final distanceToBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    return distanceToBottom <= 96;
  }

  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      _scrollController.jumpTo(target);
    });
  }

  void _syncScrollWithMessages(List<Message> messages, String? currentUserId) {
    final messageCount = messages.length;
    if (messageCount == _lastMessageCount) {
      return;
    }

    final previousMessageCount = _lastMessageCount;
    final shouldScroll = previousMessageCount == 0 || _stickToBottom;
    if (!shouldScroll && messageCount > previousMessageCount) {
      final incomingMessagesCount = messages
          .skip(previousMessageCount)
          .where(
            (message) =>
                currentUserId != null && message.senderId != currentUserId,
          )
          .length;
      _newMessagesBelowCount += incomingMessagesCount;
    }
    _lastMessageCount = messageCount;
    if (shouldScroll) {
      _newMessagesBelowCount = 0;
      _scrollToBottom(animated: _lastMessageCount > 0);
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMessage) {
      return;
    }

    setState(() => _isSendingMessage = true);
    try {
      await ref
          .read(chatMessagesControllerProvider(widget.chatId).notifier)
          .sendTextMessage(text);
      _messageController.clear();
    } catch (error) {
      _showErrorSnackBar(error);
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }

  Future<void> _showMediaPicker() async {
    if (_isSendingMessage) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Отправить фото'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickAndSendMedia(isVideo: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Отправить видео'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickAndSendMedia(isVideo: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendMedia({required bool isVideo}) async {
    try {
      final file = isVideo
          ? await _imagePicker.pickVideo(source: ImageSource.gallery)
          : await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        return;
      }

      setState(() => _isSendingMessage = true);
      await ref
          .read(chatMessagesControllerProvider(widget.chatId).notifier)
          .sendMediaMessage(
            path: file.path,
            text: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
          );
      _messageController.clear();
    } catch (error) {
      _showErrorSnackBar(error);
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }

  void _showErrorSnackBar(Object error) {
    final message = switch (error) {
      ApiException exception => exception.message,
      _ => error.toString(),
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _buildAuthenticatedFileUrl(String fileId) {
    return '${AppConfig.apiBaseUrl}/files/$fileId/content';
  }

  Map<String, String> _buildFileHeaders(String accessToken) {
    return {'Authorization': 'Bearer $accessToken'};
  }

  Future<void> _openMediaViewer({
    required MessageFile file,
    required String accessToken,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerScreen(
          file: file,
          url: _buildAuthenticatedFileUrl(file.id),
          headers: _buildFileHeaders(accessToken),
        ),
      ),
    );
  }

  Widget _buildMessageBody(Message message, bool isMine, String? accessToken) {
    final textColor = isMine ? AppTheme.background : AppTheme.textPrimary;
    final secondaryTextColor = isMine
        ? AppTheme.backgroundSoft
        : AppTheme.textSecondary;

    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (message.file != null) ...[
          _buildAttachmentPreview(message.file!, isMine, accessToken),
          if ((message.text ?? '').trim().isNotEmpty)
            const SizedBox(height: 10),
        ],
        if ((message.text ?? '').trim().isNotEmpty)
          Text(message.text!, style: TextStyle(color: textColor))
        else if (message.file == null)
          Text('[вложение]', style: TextStyle(color: textColor)),
        const SizedBox(height: 6),
        Text(
          message.createdAt.toLocal().toString().substring(11, 16),
          style: TextStyle(fontSize: 12, color: secondaryTextColor),
        ),
      ],
    );
  }

  Widget _buildAttachmentPreview(
    MessageFile file,
    bool isMine,
    String? accessToken,
  ) {
    final borderColor = isMine
        ? AppTheme.background.withValues(alpha: 0.18)
        : AppTheme.neonPink.withValues(alpha: 0.18);
    final textColor = isMine ? AppTheme.background : AppTheme.textPrimary;
    final secondaryTextColor = isMine
        ? AppTheme.backgroundSoft
        : AppTheme.textSecondary;
    final fileUrl = _buildAuthenticatedFileUrl(file.id);
    final headers = accessToken == null
        ? const <String, String>{}
        : _buildFileHeaders(accessToken);

    final preview = file.isImage
        ? ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              fileUrl,
              headers: headers,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildFileTile(
                  file: file,
                  icon: Icons.broken_image_outlined,
                  borderColor: borderColor,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                );
              },
            ),
          )
        : Stack(
            alignment: Alignment.center,
            children: [
              _buildFileTile(
                file: file,
                icon: Icons.play_circle_outline_rounded,
                borderColor: borderColor,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
              Icon(
                Icons.play_circle_fill_rounded,
                size: 44,
                color: textColor.withValues(alpha: 0.92),
              ),
            ],
          );

    if (accessToken == null) {
      return preview;
    }

    return GestureDetector(
      onTap: () => _openMediaViewer(file: file, accessToken: accessToken),
      child: preview,
    );
  }

  Widget _buildFileTile({
    required MessageFile file,
    required IconData icon,
    required Color borderColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.originalName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  file.isVideo ? 'Видео' : 'Файл',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(
      chatMessagesControllerProvider(widget.chatId),
    );
    final authSession = ref.watch(authControllerProvider).asData?.value;
    final currentUserId = authSession?.user.id;
    final accessToken = authSession?.accessToken;

    return AppScaffold(
      title: widget.title,
      titleWidget: widget.peer == null
          ? Text(widget.title)
          : InkWell(
              onTap: () => context.push('/users/${widget.peer!.id}'),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    fullName: widget.peer!.fullName,
                    avatarFileId: widget.peer!.avatarFileId,
                    avatarUrl: widget.peer!.avatarUrl,
                    accessToken: accessToken,
                    radius: 18,
                    isOnline: widget.peer!.presenceStatus == 'online',
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.peer!.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
      body: Column(
        children: [
          Expanded(
            child: messagesState.when(
              data: (messages) {
                _syncScrollWithMessages(messages, currentUserId);
                return Stack(
                  children: [
                    ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: messages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.senderId == currentUserId;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? AppTheme.neonCyan.withValues(alpha: 0.88)
                                  : AppTheme.panel,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isMine
                                    ? AppTheme.neonCyan.withValues(alpha: 0.35)
                                    : AppTheme.neonPink.withValues(alpha: 0.18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isMine
                                              ? AppTheme.neonCyan
                                              : AppTheme.neonPink)
                                          .withValues(alpha: 0.12),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildMessageBody(message, isMine, accessToken),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (_showScrollToBottomButton)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: FloatingActionButton.small(
                          tooltip: 'К новым сообщениям',
                          onPressed: () {
                            setState(() {
                              _stickToBottom = true;
                              _showScrollToBottomButton = false;
                              _newMessagesBelowCount = 0;
                            });
                            _scrollToBottom(animated: true);
                          },
                          backgroundColor: AppTheme.panel,
                          foregroundColor: AppTheme.textPrimary,
                          shape: CircleBorder(
                            side: BorderSide(
                              color: AppTheme.neonPink.withValues(alpha: 0.18),
                            ),
                          ),
                          elevation: 6,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.keyboard_arrow_down),
                              if (_newMessagesBelowCount > 0)
                                Positioned(
                                  right: -12,
                                  top: -12,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.background,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppTheme.neonPink,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      _newMessagesBelowCount > 99
                                          ? '99+'
                                          : '$_newMessagesBelowCount',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.neonPink,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Не удалось загрузить сообщения: $error')),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Отправить медиа',
                onPressed: _isSendingMessage ? null : _showMediaPicker,
                icon: _isSendingMessage
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file_rounded),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Сгенерировать ответ',
                onPressed: _isGeneratingReply
                    ? null
                    : () async {
                        setState(() => _isGeneratingReply = true);
                        try {
                          final suggestion = await ref
                              .read(aiRepositoryProvider)
                              .suggestMessage(
                                chatId: widget.chatId,
                                instruction:
                                    _messageController.text.trim().isEmpty
                                    ? null
                                    : _messageController.text.trim(),
                              );
                          _messageController.text = suggestion;
                          _messageController.selection =
                              TextSelection.collapsed(
                                offset: _messageController.text.length,
                              );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Не удалось сгенерировать ответ: $error',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isGeneratingReply = false);
                          }
                        }
                      },
                icon: _isGeneratingReply
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Ввести сообщение',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isSendingMessage ? null : _sendTextMessage,
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
