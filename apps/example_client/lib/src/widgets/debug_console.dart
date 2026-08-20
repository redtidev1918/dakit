import 'package:flutter/material.dart';

import '../client_controller.dart';

final class DebugConsole extends StatefulWidget {
  const DebugConsole({required this.controller, super.key});

  final ExampleClientController controller;

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

final class _DebugConsoleState extends State<DebugConsole> {
  final TextEditingController _input = TextEditingController();
  final List<String> _lines = <String>[];
  bool _running = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final command = _input.text.trim();
    if (command.isEmpty || _running) return;
    setState(() {
      _running = true;
      _lines.add('> $command');
    });
    _input.clear();
    try {
      final result = await widget.controller.runConsoleCommand(command);
      if (!mounted) return;
      setState(() => _lines.add(result.isEmpty ? '(no output)' : result));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _lines.add('error: $error'));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.terminal),
              const SizedBox(width: 8),
              Text(
                'Debug console',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: _running ? null : () => setState(_lines.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: SingleChildScrollView(
              reverse: true,
              child: SelectionArea(
                child: Text(
                  _lines.isEmpty
                      ? 'Type `help` and press Enter.'
                      : _lines.join('\n'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_running,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText:
                        'help | account | status | open UUID | download UUID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _running ? null : _submit,
                child: const Text('Run'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
