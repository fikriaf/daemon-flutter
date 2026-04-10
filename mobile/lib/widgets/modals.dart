import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'modal_model_selection.dart';

class Modals {
  // 0. Modal Model Selection
  static void showModelMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75, // Adjust height as needed
        child: const ModalModelSelection(),
      ),
    );
  }

  // 1. Modal 3-Point Menu (from 'modal point 3 menus.png')
  static void showThreadMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ThreadMenuModal(),
    );
  }

  // 2. Modal Share (from 'modal share.png')
  static void showShareMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ShareModal(),
    );
  }

  // 3. Modal Upgrade (from 'modal upgrade subscription.png')
  static void showUpgradeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _UpgradeModal(),
    );
  }
}

// ---------------------------------------------------------
// Thread Menu
// ---------------------------------------------------------
class _ThreadMenuModal extends StatelessWidget {
  const _ThreadMenuModal();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), // Spacer for centering
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'carikan saham indonesia terbaru',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Created by', style: Theme.of(context).textTheme.labelSmall),
                    Text('vulgansara7908 (You)', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Last Updated', style: Theme.of(context).textTheme.labelSmall),
                    Text('Today', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderLight),
          _MenuActionItem(icon: Icons.bookmark_border, title: 'Add Bookmark', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature not available yet')));
          }),
          _MenuActionItem(icon: Icons.add, title: 'Add to Space', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature not available yet')));
          }),
          _MenuActionItem(icon: Icons.edit_outlined, title: 'Rename Thread', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature not available yet')));
          }),
          const SizedBox(height: 8),
          _MenuActionItem(icon: Icons.picture_as_pdf_outlined, title: 'Export as PDF', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature not available yet')));
          }),
          _MenuActionItem(icon: Icons.data_object, title: 'Export as Markdown', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature not available yet')));
          }),
          _MenuActionItem(icon: Icons.description_outlined, title: 'Export as DOCX', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature not available yet')));
          }),
          const SizedBox(height: 8),
          _MenuActionItem(icon: Icons.delete_outline, title: 'Delete', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature not available yet')));
          }),
        ],
      ),
    );
  }
}

class _MenuActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuActionItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: 20),
            const SizedBox(width: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Share Modal
// ---------------------------------------------------------
class _ShareModal extends StatelessWidget {
  const _ShareModal();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 24, left: 24, right: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Share this thread',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline, color: AppTheme.textPrimary),
            title: Text('Private', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
            subtitle: Text('Only the author can view', style: Theme.of(context).textTheme.bodyMedium),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.public, color: AppTheme.accentLink),
            title: Text('Anyone with the link', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.accentLink, fontWeight: FontWeight.w500)),
            subtitle: Text('Anyone with the link', style: Theme.of(context).textTheme.bodyMedium),
            trailing: const Icon(Icons.check, color: AppTheme.accentLink),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.copy, size: 16, color: AppTheme.accentLink),
              const SizedBox(width: 8),
              Text(
                'Link copied. Paste to share',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.accentLink),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Modals.showShareMenu(context);
              },
              icon: const Icon(Icons.reply, size: 18),
              label: const Text('Share'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Upgrade Modal
// ---------------------------------------------------------
class _UpgradeModal extends StatefulWidget {
  const _UpgradeModal();

  @override
  State<_UpgradeModal> createState() => _UpgradeModalState();
}

class _UpgradeModalState extends State<_UpgradeModal> {
  int _selectedTab = 0; // 0=Personal, 1=Education, 2=Business

  static const _tabs = ['Personal', 'Education', 'Business'];

  // Plan data per tab
  static const _plans = [
    _PlanData(
      name: 'Daemon Max',
      tagline: 'Advanced AI for everyday power users',
      price: 'US\$17',
      priceSuffix: '/month, billed annually',
      buttonLabel: 'Get Max',
      features: [
        'Access to latest AI models including GPT, Gemini, and Grok',
        'Daemon Sandbox with full file, connector, and live agent support',
        'Higher monthly token limits for heavy usage',
        'Priority response speed and queue',
        'Advanced web search with deeper source indexing',
      ],
    ),
    _PlanData(
      name: 'Daemon Edu',
      tagline: 'Powerful AI tools for students & educators',
      price: 'US\$9',
      priceSuffix: '/month with valid student email',
      buttonLabel: 'Get Edu',
      features: [
        'Same AI model access as Daemon Max at reduced cost',
        'Daemon Sandbox for research, coding, and academic projects',
        'Collaborative features for study groups',
        'Document analysis and citation-ready summaries',
        'Verified student & educator discount',
      ],
    ),
    _PlanData(
      name: 'Daemon Business',
      tagline: 'AI infrastructure for teams & enterprises',
      price: 'US\$39',
      priceSuffix: '/seat/month, billed annually',
      buttonLabel: 'Contact Sales',
      features: [
        'Unlimited seats with centralised billing',
        'Shared workspace and team chat history',
        'Custom MCP connectors and private tool integrations',
        'Audit logs, SSO, and enterprise-grade security',
        'Dedicated support and onboarding',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final plan = _plans[_selectedTab];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 24, left: 24, right: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textSecondary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Text(
            'Choose your plan',
            style: Theme.of(context).primaryTextTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to unlock the full power of Daemon AI.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Segmented tab switcher
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_tabs.length, (i) {
                final isActive = i == _selectedTab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: isActive
                        ? BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.accentLink.withValues(alpha: 0.5)),
                          )
                        : null,
                    child: Text(
                      _tabs[i],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isActive ? AppTheme.accentLink : AppTheme.textSecondary,
                          ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 32),
          // Pricing Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentLink.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLink.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Popular',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.accentLink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(plan.tagline, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(plan.price, style: Theme.of(context).textTheme.displaySmall),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
                      child: Text(plan.priceSuffix, style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: AppTheme.borderLight),
                const SizedBox(height: 16),
                Text('Everything in Free, plus:', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                for (final f in plan.features) _FeatureCheck(f),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Feature not available yet')),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(plan.buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanData {
  final String name;
  final String tagline;
  final String price;
  final String priceSuffix;
  final String buttonLabel;
  final List<String> features;

  const _PlanData({
    required this.name,
    required this.tagline,
    required this.price,
    required this.priceSuffix,
    required this.buttonLabel,
    required this.features,
  });
}

class _FeatureCheck extends StatelessWidget {
  final String text;

  const _FeatureCheck(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0, right: 12.0),
            child: Icon(Icons.check, size: 16, color: AppTheme.textSecondary),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
