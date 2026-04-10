import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/auth_state.dart';
import '../services/provider.dart';
import '../services/agent_service.dart';
import 'skeleton.dart';

class SidebarDrawer extends ConsumerStatefulWidget {
  /// Optional callback for screens (e.g. RootScreen) that handle session
  /// loading internally. When null, the sidebar navigates automatically.
  final void Function(ChatSession session)? onSessionTap;
  const SidebarDrawer({super.key, this.onSessionTap});

  @override
  ConsumerState<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends ConsumerState<SidebarDrawer> {
  List<ChatSession> _sessions = [];
  bool _loadingHistory = false;
  bool _historyError = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = false;
    });
    try {
      final sessions = await apiProvider.agentService.getChats();
      if (mounted)
        setState(() {
          _sessions = sessions;
          _loadingHistory = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingHistory = false;
          _historyError = true;
        });
    }
  }

  void _onSessionTap(BuildContext context, ChatSession session) {
    if (widget.onSessionTap != null) {
      Navigator.pop(context); // close drawer
      widget.onSessionTap!(session);
      return;
    }
    // Fallback: capture current path BEFORE popping (context may detach after pop),
    // then navigate to home with the session. Discover/Finance always pass
    // onSessionTap so this branch is only hit for unknown/future screens.
    final currentPath = GoRouterState.of(context).uri.toString();
    Navigator.pop(context);
    if (!currentPath.startsWith('/discover') &&
        !currentPath.startsWith('/finance')) {
      context.go('/', extra: session);
    }
    // If somehow on discover/finance without onSessionTap, do nothing — the
    // callback path above handles it; here we just close the drawer cleanly.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.isLoggedIn;

    // Get the current path to determine context and active state
    final currentPath = GoRouterState.of(context).uri.toString();
    final isSandboxContext = currentPath.startsWith('/sandbox');

    return Drawer(
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo / Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/daemonprotocol_logo_White_transparent.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Daemon',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Context Switcher (Always visible)
            _DrawerItem(
              icon: Icons.search,
              title: 'Home',
              isActive: currentPath == '/',
              onTap: () {
                Navigator.pop(context);
                context.go('/');
              },
            ),
            _DrawerItem(
              icon: Icons.laptop_chromebook,
              title: 'Sandbox',
              isActive: currentPath == '/sandbox',
              onTap: () {
                Navigator.pop(context);
                context.go('/sandbox');
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Divider(color: AppTheme.borderLight),
            ),

            // Dynamic Context Menu
            if (isSandboxContext) ...[
              _DrawerItem(
                icon: Icons.electrical_services,
                title: 'Connectors',
                isActive: currentPath == '/sandbox/connectors',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/sandbox/connectors');
                },
              ),
              _DrawerItem(
                icon: Icons.folder_outlined,
                title: 'Files',
                isActive: currentPath == '/sandbox/files',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/sandbox/files');
                },
              ),
              _DrawerItem(
                icon: Icons.live_tv,
                title: 'Live Examples',
                isActive: currentPath == '/sandbox/live',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/sandbox/live');
                },
              ),
            ] else ...[
              _DrawerItem(
                icon: Icons.explore_outlined,
                title: 'Discover',
                isActive: currentPath == '/discover',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/discover');
                },
              ),
              _DrawerItem(
                icon: Icons.show_chart,
                title: 'Finance',
                isActive: currentPath == '/finance',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/finance');
                },
              ),
              _DrawerItem(
                icon: Icons.radar,
                title: 'World Radar',
                isActive: currentPath == '/worldmonitor',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/worldmonitor');
                },
              ),
              _DrawerItem(
                icon: Icons.verified_user,
                title: 'Audit',
                isActive: currentPath == '/audit',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/audit');
                },
              ),
              _DrawerItem(
                icon: Icons.folder_outlined,
                title: 'Library',
                isActive: currentPath == '/library',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/library');
                },
              ),
              _DrawerItem(
                icon: Icons.grid_view,
                title: 'Spaces',
                isActive: currentPath == '/spaces',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/spaces');
                },
              ),
            ],

            const SizedBox(height: 24),

            // History section — always shown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'History',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (!_loadingHistory &&
                      (_sessions.isNotEmpty || _historyError))
                    GestureDetector(
                      onTap: _loadHistory,
                      child: const Icon(
                        Icons.refresh,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loadingHistory
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 4,
                      itemBuilder: (_, i) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: SkeletonListTile(hasSubtitle: false),
                      ),
                    )
                  : _historyError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppTheme.textSecondary,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Could not load history',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: _loadHistory,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _sessions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.history,
                          color: AppTheme.textSecondary,
                          size: 32,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          leading: const Icon(
                            Icons.chat_bubble_outline,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          title: Text(
                            session.title,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _onSessionTap(context, session),
                        );
                      },
                    ),
            ),

            // Bottom section: User profile & settings
            const Divider(color: AppTheme.border, height: 1),
            if (isLoggedIn)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppTheme.avatarBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      authState.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  authState.email ?? 'User',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: authState.walletAddress != null
                    ? Text(
                        '${authState.walletAddress!.substring(0, 6)}...${authState.walletAddress!.substring(authState.walletAddress!.length - 4)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/settings');
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () {
                        ref.read(authStateProvider.notifier).logout();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              )
            else
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: const Icon(
                    Icons.login,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                ),
                title: Text(
                  'Sign In',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  'Connect wallet & email',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/login');
                },
              ),
          ],
        ),
      ),
    );
  }
} // end _SidebarDrawerState

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        icon,
        color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
          fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}
