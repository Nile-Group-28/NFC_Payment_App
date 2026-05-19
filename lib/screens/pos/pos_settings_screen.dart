// lib/screens/pos/pos_settings_screen.dart
import 'package:flutter/material.dart';
import '../../services/pos_service.dart';
import '../../services/api_service.dart';

class POSSettingsScreen extends StatefulWidget {
  const POSSettingsScreen({super.key});
  @override
  State<POSSettingsScreen> createState() => _POSSettingsScreenState();
}

class _POSSettingsScreenState extends State<POSSettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving  = false;

  final _nameCtrl     = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _footerCtrl   = TextEditingController();

  bool   _tipEnabled  = false;
  double _taxRate     = 0;
  List<int> _tipPresets = [5, 10, 15, 20];
  String _settlementFreq = 'DAILY';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await PosApi.activate();
      final p   = res['profile'] as Map<String, dynamic>? ?? {};
      setState(() {
        _profile        = p;
        _nameCtrl.text     = p['business_name']     as String? ?? '';
        _categoryCtrl.text = p['business_category'] as String? ?? '';
        _addressCtrl.text  = p['business_address']  as String? ?? '';
        _phoneCtrl.text    = p['business_phone']    as String? ?? '';
        _footerCtrl.text   = p['receipt_footer_text'] as String? ?? '';
        _tipEnabled        = p['tip_enabled'] as bool? ?? false;
        _taxRate           = (p['tax_rate'] as num?)?.toDouble() ?? 0;
        _settlementFreq    = p['settlement_frequency'] as String? ?? 'DAILY';
        final presets      = p['tip_preset_percentages'];
        if (presets is List) _tipPresets = presets.cast<int>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await PosApi.activate(
        businessName:         _nameCtrl.text.trim(),
        businessCategory:     _categoryCtrl.text.trim(),
        businessAddress:      _addressCtrl.text.trim(),
        businessPhone:        _phoneCtrl.text.trim(),
        taxRate:              _taxRate,
        tipEnabled:           _tipEnabled,
        tipPresets:           _tipPresets,
        receiptFooter:        _footerCtrl.text.trim(),
        settlementFrequency:  _settlementFreq,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved.')),
        );
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Business Information'),
                _field('Business Name',     _nameCtrl),
                _field('Business Category', _categoryCtrl),
                _field('Address',           _addressCtrl),
                _field('Phone',             _phoneCtrl, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                _section('Tax Settings'),
                Row(
                  children: [
                    const Expanded(child: Text('Tax Rate (%)')),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: TextEditingController(text: _taxRate.toString())
                          ..selection = TextSelection.collapsed(offset: _taxRate.toString().length),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) => _taxRate = double.tryParse(v) ?? 0,
                        decoration: const InputDecoration(suffixText: '%', isDense: true),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section('Tip Settings'),
                SwitchListTile(
                  title: const Text('Enable Tips'),
                  value: _tipEnabled,
                  onChanged: (v) => setState(() => _tipEnabled = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_tipEnabled)
                  Wrap(
                    spacing: 8,
                    children: [5, 10, 15, 20].map((pct) => FilterChip(
                      label: Text('$pct%'),
                      selected: _tipPresets.contains(pct),
                      onSelected: (on) {
                        setState(() {
                          if (on) _tipPresets.add(pct);
                          else    _tipPresets.remove(pct);
                        });
                      },
                    )).toList(),
                  ),
                const SizedBox(height: 16),
                _section('Receipt'),
                _field('Receipt Footer Message', _footerCtrl, maxLines: 3),
                const SizedBox(height: 16),
                _section('Settlement'),
                DropdownButtonFormField<String>(
                  value: _settlementFreq,
                  decoration: const InputDecoration(
                    labelText: 'Settlement Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'INSTANT', child: Text('Instant')),
                    DropdownMenuItem(value: 'DAILY',   child: Text('Daily')),
                    DropdownMenuItem(value: 'WEEKLY',  child: Text('Weekly')),
                  ],
                  onChanged: (v) => setState(() => _settlementFreq = v ?? 'DAILY'),
                ),
              ],
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepPurple)),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
