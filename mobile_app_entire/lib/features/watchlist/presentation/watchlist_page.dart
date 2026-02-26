import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app_entire/features/watchlist/presentation/watchlist_controller.dart';
import 'package:mobile_app_entire/shared/widgets/error_banner.dart';

class WatchlistPage extends ConsumerStatefulWidget {
  const WatchlistPage({super.key});

  @override
  ConsumerState<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends ConsumerState<WatchlistPage> {
  final _tickerController = TextEditingController();

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchlistControllerProvider);
    final controller = ref.read(watchlistControllerProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '관심종목',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tickerController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: '티커',
                    hintText: '예: 005930',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: state.loading
                    ? null
                    : () async {
                        await controller.add(_tickerController.text);
                        _tickerController.clear();
                      },
                child: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: state.loading ? null : _pickCsv,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('CSV 가져오기 (전체 교체)'),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            ErrorBanner(message: state.error!),
          ],
          const SizedBox(height: 10),
          if (state.loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          if (state.items.isEmpty)
            const Text('관심종목이 없습니다.')
          else
            ...state.items.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item.ticker),
                  subtitle: item.alias == null ? null : Text(item.alias!),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => controller.remove(item.ticker),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickCsv() async {
    final controller = ref.read(watchlistControllerProvider.notifier);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    final csvRaw = utf8.decode(bytes, allowMalformed: true);
    await controller.importCsv(csvRaw);
  }
}
