import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar_drawer.dart';

class SandboxLiveScreen extends StatelessWidget {
  const SandboxLiveScreen({super.key});

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
            const Icon(Icons.live_tv, color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Live Examples',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Task',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.borderLight, height: 1),
          Expanded(
            child: ListView(
              children: const [
                _LiveTaskRow(
                  status: 'Completed',
                  isDone: true,
                  task: 'Analyzing OpenAI shareholder funding...',
                ),
                _LiveTaskRow(
                  status: 'Completed',
                  isDone: true,
                  task: 'Writing Python script for daily log data analysis...',
                ),
                _LiveTaskRow(
                  status: 'Completing shareh...',
                  isDone: false,
                  task: 'OpenAI Shareholders Funding analysis and summary report...',
                ),
                _LiveTaskRow(
                  status: 'Completed',
                  isDone: true,
                  task: 'Searching for articles related to AI innovations in 2026...',
                ),
                _LiveTaskRow(
                  status: 'Waiting...',
                  isDone: false,
                  task: 'Reading github repository for flutter documentation...',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTaskRow extends StatelessWidget {
  final String status;
  final bool isDone;
  final String task;

  const _LiveTaskRow({
    required this.status,
    required this.isDone,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                  color: isDone ? Colors.green : AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              task,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
