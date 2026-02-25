import 'package:coreline_stock_ai/core/network/dio_client.dart';
import 'package:coreline_stock_ai/shared/models/app_settings.dart';
import 'package:coreline_stock_ai/shared/providers/app_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _apiController;
  late final TextEditingController _timeoutController;
  String _versionText = '-';
  bool _checkingHealth = false;
  String? _healthStatus;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _apiController = TextEditingController(text: settings.apiBaseUrl);
    _timeoutController = TextEditingController(text: settings.timeoutSeconds.toString());
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _versionText = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  void dispose() {
    _apiController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final cache = ref.read(localCacheProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            TextField(
              controller: _apiController,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'http://127.0.0.1:8000',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _timeoutController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              decoration: const InputDecoration(labelText: '요청 타임아웃(초)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppThemePreference>(
              initialValue: settings.theme,
              decoration: const InputDecoration(labelText: '테마 모드'),
              items: const [
                DropdownMenuItem(value: AppThemePreference.system, child: Text('시스템')), 
                DropdownMenuItem(value: AppThemePreference.light, child: Text('라이트')),
                DropdownMenuItem(value: AppThemePreference.dark, child: Text('다크')),
              ],
              onChanged: (value) {
                if (value != null) {
                  notifier.updateTheme(value);
                }
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await notifier.updateApiBaseUrl(_apiController.text);
                    final timeout = int.tryParse(_timeoutController.text.trim()) ?? 15;
                    await notifier.updateTimeoutSeconds(timeout.clamp(5, 120));
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('설정이 저장되었습니다.')),
                    );
                  },
                  child: const Text('설정 저장'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await cache.clearTransientCache();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('캐시를 초기화했습니다.')),
                    );
                  },
                  child: const Text('캐시 초기화'),
                ),
                OutlinedButton.icon(
                  onPressed: _checkingHealth ? null : _checkHealth,
                  icon: const Icon(Icons.health_and_safety_outlined, size: 16),
                  label: Text(_checkingHealth ? '확인 중...' : '서버 헬스체크'),
                ),
              ],
            ),
            if (_healthStatus != null) ...[
              const SizedBox(height: 10),
              Text(_healthStatus!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App Info', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Version: $_versionText'),
                    const SizedBox(height: 4),
                    const Text('인증: user_key=default (무인증 모드)'),
                    const SizedBox(height: 4),
                    const Text('자동 폴링: 비활성 (사용자 입력 시 로딩)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkHealth() async {
    final dio = ref.read(dioProvider);
    setState(() {
      _checkingHealth = true;
      _healthStatus = null;
    });
    try {
      final response = await dio.get<Object>('/api/v1/health');
      setState(() {
        _healthStatus = 'OK: ${response.data}';
      });
    } on DioException catch (error) {
      setState(() {
        _healthStatus = '헬스체크 실패: ${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingHealth = false;
        });
      }
    }
  }
}
