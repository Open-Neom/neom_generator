import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/generator_translation_constants.dart';

/// Compact display only: editing uses the original precision, never this text.
String formatChamberFrequency(double value) {
  if (!value.isFinite) return '0';
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Wraps rather than clipping long translations or enlarged accessibility text.
class ChamberParameterLabel extends StatelessWidget {
  final String label;
  final String value;
  const ChamberParameterLabel(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(12) > 18;
        final title = Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        );
        final detail = Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Courier',
            fontSize: 12,
          ),
        );
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 4), detail],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  Flexible(child: detail),
                ],
              );
      },
    ),
  );
}

class ChamberFrequencyControl extends StatefulWidget {
  final String label;
  final double value;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<String> onSubmit;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final bool compact;

  const ChamberFrequencyControl({
    super.key,
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelect,
    required this.onSubmit,
    required this.onIncrease,
    required this.onDecrease,
    this.compact = false,
  });

  @override
  State<ChamberFrequencyControl> createState() =>
      _ChamberFrequencyControlState();
}

class _ChamberFrequencyControlState extends State<ChamberFrequencyControl> {
  Future<void> _edit() async {
    widget.onSelect();
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _FrequencyEditDialog(label: widget.label, value: widget.value),
    );
    if (mounted && result != null) widget.onSubmit(result);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .4),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onSelect,
      child: Container(
        padding: EdgeInsets.all(widget.compact ? 6 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.selected ? AppColor.bondiBlue : Colors.white24,
          ),
        ),
        child: widget.compact
            ? _compactContent(context)
            : Column(
                children: [
                  Semantics(
                    selected: widget.selected,
                    button: true,
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatChamberFrequency(widget.value)} Hz',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Courier',
                      fontSize: 24,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip:
                            '${GeneratorTranslationConstants.decreaseControl.tr}: ${widget.label}',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: widget.onDecrease,
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        tooltip:
                            '${GeneratorTranslationConstants.editControl.tr}: ${widget.label}',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: _edit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip:
                            '${GeneratorTranslationConstants.increaseControl.tr}: ${widget.label}',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: widget.onIncrease,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _compactContent(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        widget.label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final value = TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              foregroundColor: Colors.white,
            ),
            onPressed: _edit,
            child: Text(
              '${formatChamberFrequency(widget.value)} Hz',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontFamily: 'Courier'),
            ),
          );
          final edit = Tooltip(
            message:
                '${GeneratorTranslationConstants.editControl.tr}: ${widget.label}',
            child: value,
          );
          final decrease = IconButton(
            tooltip:
                '${GeneratorTranslationConstants.decreaseControl.tr}: ${widget.label}',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: widget.onDecrease,
            icon: const Icon(Icons.remove, size: 20),
          );
          final increase = IconButton(
            tooltip:
                '${GeneratorTranslationConstants.increaseControl.tr}: ${widget.label}',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: widget.onIncrease,
            icon: const Icon(Icons.add, size: 20),
          );
          if (constraints.maxWidth < 148 ||
              MediaQuery.textScalerOf(context).scale(20) > 30) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                edit,
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [decrease, increase],
                ),
              ],
            );
          }
          return Row(
            children: [
              decrease,
              Expanded(child: edit),
              increase,
            ],
          );
        },
      ),
    ],
  );
}

class _FrequencyEditDialog extends StatefulWidget {
  final String label;
  final double value;
  const _FrequencyEditDialog({required this.label, required this.value});
  @override
  State<_FrequencyEditDialog> createState() => _FrequencyEditDialogState();
}

class _FrequencyEditDialogState extends State<_FrequencyEditDialog> {
  late final TextEditingController _text;
  bool _invalid = false;
  void _submit() {
    final value = double.tryParse(_text.text.replaceAll(',', '.'));
    if (value == null || !value.isFinite) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(value.toString());
  }

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    content: TextField(
      autofocus: true,
      controller: _text,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: 'Hz',
        errorText: _invalid
            ? GeneratorTranslationConstants.invalidFrequencyControl.tr
            : null,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(GeneratorTranslationConstants.cancelControl.tr),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(GeneratorTranslationConstants.applyControl.tr),
      ),
    ],
  );
}

class ChamberOctaveControl extends StatelessWidget {
  final int octave;
  final double effectiveFrequency;
  final ValueChanged<int> onChanged;
  final bool compact;
  const ChamberOctaveControl({
    super.key,
    required this.octave,
    required this.effectiveFrequency,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => compact
      ? _compactSelector(context)
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChamberParameterLabel(
              GeneratorTranslationConstants.octave.tr,
              '${formatChamberFrequency(effectiveFrequency)} Hz',
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var value = -4; value <= 4; value++)
                  Semantics(
                    label: '${GeneratorTranslationConstants.octave.tr} $value',
                    child: ChoiceChip(
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      showCheckmark: false,
                      label: Text(
                        value == 0
                            ? GeneratorTranslationConstants.octaveBase.tr
                            : value < 0
                            ? '/${1 << -value}'
                            : '${1 << value}x',
                      ),
                      selected: octave == value,
                      onSelected: (_) => onChanged(value),
                    ),
                  ),
              ],
            ),
          ],
        );

  String _label(int value) => value == 0
      ? GeneratorTranslationConstants.octaveBase.tr
      : value < 0
      ? '/${1 << -value}'
      : '${1 << value}x';

  Widget _compactSelector(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: GeneratorTranslationConstants.octave.tr,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: octave,
        isExpanded: true,
        itemHeight: null,
        menuMaxHeight: 360,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        selectedItemBuilder: (_) => [
          for (var value = -4; value <= 4; value++)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_label(value)} · ${formatChamberFrequency(effectiveFrequency)} Hz',
                ),
              ),
            ),
        ],
        items: [
          for (var value = -4; value <= 4; value++)
            DropdownMenuItem(
              value: value,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_label(value)),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Exposes failures rather than leaving the user with a silent failed save.
class ChamberFeedback extends StatefulWidget {
  final String playbackError;
  final String saveError;
  final Future<void> Function() onRetrySave;
  const ChamberFeedback({
    super.key,
    required this.playbackError,
    required this.saveError,
    required this.onRetrySave,
  });

  @override
  State<ChamberFeedback> createState() => _ChamberFeedbackState();
}

class _ChamberFeedbackState extends State<ChamberFeedback> {
  bool _saving = false;
  Future<void> _retry() async {
    setState(() => _saving = true);
    try {
      await widget.onRetrySave();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playbackError.isEmpty && widget.saveError.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.playbackError.isNotEmpty)
              Text(
                widget.playbackError,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            if (widget.saveError.isNotEmpty) ...[
              Text(
                widget.saveError,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _saving ? null : _retry,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(GeneratorTranslationConstants.retryControl.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChamberPlaybackButton extends StatelessWidget {
  final bool requested;
  final bool transitioning;
  final VoidCallback onPressed;
  const ChamberPlaybackButton({
    super.key,
    required this.requested,
    required this.transitioning,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message:
        (requested
                ? GeneratorTranslationConstants.stopChamber
                : GeneratorTranslationConstants.activateChamber)
            .tr,
    child: IconButton(
      constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
      tooltip:
          (requested
                  ? GeneratorTranslationConstants.stopChamber
                  : GeneratorTranslationConstants.activateChamber)
              .tr,
      onPressed: onPressed,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          if (transitioning)
            const SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          Icon(
            requested ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 44,
            color: requested ? AppColor.bondiBlue : Colors.white,
          ),
        ],
      ),
    ),
  );
}
