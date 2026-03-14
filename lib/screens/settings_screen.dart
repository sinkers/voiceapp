import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';
import '../providers/conversation_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Settings _draft;
  final _claudeKeyController = TextEditingController();
  final _openaiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _claudeModelController = TextEditingController();
  final _openaiModelController = TextEditingController();
  final _systemPromptController = TextEditingController();
  @override
  void initState() {
    super.initState();
    final settings = context.read<ConversationProvider>().settings;
    _draft = settings;
    _claudeKeyController.text = settings.claudeApiKey ?? '';
    _openaiKeyController.text = settings.openaiApiKey ?? '';
    _baseUrlController.text = settings.openaiBaseUrl;
    _claudeModelController.text = settings.claudeModelName;
    _openaiModelController.text = settings.openaiModelName;
    _systemPromptController.text = settings.systemPrompt;
  }

  @override
  void dispose() {
    _claudeKeyController.dispose();
    _openaiKeyController.dispose();
    _baseUrlController.dispose();
    _claudeModelController.dispose();
    _openaiModelController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final claudeKey = _claudeKeyController.text.trim();
    final openaiKey = _openaiKeyController.text.trim();

    final newSettings = _draft.copyWith(
      claudeApiKey: claudeKey.isNotEmpty ? claudeKey : null,
      clearClaudeApiKey: claudeKey.isEmpty,
      openaiApiKey: openaiKey.isNotEmpty ? openaiKey : null,
      clearOpenaiApiKey: openaiKey.isEmpty,
      openaiBaseUrl: _baseUrlController.text.trim().isNotEmpty
          ? _baseUrlController.text.trim()
          : 'https://api.openai.com/v1',
      claudeModelName: _claudeModelController.text.trim().isNotEmpty
          ? _claudeModelController.text.trim()
          : 'claude-opus-4-6',
      openaiModelName: _openaiModelController.text.trim().isNotEmpty
          ? _openaiModelController.text.trim()
          : 'gpt-4o',
      systemPrompt: _systemPromptController.text,
    );

    await context.read<ConversationProvider>().updateSettings(newSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Backend selection
          const _SectionHeader(title: 'AI Backend'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Provider', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<LLMBackend>(
                    segments: const [
                      ButtonSegment(
                        value: LLMBackend.claude,
                        label: Text('Claude'),
                        icon: Icon(Icons.auto_awesome),
                      ),
                      ButtonSegment(
                        value: LLMBackend.openaiCompatible,
                        label: Text('OpenAI / vLLM'),
                        icon: Icon(Icons.settings_ethernet),
                      ),
                    ],
                    selected: {_draft.backend},
                    onSelectionChanged: (s) =>
                        setState(() => _draft = _draft.copyWith(backend: s.first)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Claude settings
          if (_draft.backend == LLMBackend.claude) ...[
            const _SectionHeader(title: 'Claude'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _ApiKeyField(
                      controller: _claudeKeyController,
                      label: 'Anthropic API Key',
                      hint: 'sk-ant-...',
                    ),
                    const SizedBox(height: 12),
                    _TextField(
                      controller: _claudeModelController,
                      label: 'Model',
                      hint: 'claude-opus-4-6',
                    ),
                  ],
                ),
              ),
            ),
          ],

          // OpenAI-compatible settings
          if (_draft.backend == LLMBackend.openaiCompatible) ...[
            const _SectionHeader(title: 'OpenAI / Compatible API'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _ApiKeyField(
                      controller: _openaiKeyController,
                      label: 'API Key',
                      hint: 'sk-... or leave empty for local server',
                    ),
                    const SizedBox(height: 12),
                    _TextField(
                      controller: _baseUrlController,
                      label: 'Base URL',
                      hint: 'https://api.openai.com/v1',
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'For vLLM: http://localhost:8000/v1\n'
                        'For OpenClaw: http://localhost:3000/v1',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TextField(
                      controller: _openaiModelController,
                      label: 'Model',
                      hint: 'gpt-4o or meta-llama/Meta-Llama-3-70B-Instruct',
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // System prompt
          const _SectionHeader(title: 'System Prompt'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _systemPromptController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'System prompt',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Voice settings
          const _SectionHeader(title: 'Voice'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Speech Rate',
                          style: theme.textTheme.bodyMedium),
                      Text('${(_draft.ttsRate * 100).round()}%',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                  Slider(
                    value: _draft.ttsRate,
                    min: 0.1,
                    max: 1.0,
                    divisions: 18,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(ttsRate: v)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pitch', style: theme.textTheme.bodyMedium),
                      Text('${(_draft.ttsPitch * 100).round()}%',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                  Slider(
                    value: _draft.ttsPitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(ttsPitch: v)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Save Settings'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ApiKeyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _ApiKeyField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
