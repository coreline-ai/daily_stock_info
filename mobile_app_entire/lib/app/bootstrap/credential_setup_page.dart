import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/app/bootstrap/providers.dart';
import 'package:mobile_app_entire/domain/repositories/credential_repository.dart';
import 'package:mobile_app_entire/shared/widgets/error_banner.dart';

class CredentialSetupPage extends ConsumerStatefulWidget {
  const CredentialSetupPage({super.key});

  @override
  ConsumerState<CredentialSetupPage> createState() =>
      _CredentialSetupPageState();
}

class _CredentialSetupPageState extends ConsumerState<CredentialSetupPage> {
  static const _defaultGlmBaseUrl = 'https://open.bigmodel.cn/api/paas/v4';

  final _twelveController = TextEditingController();
  final _finnhubController = TextEditingController();
  final _glmController = TextEditingController();
  final _glmBaseController = TextEditingController(text: _defaultGlmBaseUrl);

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _twelveController.dispose();
    _finnhubController.dispose();
    _glmController.dispose();
    _glmBaseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(credentialRepositoryProvider);
    final result = await repository.load();
    result.when(
      success: (credentials) {
        _twelveController.text = credentials.twelveDataKey;
        _finnhubController.text = credentials.finnhubKey;
        _glmController.text = credentials.glmKey;
        _glmBaseController.text = credentials.glmBaseUrl.isEmpty
            ? _defaultGlmBaseUrl
            : credentials.glmBaseUrl;
      },
      failure: (_) {},
    );
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final twelve = _twelveController.text.trim();
    final finnhub = _finnhubController.text.trim();
    final glm = _glmController.text.trim();
    final glmBaseUrl = _glmBaseController.text.trim().isEmpty
        ? _defaultGlmBaseUrl
        : _glmBaseController.text.trim();

    bool invalidKey(String value) =>
        value.isEmpty || value.toLowerCase() == 'demo';
    final glmIsDemo = glm.toLowerCase() == 'demo';
    if (invalidKey(twelve) || invalidKey(finnhub)) {
      setState(() {
        _error = '실데이터 강제 모드에서는 TwelveData/Finnhub 키를 실제 발급값으로 입력해야 합니다.';
      });
      return;
    }
    if (glmIsDemo) {
      setState(() {
        _error = 'GLM 키를 입력할 경우 demo가 아닌 실제 발급 키를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repository = ref.read(credentialRepositoryProvider);
    final result = await repository.save(
      ApiCredentials(
        twelveDataKey: twelve,
        finnhubKey: finnhub,
        glmKey: glm,
        glmBaseUrl: glmBaseUrl,
      ),
    );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.invalidate(apiKeysReadyProvider);
      },
      failure: (failure) {
        setState(() {
          _error = failure.message;
        });
      },
    );

    setState(() {
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '초기 API 키 설정',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '실데이터 강제 모드가 활성화되어 있어 TwelveData/Finnhub 키 입력 전에는 앱을 사용할 수 없습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              'GLM 키는 선택입니다. 비워두면 AI 리포트 기능만 제한됩니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _field(_twelveController, 'TwelveData API 키'),
            const SizedBox(height: 10),
            _field(_finnhubController, 'Finnhub API 키'),
            const SizedBox(height: 10),
            _field(_glmController, 'GLM API 키'),
            const SizedBox(height: 10),
            _field(_glmBaseController, 'GLM 기본 URL', obscure: false),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '저장 중...' : '저장하고 시작하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = true,
  }) {
    final shouldObscure = obscure && label.contains('키');
    return TextField(
      controller: controller,
      obscureText: shouldObscure,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
