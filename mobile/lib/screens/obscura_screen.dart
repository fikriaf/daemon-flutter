import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// ─── Constants ─────────────────────────────────────────────────────────────────

const _obscuraBaseUrl = 'https://api.obscura-app.com';
const _obscuraPurple = Color(0xFFB388FF);
const _obscuraCyan = Color(0xFF00E5FF);
const _prefsKey = 'obscura_deposit_notes';

// ─── Network config ────────────────────────────────────────────────────────────

class _Network {
  final String value;
  final String label;
  final String token;
  final String logoUrl;
  final String minDeposit;
  final List<String> features;

  const _Network({
    required this.value,
    required this.label,
    required this.token,
    required this.logoUrl,
    required this.minDeposit,
    required this.features,
  });
}

const _networks = [
  _Network(
    value: 'solana-devnet',
    label: 'Solana Devnet',
    token: 'SOL',
    logoUrl: 'https://cryptologos.cc/logos/solana-sol-logo.png',
    minDeposit: '0.0003',
    features: ['ZK Compression', 'Arcium MPC', 'cSPL Balance'],
  ),
  _Network(
    value: 'sepolia',
    label: 'Ethereum Sepolia',
    token: 'ETH',
    logoUrl: 'https://cryptologos.cc/logos/ethereum-eth-logo.png',
    minDeposit: '0.0003',
    features: ['Pedersen Commitments', 'Stealth Addresses'],
  ),
];

_Network _networkFor(String value) =>
    _networks.firstWhere((n) => n.value == value, orElse: () => _networks[0]);

// ─── Privacy levels ─────────────────────────────────────────────────────────────

class _PrivacyLevel {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final List<String> features;

  const _PrivacyLevel({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.features,
  });
}

const _privacyLevels = [
  _PrivacyLevel(
    value: 'shielded',
    label: 'Shielded',
    description: 'Maximum privacy',
    icon: Icons.shield_outlined,
    features: ['Stealth addresses', 'Encrypted amounts', 'No viewing keys'],
  ),
  _PrivacyLevel(
    value: 'compliant',
    label: 'Compliant',
    description: 'Audit-friendly',
    icon: Icons.visibility_outlined,
    features: ['Regulatory access', 'Sealed viewing keys', 'Selective disclosure'],
  ),
];

// ─── Obscura Features ──────────────────────────────────────────────────────────

const _obscuraFeatures = [
  (icon: Icons.fingerprint, title: 'Post-Quantum Security', desc: 'WOTS+ signatures resistant to quantum attacks'),
  (icon: Icons.storage_outlined, title: 'Arcium MPC', desc: 'Confidential computing on encrypted data'),
  (icon: Icons.layers_outlined, title: 'ZK Compression', desc: '~1000x cheaper storage via Light Protocol'),
  (icon: Icons.wifi_tethering, title: 'Relayer Network', desc: 'True privacy with nullifier-based claims'),
  (icon: Icons.lock_outlined, title: 'Graph Tracing Prevention', desc: 'Direct transfer breaks depositor-recipient link'),
  (icon: Icons.bolt_outlined, title: 'Off-Chain Balance', desc: 'Encrypted balances with Arcium cSPL'),
];

// ─── Main Screen ───────────────────────────────────────────────────────────────

class ObscuraScreen extends StatefulWidget {
  const ObscuraScreen({super.key});

  @override
  State<ObscuraScreen> createState() => _ObscuraScreenState();
}

class _ObscuraScreenState extends State<ObscuraScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Shared deposit notes (persisted)
  List<Map<String, dynamic>> _savedNotes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      if (mounted) {
        setState(() {
          _savedNotes = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    }
  }

  Future<void> _saveNote(Map<String, dynamic> note) async {
    final updated = [note, ..._savedNotes];
    setState(() => _savedNotes = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(updated));
  }

  Future<void> _removeNote(String commitment) async {
    final updated = _savedNotes.where((n) => n['commitment'] != commitment).toList();
    setState(() => _savedNotes = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(updated));
  }

  Map<String, dynamic>? _pendingWithdrawNote;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _obscuraPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: _obscuraPurple, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              'Obscura',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          // Status badges
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Text('Devnet', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text('Relayer', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _obscuraPurple,
          labelColor: _obscuraPurple,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Deposit'),
            Tab(text: 'Withdraw'),
            Tab(text: 'Balance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DepositTab(onDepositSaved: _saveNote),
          _WithdrawTab(
            savedNotes: _savedNotes,
            pendingNote: _pendingWithdrawNote,
            onNotePicked: () => setState(() => _pendingWithdrawNote = null),
            onNoteRemoved: _removeNote,
            onGoDeposit: () => _tabController.animateTo(0),
          ),
          const _BalanceTab(),
        ],
      ),
    );
  }
}

