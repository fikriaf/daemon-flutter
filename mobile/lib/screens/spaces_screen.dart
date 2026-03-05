import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar_drawer.dart';
import 'package:go_router/go_router.dart';

class SpacesScreen extends StatelessWidget {
  const SpacesScreen({super.key});

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
        title: Image.asset(
          'assets/images/daemonprotocol_logo_White_transparent_text.png',
          height: 24,
          fit: BoxFit.contain,
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          // ── Your Tools ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Your Tools',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Cyclops hero card
          _HeroToolCard(
            title: 'Cyclops',
            subtitle: 'Wallet Risk Analyzer',
            description: 'Scan any ETH, Solana, or Bitcoin address for OFAC sanctions, risk score, and on-chain entity labels.',
            badge: 'Risk Analysis',
            gradientColors: const [Color(0xFF003D40), Color(0xFF191A1A)],
            accentColor: const Color(0xFF00E5FF),
            icon: Icons.remove_red_eye_outlined,
            stats: const [
              _StatChip(label: 'Multi-chain', icon: Icons.link),
              _StatChip(label: 'OFAC', icon: Icons.gavel_outlined),
              _StatChip(label: 'Real-time', icon: Icons.bolt_outlined),
            ],
            onTap: () => context.push('/spaces/cyclops'),
          ),

          const SizedBox(height: 12),

          // Obscura hero card
          _HeroToolCard(
            title: 'Obscura',
            subtitle: 'Private Sender',
            description: 'Deposit and withdraw SOL or ETH with full on-chain privacy via post-quantum relayer network.',
            badge: 'Privacy',
            gradientColors: const [Color(0xFF1A0D2E), Color(0xFF191A1A)],
            accentColor: const Color(0xFFB388FF),
            icon: Icons.shield_outlined,
            logoAsset: 'assets/images/logo_obscura_white_no-text.png',
            stats: const [
              _StatChip(label: 'Post-quantum', icon: Icons.lock_outlined),
              _StatChip(label: 'SOL & ETH', icon: Icons.currency_bitcoin_outlined),
              _StatChip(label: 'Relayer', icon: Icons.device_hub_outlined),
            ],
            onTap: () => context.push('/spaces/obscura'),
          ),

          const SizedBox(height: 12),

          // World Monitor hero card
          _HeroToolCard(
            title: 'World Monitor',
            subtitle: 'Global Intelligence Dashboard',
            description: 'Real-time global intelligence: live news, markets, military tracking, flight & ship AIS, earthquakes, and geopolitical data in one view.',
            badge: 'OSINT',
            gradientColors: const [Color(0xFF003300), Color(0xFF191A1A)],
            accentColor: const Color(0xFF00E676),
            icon: Icons.public,
            stats: const [
              _StatChip(label: 'Live News', icon: Icons.rss_feed),
              _StatChip(label: 'AIS Tracking', icon: Icons.directions_boat_outlined),
              _StatChip(label: 'Geo Intel', icon: Icons.travel_explore),
            ],
            onTap: () => context.push('/spaces/worldmonitor'),
          ),

          const SizedBox(height: 32),

          // ── Discover Tools ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Discover',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Coming Soon',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: const [
                _DiscoverCard(
                  title: 'Dark OTC',
                  subtitle: 'Private OTC trades',
                  icon: Icons.swap_horiz,
                  accentColor: Color(0xFFFFB74D),
                ),
                _DiscoverCard(
                  title: 'Chain Radar',
                  subtitle: 'On-chain analytics',
                  icon: Icons.radar,
                  accentColor: Color(0xFF69F0AE),
                ),
                _DiscoverCard(
                  title: 'Sentinel',
                  subtitle: 'Wallet monitoring',
                  icon: Icons.notifications_active_outlined,
                  accentColor: Color(0xFFFF5252),
                ),
                _DiscoverCard(
                  title: 'Vault',
                  subtitle: 'Secure storage',
                  icon: Icons.lock_outline,
                  accentColor: Color(0xFF40C4FF),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Invitations ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Invitations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, color: AppTheme.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'No pending invitations',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Tool Card ───────────────────────────────────────────────────────────

class _HeroToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final String badge;
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;
  final String? logoAsset;
  final List<_StatChip> stats;
  final VoidCallback onTap;

  const _HeroToolCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badge,
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
    this.logoAsset,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: logoAsset != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  logoAsset!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          : Icon(icon, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: accentColor.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: accentColor.withValues(alpha: 0.5), size: 20),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 14),

                // Stat chips row
                Wrap(
                  spacing: 8,
                  children: stats,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Discover Card ────────────────────────────────────────────────────────────

class _DiscoverCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _DiscoverCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor.withValues(alpha: 0.6), size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Soon',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textPlaceholder,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textPlaceholder,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
