import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../../domain/models/incienso.dart';
import '../../utils/constants/generator_translation_constants.dart';

/// Selection loads parameters; Play remains an explicit action.
class ChamberSessionsButton extends StatelessWidget {
  final Future<List<Incienso>> Function() loadSessions;
  final Future<void> Function(Incienso) onSelected;
  final bool Function(String)? isFavorite;
  final Future<void> Function(String)? onToggleFavorite;
  final Future<void> Function(Incienso)? onExport;
  final String Function()? errorMessage;
  const ChamberSessionsButton({
    super.key,
    required this.loadSessions,
    required this.onSelected,
    this.isFavorite,
    this.onToggleFavorite,
    this.onExport,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    icon: const Icon(Icons.history),
    label: Text(GeneratorTranslationConstants.mySessions.tr),
    onPressed: () async {
      final selected = await showDialog<Incienso>(
        context: context,
        builder: (_) => _SessionsDialog(
          loadSessions: loadSessions,
          isFavorite: isFavorite,
          onToggleFavorite: onToggleFavorite,
          onExport: onExport,
          errorMessage: errorMessage,
        ),
      );
      if (selected != null && context.mounted) await onSelected(selected);
    },
  );
}

class _SessionsDialog extends StatefulWidget {
  final Future<List<Incienso>> Function() loadSessions;
  final bool Function(String)? isFavorite;
  final Future<void> Function(String)? onToggleFavorite;
  final Future<void> Function(Incienso)? onExport;
  final String Function()? errorMessage;
  const _SessionsDialog({
    required this.loadSessions,
    this.isFavorite,
    this.onToggleFavorite,
    this.onExport,
    this.errorMessage,
  });
  @override
  State<_SessionsDialog> createState() => _SessionsDialogState();
}

class _SessionsDialogState extends State<_SessionsDialog> {
  late Future<List<Incienso>> _sessions;
  final Set<String> _busy = {};
  @override
  void initState() {
    super.initState();
    _sessions = Future.sync(widget.loadSessions);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(GeneratorTranslationConstants.mySessions.tr),
    content: SizedBox(
      width: 500,
      height: MediaQuery.sizeOf(context).height * .5,
      child: FutureBuilder<List<Incienso>>(
        future: _sessions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  Text(GeneratorTranslationConstants.loadSessionsFailed.tr),
                  TextButton(
                    onPressed: () {
                      final sessions = Future.sync(widget.loadSessions);
                      setState(() {
                        _sessions = sessions;
                      });
                    },
                    child: Text(GeneratorTranslationConstants.retryLoad.tr),
                  ),
                ],
              ),
            );
          }
          final sessions = snapshot.data ?? const <Incienso>[];
          if (sessions.isEmpty) {
            return Text(GeneratorTranslationConstants.emptySessions.tr);
          }
          return ListView(
            children: [
              Text(GeneratorTranslationConstants.selectSessionHint.tr),
              const SizedBox(height: 12),
              for (final session in sessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    session.getName(Sint.locale?.languageCode ?? 'en'),
                  ),
                  subtitle: Text(
                    '${session.effectiveDuration.inMinutes}:${(session.effectiveDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                  ),
                  trailing:
                      widget.onToggleFavorite == null &&
                          (widget.onExport == null || !session.isPublic)
                      ? const Icon(Icons.chevron_right)
                      : PopupMenuButton<String>(
                          tooltip: GeneratorTranslationConstants
                              .practiceSessionActions
                              .tr,
                          enabled: !_busy.contains(session.id),
                          icon: Icon(
                            widget.isFavorite?.call(session.id) ?? false
                                ? Icons.star
                                : Icons.more_vert,
                          ),
                          onSelected: (action) async {
                            setState(() => _busy.add(session.id));
                            try {
                              if (action == 'favorite') {
                                await widget.onToggleFavorite?.call(session.id);
                              } else if (action == 'export') {
                                await widget.onExport?.call(session);
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _busy.remove(session.id));
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            if (widget.onToggleFavorite != null)
                              PopupMenuItem(
                                value: 'favorite',
                                child: Text(
                                  ((widget.isFavorite?.call(session.id) ??
                                              false)
                                          ? GeneratorTranslationConstants
                                                .practiceUnfavorite
                                          : GeneratorTranslationConstants
                                                .practiceFavorite)
                                      .tr,
                                ),
                              ),
                            if (widget.onExport != null && session.isPublic)
                              PopupMenuItem(
                                value: 'export',
                                child: Text(
                                  GeneratorTranslationConstants
                                      .practiceExport
                                      .tr,
                                ),
                              ),
                          ],
                        ),
                  onTap: () => Navigator.of(context).pop(session),
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      if ((widget.errorMessage?.call() ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              widget.errorMessage!(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(GeneratorTranslationConstants.cancelControl.tr),
      ),
    ],
  );
}
