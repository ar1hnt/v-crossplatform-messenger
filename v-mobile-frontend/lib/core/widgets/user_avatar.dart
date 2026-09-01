import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../config/app_config.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.fullName,
    this.avatarFileId,
    this.avatarUrl,
    this.accessToken,
    this.localImageBytes,
    this.radius = 22,
    this.isOnline,
    this.onTap,
  });

  final String fullName;
  final String? avatarFileId;
  final String? avatarUrl;
  final String? accessToken;
  final Uint8List? localImageBytes;
  final double radius;
  final bool? isOnline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fileId = avatarFileId?.trim();
    final imageUrl = fileId != null && fileId.isNotEmpty
        ? '${AppConfig.apiBaseUrl}/files/$fileId/content'
        : avatarUrl?.trim();
    final imageHeaders =
        fileId != null &&
            fileId.isNotEmpty &&
            accessToken != null &&
            accessToken!.trim().isNotEmpty
        ? {'Authorization': 'Bearer ${accessToken!.trim()}'}
        : null;
    final initials = _initials(fullName);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.18),
      foregroundImage: localImageBytes != null
          ? MemoryImage(localImageBytes!)
          : imageUrl == null || imageUrl.isEmpty
          ? null
          : NetworkImage(imageUrl, headers: imageHeaders),
      child: (imageUrl == null || imageUrl.isEmpty) && localImageBytes == null
          ? Text(
              initials,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: radius * 0.48,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );

    final content = isOnline == null
        ? avatar
        : Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: radius * 0.48,
                  height: radius * 0.48,
                  decoration: BoxDecoration(
                    color: isOnline!
                        ? const Color(0xFF2D8A4F)
                        : const Color(0xFFB6ADA0),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.background, width: 2),
                  ),
                ),
              ),
            ],
          );

    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: content,
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
  }
}
