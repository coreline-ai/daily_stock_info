import 'package:coreline_stock_ai/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:coreline_stock_ai/features/watchlist/presentation/providers/watchlist_providers.dart';
import 'package:coreline_stock_ai/shared/widgets/error_banner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WatchlistPage extends ConsumerStatefulWidget {
  const WatchlistPage({super.key});

  @override
  ConsumerState<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends ConsumerState<WatchlistPage> {
  late final TextEditingController _tickerController;

  @override
  void initState() {
    super.initState();
    _tickerController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchlistControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchlistControllerProvider);
    final controller = ref.read(watchlistControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          IconButton(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tickerController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: '티커 추가 (예: 005930)',
                          ),
                          onSubmitted: (_) => _addTicker(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _addTicker, child: const Text('추가')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('CSV 업로드 replace 모드'),
                          value: state.replaceMode,
                          onChanged: controller.setReplaceMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _uploadCsv,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('CSV 업로드'),
                      ),
                    ],
                  ),
                  if (state.notice != null && state.notice!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          state.notice!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  if (state.error != null && state.error!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ErrorBanner(message: state.error!),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: state.loading && state.tickers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      itemCount: state.tickers.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ticker = state.tickers[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(ticker),
                            trailing: IconButton(
                              onPressed: () => _deleteTicker(ticker),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTicker() async {
    final ticker = _tickerController.text.trim();
    if (ticker.isEmpty) {
      return;
    }
    await ref.read(watchlistControllerProvider.notifier).addTicker(ticker);
    _tickerController.clear();
    if (!mounted) return;
    await ref.read(dashboardControllerProvider.notifier).reload(reason: 'watchlist-add');
  }

  Future<void> _deleteTicker(String ticker) async {
    await ref.read(watchlistControllerProvider.notifier).deleteTicker(ticker);
    if (!mounted) return;
    await ref.read(dashboardControllerProvider.notifier).reload(reason: 'watchlist-delete');
  }

  Future<void> _uploadCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 데이터를 읽지 못했습니다.')),
      );
      return;
    }

    await ref.read(watchlistControllerProvider.notifier).uploadCsv(
          bytes: bytes,
          filename: file.name,
        );
    if (!mounted) return;
    await ref.read(dashboardControllerProvider.notifier).reload(reason: 'watchlist-csv');
  }
}
