import 'package:flutter/material.dart';
import 'package:flutter_vless/flutter_vless.dart';

const _defaultVlessLink =
    'vless://72e961e9-e96d-4f64-9482-692da6c01ff8@aeza-ru1-v4sihphi6rbh.radshim.com:443'
    '?security=reality&encryption=none'
    '&pbk=SM8JROBBDXJccp-L4fRO1LMwQgujJ7u3MA9pc67z5FE'
    '&headerType=&fp=chrome&spx=%2FKGxo1rMH1RSSpOc&type=tcp'
    '&flow=xtls-rprx-vision'
    '&sni=aeza-ru1-v4sihphi6rbh.radshim.com&sid=581c23905ebf9f'
    '#-0zir7ni6ni%5B10GB%5D2%7C%F0%9F%93%8A10.00GB%7C%E2%8F%B310D';

void main() {
  runApp(const VpnApp());
}

class VpnApp extends StatelessWidget {
  const VpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VLESS VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final FlutterVless _flutterVless;
  late final TextEditingController _linkController;

  VlessStatus _status = VlessStatus();
  bool _busy = false;
  bool _initialized = false;

  bool get _isConnected =>
      _status.connectionState == VlessConnectionState.connected ||
      _status.connectionState == VlessConnectionState.connecting;

  @override
  void initState() {
    super.initState();
    _linkController = TextEditingController(text: _defaultVlessLink);
    _flutterVless = FlutterVless(
      onStatusChanged: (status) {
        if (!mounted) return;
        setState(() => _status = status);
      },
    );
    _initPlugin();
  }

  Future<void> _initPlugin() async {
    try {
      // iOS/macOS: base app bundle id + App Group shared with XrayTunnel.
      // The plugin appends ".XrayTunnel" to the provider id internally.
      await _flutterVless.initializeVless(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
        providerBundleIdentifier: 'com.example.vpnVless',
        groupIdentifier: 'group.com.example.vpnVless',
      );
      if (!mounted) return;
      setState(() => _initialized = true);
    } catch (e) {
      _showError('Failed to initialize: $e');
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;

    if (_isConnected) {
      await _disconnect();
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      _showError('Paste a vless:// link first.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (!_initialized) {
        await _initPlugin();
      }

      final parsed = FlutterVless.parse(link);
      final allowed = await _flutterVless.requestPermission();
      if (!allowed) {
        _showError('VPN permission was denied.');
        return;
      }

      await _flutterVless.startVless(
        remark: parsed.remark.isEmpty ? 'VLESS' : parsed.remark,
        config: parsed.getFullConfiguration(),
      );
    } catch (e) {
      _showError('Connect failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await _flutterVless.stopVless();
    } catch (e) {
      _showError('Disconnect failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get _statusLabel {
    switch (_status.connectionState) {
      case VlessConnectionState.connected:
        return 'Connected';
      case VlessConnectionState.connecting:
        return 'Connecting…';
      case VlessConnectionState.disconnecting:
        return 'Disconnecting…';
      case VlessConnectionState.disconnected:
        return 'Disconnected';
      case VlessConnectionState.unknown:
        return _status.state.isEmpty ? 'Disconnected' : _status.state;
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        _status.connectionState == VlessConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VLESS VPN'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _linkController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'VLESS link',
                  hintText: 'vless://…',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _statusLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: connected
                          ? Colors.greenAccent
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                '↓ ${_formatBytes(_status.download)}   ↑ ${_formatBytes(_status.upload)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _toggle,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: connected
                      ? Colors.redAccent
                      : Theme.of(context).colorScheme.primary,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        connected ||
                                _status.connectionState ==
                                    VlessConnectionState.connecting
                            ? 'Disconnect'
                            : 'Connect',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
