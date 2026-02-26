import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/app/bootstrap/providers.dart';
import 'package:mobile_app_entire/domain/repositories/credential_repository.dart';
import 'package:mobile_app_entire/features/settings/presentation/settings_controller.dart';
import 'package:mobile_app_entire/shared/widgets/error_banner.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _twelveController = TextEditingController();
  final _finnhubController = TextEditingController();
  final _glmController = TextEditingController();
  final _glmBaseController = TextEditingController();

  @override
  void dispose() {
    _twelveController.dispose();
    _finnhubController.dispose();
    _glmController.dispose();
    _glmBaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    _syncFields(state.credentials);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '설정',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _field(_twelveController, 'TwelveData API 키'),
          const SizedBox(height: 8),
          _field(_finnhubController, 'Finnhub API 키'),
          const SizedBox(height: 8),
          _field(_glmController, 'GLM API 키'),
          const SizedBox(height: 8),
          _field(_glmBaseController, 'GLM 기본 URL'),
          const SizedBox(height: 8),
          const Text(
            '키 없이도 앱 실행은 가능합니다. 실데이터 강제 모드 사용 시 TwelveData/Finnhub 실키가 필요하며 GLM은 선택입니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          if (state.error != null) ErrorBanner(message: state.error!),
          if (state.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.message!,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: state.loading ? null : _onSave,
                  child: const Text('키 저장'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: state.loading ? null : controller.clear,
                  child: const Text('초기화'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '테마',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('라이트')),
              ButtonSegment(value: ThemeMode.dark, label: Text('다크')),
              ButtonSegment(value: ThemeMode.system, label: Text('시스템')),
            ],
            selected: {ref.watch(themeModeProvider)},
            onSelectionChanged: (values) {
              controller.setThemeMode(values.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: label.contains('키'),
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  void _syncFields(ApiCredentials credentials) {
    if (_twelveController.text != credentials.twelveDataKey) {
      _twelveController.text = credentials.twelveDataKey;
    }
    if (_finnhubController.text != credentials.finnhubKey) {
      _finnhubController.text = credentials.finnhubKey;
    }
    if (_glmController.text != credentials.glmKey) {
      _glmController.text = credentials.glmKey;
    }
    if (_glmBaseController.text != credentials.glmBaseUrl) {
      _glmBaseController.text = credentials.glmBaseUrl;
    }
  }

  Future<void> _onSave() async {
    final controller = ref.read(settingsControllerProvider.notifier);
    await controller.save(
      ApiCredentials(
        twelveDataKey: _twelveController.text.trim(),
        finnhubKey: _finnhubController.text.trim(),
        glmKey: _glmController.text.trim(),
        glmBaseUrl: _glmBaseController.text.trim().isEmpty
            ? ApiCredentials.empty.glmBaseUrl
            : _glmBaseController.text.trim(),
      ),
    );
  }
}
