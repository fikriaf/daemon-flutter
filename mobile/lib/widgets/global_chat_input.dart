import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import 'modal_model_selection.dart';

class GlobalChatInput extends StatelessWidget {
  final TextEditingController? controller;
  final VoidCallback? onSubmit;
  /// The currently selected model id (null = use agent default)
  final String? selectedModelId;
  /// Display label for the selected model (e.g. "Trinity Large")
  final String? selectedModelName;
  /// Called when user picks a different model from the modal
  final ValueChanged<String>? onModelChanged;

  const GlobalChatInput({
    super.key,
    this.controller,
    this.onSubmit,
    this.selectedModelId,
    this.selectedModelName,
    this.onModelChanged,
  });

  Future<void> _showModelModal(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: ModalModelSelection(currentModelId: selectedModelId),
      ),
    );
    if (picked != null && onModelChanged != null) {
      onModelChanged!(picked);
    }
  }

  void _showActionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ActionModal(),
    );
  }

  /// Short label for the model button — at most ~10 chars
  String _modelLabel() {
    return ApiConfig.shortLabelForModel(selectedModelId) ?? 'Model';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.background,
      ),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight, width: 1),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,
                onSubmitted: (_) {
                  if (onSubmit != null) onSubmit!();
                },
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Type @ for connectors...',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textPlaceholder,
                      ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Add button
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add,
                              color: AppTheme.textSecondary, size: 18),
                          onPressed: () => _showActionModal(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Model picker button
                      GestureDetector(
                        onTap: () => _showModelModal(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selectedModelId != null
                                ? AppTheme.accentLink.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selectedModelId != null
                                  ? AppTheme.accentLink.withValues(alpha: 0.4)
                                  : AppTheme.borderLight,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 13,
                                color: selectedModelId != null
                                    ? AppTheme.accentLink
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _modelLabel(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: selectedModelId != null
                                          ? AppTheme.accentLink
                                          : AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 14,
                                color: selectedModelId != null
                                    ? AppTheme.accentLink
                                    : AppTheme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sandbox
                      GestureDetector(
                        onTap: () => context.go('/sandbox'),
                        child: Row(
                          children: [
                            const Icon(Icons.laptop_chromebook,
                                size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Sandbox',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.mic_none,
                            color: AppTheme.textSecondary, size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Feature not available yet')),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppTheme.borderLight,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_forward,
                              color: AppTheme.textPrimary, size: 16),
                          onPressed: () {
                            if (onSubmit != null) {
                              onSubmit!();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Feature not available yet')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionModal extends StatelessWidget {
  const ActionModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Choose Action',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          _ActionItem(
            icon: Icons.upload_file,
            title: 'Upload File',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature not available yet')),
              );
            },
          ),
          _ActionItem(
            icon: Icons.image_outlined,
            title: 'Choose Image',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature not available yet')),
              );
            },
          ),
          _ActionItem(
            icon: Icons.camera_alt_outlined,
            title: 'Camera',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature not available yet')),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.borderLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 24),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
            ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
