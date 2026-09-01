class MessageFile {
  const MessageFile({
    required this.id,
    required this.originalName,
    required this.contentType,
    required this.url,
  });

  final String id;
  final String originalName;
  final String contentType;
  final String url;

  bool get isImage => contentType.startsWith('image/');
  bool get isVideo => contentType.startsWith('video/');

  factory MessageFile.fromJson(Map<String, dynamic> json) {
    return MessageFile(
      id: json['id'] as String,
      originalName: json['original_name'] as String? ?? 'Файл',
      contentType:
          json['content_type'] as String? ?? 'application/octet-stream',
      url: json['url'] as String? ?? '',
    );
  }
}

class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.messageType,
    required this.createdAt,
    required this.text,
    this.readAt,
    this.file,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String messageType;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? text;
  final MessageFile? file;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      messageType: json['message_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      text: json['text'] as String?,
      file: json['file'] != null
          ? MessageFile.fromJson(json['file'] as Map<String, dynamic>)
          : null,
    );
  }

  Message copyWith({DateTime? readAt}) {
    return Message(
      id: id,
      chatId: chatId,
      senderId: senderId,
      messageType: messageType,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      text: text,
      file: file,
    );
  }
}
