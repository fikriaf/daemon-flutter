import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar_drawer.dart';

class SandboxConnectorsScreen extends StatelessWidget {
  const SandboxConnectorsScreen({super.key});

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.laptop_chromebook, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Connectors',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search feature not available yet')));
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daemon can sync with your daily tools seamlessly,\ngiving it the ability to respond using real-time information.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          Text('Popular', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          Text('All categories', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: const [
                _ConnectorItem(title: 'Gmail', subtitle: 'Email from Google', iconColor: Colors.redAccent),
                _ConnectorItem(title: 'Outlook', subtitle: 'Email & Calendar from Microsoft', iconColor: Colors.blueAccent),
                _ConnectorItem(title: 'ActiveCampaign', subtitle: 'Marketing Automation & CRM', iconColor: Colors.indigoAccent),
                _ConnectorItem(title: 'Ahrefs', subtitle: 'All-in-one SEO Toolset', iconColor: Colors.orangeAccent),
                _ConnectorItem(title: 'Airtable', subtitle: 'Platform for building collaborative databases', iconColor: Colors.yellow),
                _ConnectorItem(title: 'Apollo.io', subtitle: 'Sales intelligence platform', iconColor: Colors.cyanAccent),
                _ConnectorItem(title: 'Attio', subtitle: 'CRM for the modern generation', iconColor: Colors.green),
                _ConnectorItem(title: 'AWS', subtitle: 'Amazon Web Services', iconColor: Colors.amber),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectorItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color iconColor;

  const _ConnectorItem({
    required this.title,
    required this.subtitle,
    required this.iconColor,
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(Icons.apps, color: iconColor, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connector cannot be enabled yet')));
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}
