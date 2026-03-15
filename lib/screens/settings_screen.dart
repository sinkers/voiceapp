import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/settings.dart';
import '../providers/conversation_provider.dart';
import '../services/openclaw_service.dart';

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
  final _elevenLabsKeyController = TextEditingController();
  final _elevenLabsVoiceIdController = TextEditingController();
  final _elevenLabsModelIdController = TextEditingController();
  final _openClawService = OpenClawService();
  List<String> _agents = [];
  bool _loadingAgents = false;

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
    _elevenLabsKeyController.text = settings.elevenLabsApiKey ?? '';
    _elevenLabsVoiceIdController.text = settings.elevenLabsVoiceId;
    _elevenLabsModelIdController.text = settings.elevenLabsModelId;

    final selectedInstance = settings.selectedInstance;
    if (selectedInstance != null) {
      _loadingAgents = true;
      _fetchAgentsForInstance(selectedInstance);
    }
  }

  @override
  void dispose() {
    _claudeKeyController.dispose();
    _openaiKeyController.dispose();
    _baseUrlController.dispose();
    _claudeModelController.dispose();
    _openaiModelController.dispose();
    _systemPromptController.dispose();
    _elevenLabsKeyController.dispose();
    _elevenLabsVoiceIdController.dispose();
    _elevenLabsModelIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgentsForInstance(OpenClawInstance instance) async {
    final agents = await _openClawService.fetchAgents(instance);
    if (!mounted) return;
    setState(() {
      _agents = agents;
      _loadingAgents = false;
      if (!agents.contains(_draft.selectedAgentId)) {
        _draft = _draft.copyWith(
          selectedAgentId: agents.isNotEmpty ? agents.first : null,
        );
      }
    });
  }

  Future<void> _onInstanceSelected(String? id) async {
    setState(() {
      if (id == null) {
        _draft = _draft.copyWith(
          clearSelectedInstanceId: true,
          clearSelectedAgentId: true,
        );
        _agents = [];
        _loadingAgents = false;
      } else {
        _draft = _draft.copyWith(
          selectedInstanceId: id,
          clearSelectedAgentId: true,
        );
        _agents = [];
        _loadingAgents = true;
      }
    });
    if (id == null) return;
    final instance = _draft.openclawInstances.firstWhere((i) => i.id == id);
    await _fetchAgentsForInstance(instance);
  }

  Future<void> _addInstance() async {
    final result = await showDialog<OpenClawInstance>(
      context: context,
      builder: (_) => const _InstanceFormDialog(),
    );
    if (result != null) {
      setState(() {
        _draft = _draft.copyWith(
          openclawInstances: [..._draft.openclawInstances, result],
        );
      });
    }
  }

  Future<void> _editInstance(OpenClawInstance instance) async {
    final result = await showDialog<OpenClawInstance>(
      context: context,
      builder: (_) => _InstanceFormDialog(instance: instance),
    );
    if (result != null) {
      setState(() {
        final updated = _draft.openclawInstances
            .map((i) => i.id == result.id ? result : i)
            .toList();
        _draft = _draft.copyWith(openclawInstances: updated);
      });
    }
  }

  void _deleteInstance(OpenClawInstance instance) {
    final wasSelected = _draft.selectedInstanceId == instance.id;
    setState(() {
      final updated =
          _draft.openclawInstances.where((i) => i.id != instance.id).toList();
      _draft = _draft.copyWith(
        openclawInstances: updated,
        clearSelectedInstanceId: wasSelected,
        clearSelectedAgentId: wasSelected,
      );
      if (wasSelected) _agents = [];
    });
  }

  Future<void> _testInstance(OpenClawInstance instance) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Testing connection...'),
          duration: Duration(seconds: 3),
        ),
      );
    final agents = await _openClawService.fetchAgents(instance);
    if (!mounted) return;
    final message = agents.length == 1 && agents.first == 'main'
        ? 'Connected (no OpenClaw agents found, using fallback)'
        : 'Found ${agents.length} agent(s): ${agents.join(', ')}';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _save() async {
    final claudeKey = _claudeKeyController.text.trim();
    final openaiKey = _openaiKeyController.text.trim();
    final elevenLabsKey = _elevenLabsKeyController.text.trim();

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
      elevenLabsApiKey: elevenLabsKey.isNotEmpty ? elevenLabsKey : null,
      clearElevenLabsApiKey: elevenLabsKey.isEmpty,
      elevenLabsVoiceId: _elevenLabsVoiceIdController.text.trim().isNotEmpty
          ? _elevenLabsVoiceIdController.text.trim()
          : '21m00Tcm4TlvDq8ikWAM',
      elevenLabsModelId: _elevenLabsModelIdController.text.trim().isNotEmpty
          ? _elevenLabsModelIdController.text.trim()
          : 'eleven_multilingual_v2',
      selectedInstanceId: _draft.selectedInstanceId,
      selectedAgentId: _draft.selectedAgentId,
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
                    onSelectionChanged: (s) => setState(
                        () => _draft = _draft.copyWith(backend: s.first)),
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
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
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

          // OpenClaw instances
          const _SectionHeader(title: 'OpenClaw'),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_draft.openclawInstances.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'No instances configured',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ..._draft.openclawInstances.map(
                  (instance) => ListTile(
                    title: Text(instance.name),
                    subtitle: Text(
                      instance.baseUrl,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.cable_rounded, size: 20),
                          tooltip: 'Test connection',
                          onPressed: () => _testInstance(instance),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          tooltip: 'Edit',
                          onPressed: () => _editInstance(instance),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20),
                          tooltip: 'Delete',
                          onPressed: () => _deleteInstance(instance),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add instance'),
                    onPressed: _addInstance,
                  ),
                ),
              ],
            ),
          ),

          // Instance + agent selection
          if (_draft.openclawInstances.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Instance', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _draft.selectedInstanceId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._draft.openclawInstances.map(
                          (i) => DropdownMenuItem(
                            value: i.id,
                            child: Text(i.name),
                          ),
                        ),
                      ],
                      onChanged: _onInstanceSelected,
                    ),
                    if (_draft.selectedInstanceId != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Agent', style: theme.textTheme.labelMedium),
                          const Spacer(),
                          if (_loadingAgents)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              tooltip: 'Refresh agent list',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                final instance = _draft.openclawInstances
                                    .where((i) =>
                                        i.id == _draft.selectedInstanceId)
                                    .firstOrNull;
                                if (instance != null) {
                                  _fetchAgentsForInstance(instance);
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Always show the agent list once we have at least one entry
                      // (fallback 'main' counts). Empty only before first fetch.
                      if (_agents.isNotEmpty)
                        DropdownButtonFormField<String>(
                          key: ValueKey(_agents.join(',')),
                          initialValue: _agents.contains(_draft.selectedAgentId)
                              ? _draft.selectedAgentId
                              : _agents.first,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _agents
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(a),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() =>
                                  _draft = _draft.copyWith(selectedAgentId: v));
                            }
                          },
                        )
                      else if (_loadingAgents)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Loading agents…',
                              style: TextStyle(fontSize: 12)),
                        )
                      else
                        // No agents yet — prompt user to add one manually
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'No agents found. Add one below.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _AddAgentField(
                        agents: _agents,
                        onAdd: (agentId) {
                          setState(() {
                            if (!_agents.contains(agentId)) {
                              _agents = [..._agents, agentId];
                            }
                            _draft = _draft.copyWith(selectedAgentId: agentId);
                          });
                        },
                      ),
                    ],
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

          // Text-to-Speech section
          const _SectionHeader(title: 'Text-to-Speech'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Provider', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TtsProvider>(
                    initialValue: _draft.ttsProvider,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TtsProvider.onDevice,
                        child: Text('On-device'),
                      ),
                      DropdownMenuItem(
                        value: TtsProvider.elevenlabs,
                        child: Text('ElevenLabs'),
                      ),
                      DropdownMenuItem(
                        value: TtsProvider.openai,
                        child: Text('OpenAI'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(
                            () => _draft = _draft.copyWith(ttsProvider: v));
                      }
                    },
                  ),
                  if (_draft.ttsProvider == TtsProvider.elevenlabs) ...[
                    const SizedBox(height: 12),
                    _ApiKeyField(
                      controller: _elevenLabsKeyController,
                      label: 'ElevenLabs API Key',
                      hint: 'Your ElevenLabs API key',
                    ),
                    const SizedBox(height: 12),
                    _TextField(
                      controller: _elevenLabsVoiceIdController,
                      label: 'Voice ID',
                      hint: '21m00Tcm4TlvDq8ikWAM',
                    ),
                    const SizedBox(height: 12),
                    _TextField(
                      controller: _elevenLabsModelIdController,
                      label: 'Model ID',
                      hint: 'eleven_multilingual_v2',
                    ),
                  ],
                  if (_draft.ttsProvider == TtsProvider.openai) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Uses your OpenAI API key above',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Voice', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _draft.openaiTtsVoice,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'alloy', child: Text('Alloy')),
                        DropdownMenuItem(value: 'echo', child: Text('Echo')),
                        DropdownMenuItem(value: 'fable', child: Text('Fable')),
                        DropdownMenuItem(value: 'onyx', child: Text('Onyx')),
                        DropdownMenuItem(value: 'nova', child: Text('Nova')),
                        DropdownMenuItem(
                            value: 'shimmer', child: Text('Shimmer')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() =>
                              _draft = _draft.copyWith(openaiTtsVoice: v));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Model', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _draft.openaiTtsModel,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'tts-1', child: Text('tts-1')),
                        DropdownMenuItem(
                            value: 'tts-1-hd', child: Text('tts-1-hd')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() =>
                              _draft = _draft.copyWith(openaiTtsModel: v));
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Voice settings (on-device rate/pitch only)
          if (_draft.ttsProvider == TtsProvider.onDevice) ...[
            const SizedBox(height: 12),
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
                        Text('Speech Rate', style: theme.textTheme.bodyMedium),
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
          ],

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

