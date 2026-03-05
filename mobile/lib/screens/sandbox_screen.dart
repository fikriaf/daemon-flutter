import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/modals.dart';

class SandboxScreen extends StatelessWidget {
  const SandboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SidebarDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.laptop_chromebook, color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Daemon Sandbox',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Sandbox is active.',
              style: Theme.of(context).primaryTextTheme.displaySmall?.copyWith(
                fontSize: 32,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Anything AI can do, Daemon Sandbox can do for you.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Input Box
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What should we work on next?',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textPlaceholder,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: const Icon(Icons.add, color: AppTheme.textSecondary, size: 16),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.mic_none, color: AppTheme.textSecondary, size: 20),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.borderLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_forward, color: AppTheme.textSecondary, size: 20),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppTheme.borderLight, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.textPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Max',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.background,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'To use Sandbox,\nyou need the Max plan',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.accentLink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            Modals.showUpgradeMenu(context);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryAction,
                            foregroundColor: AppTheme.primaryActionText,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Upgrade'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),

            // Examples Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Example tasks',
                  style: Theme.of(context).primaryTextTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feature not available yet')),
                    );
                  },
                  icon: const Icon(Icons.shuffle, size: 16, color: AppTheme.textSecondary),
                  label: Text(
                    'Shuffle',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            const _TaskCard(
              icon: Icons.science_outlined,
              text: 'Rank anti-aging compounds using ITP data and...',
            ),
            const _TaskCard(
              icon: Icons.monitor_outlined,
              text: 'Create college-level differential equations lecture slides covering...',
            ),
            const _TaskCard(
              icon: Icons.fitness_center_outlined,
              text: 'Build a mobile web app for Huberman\'s strength training protocol, complete...',
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TaskCard({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.textSecondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
