import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../services/provider.dart';
import '../services/agent_service.dart';

class ModalModelSelection extends StatefulWidget {
  final String? currentModelId;
  const ModalModelSelection({super.key, this.currentModelId});

  @override
  State<ModalModelSelection> createState() => _ModalModelSelectionState();
}

class _ModalModelSelectionState extends State<ModalModelSelection> {
  String? _selectedId;
  bool _loading = true;
  List<ModelInfo> _freeModels = [];
  List<ModelInfo> _paidModels = [];

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentModelId ?? ApiConfig.defaultFreeModelId;
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final models = await apiProvider.agentService.getModels();
      if (!mounted) return;
      final free = models.where((m) => m.isFree).toList();
      final paid = models.where((m) => !m.isFree).toList();
      setState(() {
        _freeModels = free;
        _paidModels = paid;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Fallback: show hardcoded free models if API fails
      setState(() {
        _freeModels = ApiConfig.freeModels
            .map((m) => ModelInfo(
                  id: m['id']!,
                  name: m['name']!,
                  isFree: true,
                  supportsTools: true,
                ))
            .toList();
        _paidModels = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        children: [
          // Handle + close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Model',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentLink,
                      strokeWidth: 2,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (_freeModels.isNotEmpty) ...[
                        _SectionHeader(label: 'FREE'),
                        ..._freeModels.map((m) => _ModelItem(
                              id: m.id,
                              name: m.name,
                              isFree: true,
                              supportsTools: m.supportsTools,
                              isSelected: m.id == _selectedId,
                              onTap: () => Navigator.pop(context, m.id),
                            )),
                      ],
                      if (_paidModels.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _SectionHeader(label: 'PRO'),
                        ..._paidModels.map((m) => _ModelItem(
                              id: m.id,
                              name: m.name,
                              isFree: false,
                              supportsTools: m.supportsTools,
                              isSelected: m.id == _selectedId,
                              onTap: () => Navigator.pop(context, m.id),
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _ModelItem extends StatelessWidget {
  final String id;
  final String name;
  final bool isFree;
  final bool supportsTools;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelItem({
    required this.id,
    required this.name,
    required this.isFree,
    required this.supportsTools,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentLink.withValues(alpha: 0.15)
              : AppTheme.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.auto_awesome,
          size: 18,
          color: isSelected ? AppTheme.accentLink : AppTheme.textSecondary,
        ),
      ),
      title: Text(
        name,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: supportsTools
          ? Text(
              'Supports tools',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.accentLink.withValues(alpha: 0.8),
                  ),
            )
          : null,
      trailing: isSelected
          ? const Icon(Icons.check, size: 20, color: AppTheme.accentLink)
          : null,
      onTap: onTap,
    );
  }
}