// ─── Deposit Tab ──────────────────────────────────────────────────────────────

class _DepositTab extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onDepositSaved;

  const _DepositTab({required this.onDepositSaved});

  @override
  State<_DepositTab> createState() => _DepositTabState();
}

class _DepositTabState extends State<_DepositTab> {
  String _network = 'solana-devnet';
  String _privacyLevel = 'shielded';
  final _amountCtrl = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _depositNote;
  String? _error;
  bool _showSuccessModal = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _deposit() async {
    final amount = _amountCtrl.text.trim();
    if (amount.isEmpty) return;
    final net = _networkFor(_network);
    final minAmt = double.tryParse(net.minDeposit) ?? 0;
    final inputAmt = double.tryParse(amount) ?? 0;
    if (inputAmt < minAmt) {
      setState(() => _error = 'Minimum deposit is ${net.minDeposit} ${net.token}');
      return;
    }

    setState(() {
      _isLoading = true;
      _depositNote = null;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_obscuraBaseUrl/api/v1/deposit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'network': _network,
          'token': 'native',
          'amount': amount,
          'privacyLevel': _privacyLevel,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;

      if ((response.statusCode == 200 || response.statusCode == 201) && body['success'] == true) {
        final note = {
          ...?(body['depositNote'] as Map<String, dynamic>?),
          'chainId': _network,
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'privacyLevel': _privacyLevel,
          'txHash': body['txHash'],
        };
        setState(() {
          _depositNote = note;
          _isLoading = false;
          _showSuccessModal = true;
        });
        await widget.onDepositSaved(note);
      } else {
        setState(() {
          _error = body['error']?.toString() ?? 'Deposit failed (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final net = _networkFor(_network);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Privacy Level ─────────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Privacy Level', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: _privacyLevels.map((level) {
                      final selected = _privacyLevel == level.value;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _privacyLevel = level.value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(right: level == _privacyLevels.last ? 0 : 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected ? _obscuraCyan.withValues(alpha: 0.08) : AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? _obscuraCyan : AppTheme.borderLight,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: selected ? _obscuraCyan.withValues(alpha: 0.2) : AppTheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    level.icon,
                                    size: 16,
                                    color: selected ? _obscuraCyan : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  level.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? _obscuraCyan : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  level.description,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: level.features.map((f) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(f, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary, fontSize: 9)),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Network + Amount ──────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Network dropdown
                  Text('Network', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _network,
                        isExpanded: true,
                        dropdownColor: AppTheme.surface,
                        style: Theme.of(context).textTheme.bodyMedium,
                        items: _networks.map((n) => DropdownMenuItem(
                          value: n.value,
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(n.logoUrl, width: 24, height: 24, fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) => const Icon(Icons.circle, size: 24),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(n.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                                    Text(
                                      'Min: ${n.minDeposit} ${n.token}',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) => setState(() => _network = v ?? _network),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Amount
                  Text('Amount (${net.token})', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: Theme.of(context).textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: 'Min: ${net.minDeposit}',
                              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPlaceholder),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              suffix: Text(net.token, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Minimum: ${net.minDeposit} ${net.token} (covers relayer fees)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder),
                  ),

                  const SizedBox(height: 20),

                  // Deposit button
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9333EA), _obscuraCyan],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _deposit,
                        icon: _isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download_outlined, size: 18, color: Colors.white),
                        label: Text(
                          _isLoading ? 'Processing Deposit...' : 'Deposit to Privacy Vault',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBox(message: _error!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Features Grid ─────────────────────────────────────
            _ObscuraFeaturesGrid(),

            const SizedBox(height: 16),

            // ── How it works ──────────────────────────────────────
            _HowItWorksSection(),

            const SizedBox(height: 100),
          ],
        ),

        // ── Success Modal ─────────────────────────────────────────
        if (_showSuccessModal && _depositNote != null)
          _DepositSuccessModal(
            note: _depositNote!,
            onClose: () => setState(() => _showSuccessModal = false),
          ),
      ],
    );
  }
}

// ─── Withdraw Tab ─────────────────────────────────────────────────────────────

class _WithdrawTab extends StatefulWidget {
  final List<Map<String, dynamic>> savedNotes;
  final Map<String, dynamic>? pendingNote;
  final VoidCallback onNotePicked;
  final Future<void> Function(String) onNoteRemoved;
  final VoidCallback onGoDeposit;

  const _WithdrawTab({
    required this.savedNotes,
    required this.pendingNote,
    required this.onNotePicked,
    required this.onNoteRemoved,
    required this.onGoDeposit,
  });

  @override
  State<_WithdrawTab> createState() => _WithdrawTabState();
}

class _WithdrawTabState extends State<_WithdrawTab> {
  String? _selectedCommitment;
  final _recipientCtrl = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void didUpdateWidget(_WithdrawTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingNote != null && widget.pendingNote != oldWidget.pendingNote) {
      setState(() => _selectedCommitment = widget.pendingNote!['commitment'] as String?);
      widget.onNotePicked();
    }
  }

  @override
  void dispose() {
    _recipientCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _selectedNote =>
      widget.savedNotes.cast<Map<String, dynamic>?>().firstWhere(
        (n) => n?['commitment'] == _selectedCommitment,
        orElse: () => null,
      );

  String _formatAmount(Map<String, dynamic> note) {
    final raw = note['amount'] as String? ?? '0';
    final lamports = int.tryParse(raw) ?? 0;
    return (lamports / 1e9).toStringAsFixed(6);
  }

  String _token(Map<String, dynamic>? note) {
    final chain = note?['chainId'] as String? ?? 'solana-devnet';
    return _networkFor(chain).token;
  }

  Future<void> _withdraw() async {
    final note = _selectedNote;
    if (note == null) {
      setState(() => _error = 'Select a deposit note first');
      return;
    }
    if (_recipientCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter recipient address');
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_obscuraBaseUrl/api/v1/withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'commitment': note['commitment'],
          'nullifierHash': note['nullifierHash'] ?? note['nullifier'],
          'recipient': _recipientCtrl.text.trim(),
          'amount': note['amount'],
          'chainId': note['chainId'] ?? 'solana-devnet',
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;

      if ((response.statusCode == 200 || response.statusCode == 201) && body['success'] == true) {
        setState(() {
          _result = body;
          _isLoading = false;
        });
        await widget.onNoteRemoved(_selectedCommitment!);
        setState(() => _selectedCommitment = null);
      } else {
        setState(() {
          _error = body['error']?.toString() ?? 'Withdrawal failed (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _selectedNote;
    final amount = note != null ? _formatAmount(note) : null;
    final token = _token(note);
    final fee = note != null ? (double.tryParse(amount ?? '0') ?? 0) * 0.001 : 0.0;
    final youReceive = note != null ? (double.tryParse(amount ?? '0') ?? 0) * 0.999 : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Select deposit note ───────────────────────────────────
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 18, color: _obscuraCyan),
                  const SizedBox(width: 8),
                  Text('Select Deposit to Withdraw', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.savedNotes.isEmpty)
                Column(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textPlaceholder),
                    const SizedBox(height: 8),
                    Text('No deposits found', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: widget.onGoDeposit,
                      child: Text('Make a deposit first', style: TextStyle(color: _obscuraCyan, fontSize: 13)),
                    ),
                  ],
                )
              else
                ...widget.savedNotes.reversed.map((n) {
                  final isSelected = _selectedCommitment == n['commitment'];
                  final net = _networkFor(n['chainId'] as String? ?? 'solana-devnet');
                  final amt = _formatAmount(n);
                  final savedAt = n['savedAt'] as int?;
                  final dateStr = savedAt != null
                      ? DateTime.fromMillisecondsSinceEpoch(savedAt).toLocal().toString().substring(0, 10)
                      : '';

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCommitment = n['commitment'] as String?),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? _obscuraCyan.withValues(alpha: 0.08) : AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _obscuraCyan : AppTheme.borderLight,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Radio indicator
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? _obscuraCyan : AppTheme.borderLight,
                                width: isSelected ? 5 : 2,
                              ),
                              color: isSelected ? _obscuraCyan : Colors.transparent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(net.logoUrl, width: 32, height: 32, fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => const Icon(Icons.circle, size: 32),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$amt ${net.token}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                Text(
                                  '$dateStr • ${net.label.split(' ')[0]}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _obscuraCyan.withValues(alpha: isSelected ? 0.2 : 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isSelected ? 'Selected' : 'Tap',
                              style: TextStyle(color: _obscuraCyan, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),

        if (note != null) ...[
          const SizedBox(height: 16),

          // ── Withdraw form ─────────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected deposit summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_networkFor(note['chainId'] as String? ?? 'solana-devnet').logoUrl,
                          width: 20, height: 20, fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const Icon(Icons.circle, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$amount $token available for withdrawal',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _selectedCommitment = null),
                        child: const Text('Change', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Recipient
                Text('Recipient Address', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: TextField(
                    controller: _recipientCtrl,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Enter recipient wallet address...',
                      hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPlaceholder),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Fee breakdown
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Network Fee (0.1%)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                          Text('${fee.toStringAsFixed(6)} $token', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('You Receive', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                          Text(
                            '${youReceive.toStringAsFixed(6)} $token',
                            style: TextStyle(color: _obscuraCyan, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Withdraw button
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_obscuraCyan, Color(0xFF2563EB)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _withdraw,
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_outlined, size: 18, color: Colors.white),
                      label: Text(
                        _isLoading ? 'Submitting to Relayer...' : 'Request Private Withdrawal',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(message: _error!),
                ],

                if (_result != null) ...[
                  const SizedBox(height: 12),
                  _WithdrawResultCard(result: _result!),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 100),
      ],
    );
  }
}

// ─── Balance Tab ──────────────────────────────────────────────────────────────

class _BalanceTab extends StatefulWidget {
  const _BalanceTab();

  @override
  State<_BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<_BalanceTab> {
  final _commitmentCtrl = TextEditingController();
  String _network = 'solana-devnet';
  bool _isLoading = false;
  Map<String, dynamic>? _balanceData;
  String? _error;

  @override
  void dispose() {
    _commitmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBalance() async {
    if (_commitmentCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a commitment');
      return;
    }
    if (_network != 'solana-devnet') {
      setState(() => _error = 'Balance query only supported on Solana (Arcium cSPL)');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _balanceData = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 1500)); // Mock delay
      // Mock balance data
      final mockBalance = {
        'success': true,
        'balance': '${(5000000000 * (0.1 + (DateTime.now().millisecond / 1000))).toInt()}',
        'pendingBalance': '0',
        'confidentialAccount': List.generate(32, (_) => (DateTime.now().microsecond % 256).toRadixString(16).padLeft(2, '0')).join(),
        'encrypted': true,
        'token': 'native',
        'deposits': 2,
        'withdrawals': 1,
      };
      if (!mounted) return;
      setState(() {
        _balanceData = mockBalance;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to query balance';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Commitment input
              Text('Commitment', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: TextField(
                  controller: _commitmentCtrl,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'Enter your commitment...',
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPlaceholder),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Network
              Text('Network', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _network,
                    isExpanded: true,
                    dropdownColor: AppTheme.surface,
                    style: Theme.of(context).textTheme.bodyMedium,
                    items: _networks.map((n) => DropdownMenuItem(
                      value: n.value,
                      child: Text('${n.label}${n.value == 'solana-devnet' ? ' (cSPL)' : ''}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _network = v ?? _network),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Check Balance button
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _checkBalance,
                    icon: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.storage_outlined, size: 18, color: Colors.white),
                    label: Text(
                      _isLoading ? 'Querying Arcium cSPL...' : 'Check Balance',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

              if (_network != 'solana-devnet') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(
                      'Balance query only available on Solana',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.amber),
                    ),
                  ],
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBox(message: _error!),
              ],
            ],
          ),
        ),

        // Balance result
        if (_balanceData != null) ...[
          const SizedBox(height: 16),
          _BalanceResultCard(data: _balanceData!),
        ],

        const SizedBox(height: 100),
      ],
    );
  }
}

// ─── Deposit Success Modal ────────────────────────────────────────────────────

class _DepositSuccessModal extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onClose;

  const _DepositSuccessModal({required this.note, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final commitment = note['commitment'] as String? ?? '';
    final nullifier = (note['nullifier'] as String?) ?? (note['nullifierHash'] as String?) ?? '';
    final secret = note['secret'] as String? ?? '';
    final txHash = note['txHash'] as String?;

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Deposit Successful!', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.w700)),
                            Text('Save your deposit note securely', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        onPressed: onClose,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Warning
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Save these fields — they are NOT stored anywhere else.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  _CopyField(label: 'Commitment (Public)', value: commitment),
                  const SizedBox(height: 8),
                  if (nullifier.isNotEmpty) _CopyField(label: 'Nullifier', value: nullifier, sensitive: true),
                  if (nullifier.isNotEmpty) const SizedBox(height: 8),
                  if (secret.isNotEmpty) _CopyField(label: 'Secret', value: secret, sensitive: true),
                  if (txHash != null) ...[
                    const SizedBox(height: 8),
                    _CopyField(label: 'TX Hash', value: txHash),
                  ],

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: jsonEncode(note)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Deposit note copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Full Deposit Note'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: child,
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  final bool sensitive;

  const _CopyField({required this.label, required this.value, this.sensitive = false});

  @override
  Widget build(BuildContext context) {
    final displayValue = value.length > 24
        ? '${value.substring(0, 10)}...${value.substring(value.length - 6)}'
        : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                displayValue,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: sensitive ? const Color(0xFFF85149) : AppTheme.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 14, color: AppTheme.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _WithdrawResultCard extends StatelessWidget {
  final Map<String, dynamic> result;

  const _WithdrawResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final status = result['status'] as String? ?? 'pending';
    final txHash = result['txHash'] as String?;
    final requestId = result['requestId'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text('Withdrawal ${status.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          if (requestId.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CopyField(label: 'Request ID', value: requestId),
          ],
          if (txHash != null) ...[
            const SizedBox(height: 6),
            _CopyField(label: 'TX Hash', value: txHash),
          ],
        ],
      ),
    );
  }
}

class _BalanceResultCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _BalanceResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final balance = (int.tryParse(data['balance'] as String? ?? '0') ?? 0) / 1e9;
    final pending = (int.tryParse(data['pendingBalance'] as String? ?? '0') ?? 0) / 1e9;
    final account = data['confidentialAccount'] as String? ?? '';
    final deposits = data['deposits'] as int? ?? 0;
    final withdrawals = data['withdrawals'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withValues(alpha: 0.12), const Color(0xFFEC4899).withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage_outlined, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Text('Balance Information', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.purple, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          _BalRow(label: 'Available Balance', value: '${balance.toStringAsFixed(6)} SOL', highlight: true),
          _BalRow(label: 'Pending', value: '${pending.toStringAsFixed(6)} SOL'),
          _BalRow(label: 'Confidential Account', value: '${account.substring(0, account.length.clamp(0, 16))}...', monospace: true),
          _BalRow(label: 'Encrypted', value: 'Yes', icon: Icons.lock_outlined),
          const Divider(height: 20),
          Row(
            children: [
              Text('Deposits: ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
              Text('$deposits', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              Text('Withdrawals: ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
              Text('$withdrawals', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.storage_outlined, size: 14, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Balance stored off-chain in Arcium cSPL (encrypted). No on-chain queries required.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.purple),
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

class _BalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool monospace;
  final IconData? icon;

  const _BalRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.monospace = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: Colors.green),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: TextStyle(
                  fontFamily: monospace ? 'monospace' : null,
                  fontSize: highlight ? 16 : 13,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                  color: highlight ? _obscuraCyan : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Features Grid ────────────────────────────────────────────────────────────

class _ObscuraFeaturesGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: _obscuraPurple, size: 18),
              const SizedBox(width: 8),
              Text('Obscura Privacy Architecture', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: _obscuraFeatures.map((f) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_obscuraPurple.withValues(alpha: 0.2), _obscuraCyan.withValues(alpha: 0.15)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(f.icon, size: 15, color: _obscuraCyan),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(f.title, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 10)),
                        Text(f.desc, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary, fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── How It Works ─────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      (color: Color(0xFF9333EA), step: '1', title: 'Deposit', desc: 'User deposits to Vault PDA. Balance encrypted with Arcium cSPL and stored off-chain.'),
      (color: _obscuraCyan, step: '2', title: 'Verify', desc: 'Off-chain verification via MPC. Check encrypted balance without revealing data.'),
      (color: Colors.green, step: '3', title: 'Withdraw', desc: 'Relayer transfers directly to recipient. No Vault PDA in transaction = true privacy!'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: _obscuraPurple, size: 18),
              const SizedBox(width: 8),
              Text('How Obscura Works', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  child: Center(
                    child: Text(s.step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(s.desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
