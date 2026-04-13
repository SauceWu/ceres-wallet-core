import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ceres_wallet_core/ceres_wallet_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const WalletDemoApp());
}

class WalletDemoApp extends StatelessWidget {
  const WalletDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Ceres Wallet Core Demo', theme: ThemeData(primarySwatch: Colors.blue), home: const WalletDemoPage());
  }
}

class WalletDemoPage extends StatefulWidget {
  const WalletDemoPage({super.key});

  @override
  State<WalletDemoPage> createState() => _WalletDemoPageState();
}

class _WalletDemoPageState extends State<WalletDemoPage> {
  TWHDWallet? _wallet;
  String _mnemonic = '';
  final Map<String, String> _addresses = {};
  String _status = 'Ready';

  static const _coins = [
    ('Ethereum', TWCoinType.TWCoinTypeEthereum),
    ('Solana', TWCoinType.TWCoinTypeSolana),
    ('Sui', TWCoinType.TWCoinTypeSui),
    ('Tron', TWCoinType.TWCoinTypeTron),
  ];

  void _createWallet() {
    setState(() => _status = 'Creating...');
    try {
      _wallet?.delete();
      _wallet = TWHDWallet();
      _mnemonic = _wallet!.mnemonic;
      _deriveAddresses();
      _status = 'Wallet created';
    } catch (e) {
      _status = 'Error: $e';
      print('Error creating wallet: $e');
    }
    setState(() {});
  }

  void _importWallet(String mnemonic) {
    setState(() => _status = 'Importing...');
    try {
      if (!TWMnemonic.isValid(mnemonic)) {
        setState(() => _status = 'Invalid mnemonic');
        return;
      }
      _wallet?.delete();
      _wallet = TWHDWallet.createWithMnemonic(mnemonic);
      _mnemonic = _wallet!.mnemonic;
      _deriveAddresses();
      _status = 'Wallet imported';
    } catch (e) {
      _status = 'Error: $e';
    }
    setState(() {});
  }

  void _deriveAddresses() {
    _addresses.clear();
    for (final (name, coin) in _coins) {
      try {
        _addresses[name] = _wallet!.getAddressForCoin(coin);
      } catch (e) {
        _addresses[name] = 'Error: $e';
      }
    }
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Import Wallet'),
            content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Enter mnemonic...', border: OutlineInputBorder()), maxLines: 3),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _importWallet(controller.text.trim());
                },
                child: const Text('Import'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _wallet?.delete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ceres Wallet Core'), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_status)),
            const SizedBox(height: 16),
            // Buttons
            Row(children: [Expanded(child: ElevatedButton.icon(onPressed: _createWallet, icon: const Icon(Icons.add), label: const Text('Create'))), const SizedBox(width: 12), Expanded(child: ElevatedButton.icon(onPressed: _showImportDialog, icon: const Icon(Icons.download), label: const Text('Import')))]),
            // Mnemonic
            if (_mnemonic.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Mnemonic', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _mnemonic));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                            },
                          ),
                        ],
                      ),
                      Text(_mnemonic, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
            // Addresses
            ..._addresses.entries.map(
              (e) => Card(
                child: ListTile(
                  title: Text(e.key),
                  subtitle: SelectableText(e.value, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: e.value));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.key} copied')));
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
