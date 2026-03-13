import 'package:flutter/material.dart';
import '../widgets/optimized_image.dart';

/// Dialog showing resident profile information when avatar is tapped.
/// Displays avatar, name, purok, phone number, and seller badge if applicable.
class ResidentProfileDialog extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String? purok;
  final String? phoneNumber;
  final bool isSeller;

  const ResidentProfileDialog({
    super.key,
    this.avatarUrl,
    required this.name,
    this.purok,
    this.phoneNumber,
    this.isSeller = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF20BF6B),
                      const Color(0xFF20BF6B).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl != null && avatarUrl!.isNotEmpty
                            ? OptimizedNetworkImage(
                                imageUrl: avatarUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                cacheWidth: 160,
                                cacheHeight: 160,
                                errorWidget: _buildFallbackAvatar(initials),
                              )
                            : _buildFallbackAvatar(initials),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Name
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isSeller) ...[
                      const SizedBox(height: 6),
                      // Seller badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Seller',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Info section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (purok != null && purok!.isNotEmpty) ...[
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Purok',
                        value: purok!,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (phoneNumber != null && phoneNumber!.isNotEmpty) ...[
                      _buildInfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: phoneNumber!,
                        isDark: isDark,
                      ),
                    ],
                    if ((purok == null || purok!.isEmpty) &&
                        (phoneNumber == null || phoneNumber!.isEmpty)) ...[
                      Text(
                        'No additional information available',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Close hint
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Tap anywhere to close',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String initials) {
    return CircleAvatar(
      radius: 40,
      backgroundColor: const Color(0xFF20BF6B),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF20BF6B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF20BF6B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