class _InstanceFormDialog extends StatefulWidget {
  final OpenClawInstance? instance;

  const _InstanceFormDialog({this.instance});

  @override
  State<_InstanceFormDialog> createState() => _InstanceFormDialogState();
}

class _InstanceFormDialogState extends State<_InstanceFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _obscureToken = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.instance?.name ?? '');
    _urlController =
        TextEditingController(text: widget.instance?.baseUrl ?? '');
    _tokenController =
        TextEditingController(text: widget.instance?.token ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.instance != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Instance' : 'Add Instance'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Home Pi',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'http://192.168.1.100:18789/v1',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Base URL is required';
                  }
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
                    return 'Enter a valid URL (e.g. http://10.0.0.1:18789/v1)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tokenController,
                obscureText: _obscureToken,
                decoration: InputDecoration(
                  labelText: 'Token',
                  hintText: 'Bearer token (optional)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureToken ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final url = _urlController.text.trim();
            if (name.isEmpty || url.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Name and Base URL are required.'),
                ),
              );
              return;
            }
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              OpenClawInstance(
                id: widget.instance?.id ?? const Uuid().v4(),
                name: name,
                baseUrl: url,
                token: _tokenController.text.trim(),
              ),
            );
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
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

class _AddAgentField extends StatefulWidget {
  final List<String> agents;
  final void Function(String agentId) onAdd;

  const _AddAgentField({required this.agents, required this.onAdd});

  @override
  State<_AddAgentField> createState() => _AddAgentFieldState();
}

class _AddAgentFieldState extends State<_AddAgentField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onAdd(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Add agent ID manually',
              hintText: 'e.g. main, alex',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add agent',
                onPressed: _submit,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
      ],
    );
  }
}
