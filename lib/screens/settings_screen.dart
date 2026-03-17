import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/agent_config.dart';
import '../models/elevenlabs_voice.dart';
import '../models/settings.dart';
import '../models/voice_config.dart';
import '../providers/agent_switcher_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Settings _draft;
  final _systemPromptController = TextEditingController();
  String _versionInfo = '';

  @override
  void initState() {
    super.initState();
    final settings = context.read<AgentSwitcherProvider>().settings;
    _draft = settings;
    _systemPromptController.text = settings.systemPrompt;
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    const sha = String.fromEnvironment('GIT_SHA', defaultValue: 'dev');
    setState(() {
      _versionInfo = 'ClawTalk $sha';
    });
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newSettings = _draft.copyWith(
      systemPrompt: _systemPromptController.text,
    );
    await context.read<AgentSwitcherProvider>().updateSettings(newSettings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ============ Agent Management ============

  Future<void> _addAgent() async {
    final agentType = await showDialog<AgentType>(
      context: context,
      builder: (_) => const _AgentTypePickerDialog(),
    );
    if (agentType == null || !mounted) return;

    final result = await showDialog<_AgentFormResult>(
      context: context,
      builder: (_) => _AgentFormDialog(
        agentType: agentType,
        voices: _draft.voices,
        servers: _draft.openclawServers,
      ),
    );

    if (result != null) {
      setState(() {
        // Add new server if created
        if (result.newServer != null) {
          _draft = _draft.copyWith(
            openclawServers: [..._draft.openclawServers, result.newServer!],
          );
        }
        // Add agent
        _draft = _draft.copyWith(agents: [..._draft.agents, result.agent]);
      });
    }
  }

  Future<void> _editAgent(AgentConfig agent) async {
    final result = await showDialog<_AgentFormResult>(
      context: context,
      builder: (_) => _AgentFormDialog(
        agentType: agent.type,
        agent: agent,
        voices: _draft.voices,
        servers: _draft.openclawServers,
      ),
    );

    if (result != null) {
      setState(() {
        // Add new server if created
        if (result.newServer != null) {
          _draft = _draft.copyWith(
            openclawServers: [..._draft.openclawServers, result.newServer!],
          );
        }
        // Update agent
        final updatedAgents = _draft.agents
            .map((a) => a.id == result.agent.id ? result.agent : a)
            .toList();
        _draft = _draft.copyWith(agents: updatedAgents);
      });
    }
  }

  void _deleteAgent(AgentConfig agent) {
    final wasSelected = _draft.selectedAgentId == agent.id;
    setState(() {
      final updatedAgents =
          _draft.agents.where((a) => a.id != agent.id).toList();
      _draft = _draft.copyWith(
        agents: updatedAgents,
        clearSelectedAgentId: wasSelected,
      );
    });
  }

  // ============ Voice Management ============

  Future<void> _addVoice() async {
    final voiceProvider = await showDialog<VoiceProvider>(
      context: context,
      builder: (_) => const _VoiceProviderPickerDialog(),
    );
    if (voiceProvider == null || !mounted) return;

    final voice = await showDialog<VoiceConfig>(
      context: context,
      builder: (_) => _VoiceFormDialog(provider: voiceProvider),
    );

    if (voice != null) {
      setState(() {
        _draft = _draft.copyWith(voices: [..._draft.voices, voice]);
      });
    }
  }

  Future<void> _editVoice(VoiceConfig voice) async {
    final result = await showDialog<VoiceConfig>(
      context: context,
      builder: (_) => _VoiceFormDialog(provider: voice.provider, voice: voice),
    );

    if (result != null) {
      setState(() {
        final updatedVoices =
            _draft.voices.map((v) => v.id == result.id ? result : v).toList();
        _draft = _draft.copyWith(voices: updatedVoices);
      });
    }
  }

  void _deleteVoice(VoiceConfig voice) {
    // Don't allow deleting system voice
    if (voice.id == 'system') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete system voice')),
      );
      return;
    }

    // Check if any agent is using this voice
    final agentsUsingVoice =
        _draft.agents.where((a) => a.voiceId == voice.id).toList();
    if (agentsUsingVoice.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete voice: used by ${agentsUsingVoice.length} agent(s)',
          ),
        ),
      );
      return;
    }

    setState(() {
      final updatedVoices =
          _draft.voices.where((v) => v.id != voice.id).toList();
      _draft = _draft.copyWith(voices: updatedVoices);
    });
  }

  // ============ OpenClaw Server Management ============

  Future<void> _editServer(OpenClawServer server) async {
    final result = await showDialog<OpenClawServer>(
      context: context,
      builder: (_) => _ServerFormDialog(server: server),
    );

    if (result != null) {
      setState(() {
        final updatedServers = _draft.openclawServers
            .map((s) => s.id == result.id ? result : s)
            .toList();
        _draft = _draft.copyWith(openclawServers: updatedServers);
      });
    }
  }

  void _deleteServer(OpenClawServer server) {
    // Check if any agent is using this server
    final agentsUsingServer =
        _draft.agents.where((a) => a.serverId == server.id).toList();
    if (agentsUsingServer.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete server: used by ${agentsUsingServer.length} agent(s)',
          ),
        ),
      );
      return;
    }

    setState(() {
      final updatedServers =
          _draft.openclawServers.where((s) => s.id != server.id).toList();
      _draft = _draft.copyWith(openclawServers: updatedServers);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============ Agents Section ============
          const _SectionHeader(title: 'Agents'),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_draft.agents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'No agents configured',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                ..._draft.agents.map(
                  (agent) => _AgentTile(
                    agent: agent,
                    voices: _draft.voices,
                    servers: _draft.openclawServers,
                    onEdit: () => _editAgent(agent),
                    onDelete: () => _deleteAgent(agent),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Agent'),
                    onPressed: _addAgent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ============ Voice Providers Section ============
          const _SectionHeader(title: 'Voice Providers'),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._draft.voices.map(
                  (voice) => _VoiceTile(
                    voice: voice,
                    onEdit: () => _editVoice(voice),
                    onDelete: () => _deleteVoice(voice),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Voice Provider'),
                    onPressed: _addVoice,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ============ OpenClaw Servers Section ============
          if (_draft.openclawServers.isNotEmpty) ...[
            const _SectionHeader(title: 'OpenClaw Servers'),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _draft.openclawServers
                    .map(
                      (server) => _ServerTile(
                        server: server,
                        onEdit: () => _editServer(server),
                        onDelete: () => _deleteServer(server),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ============ System Prompt ============
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

          // Conversational mode
          const _SectionHeader(title: 'Conversational Mode'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Conversational mode'),
                    subtitle: const Text(
                      'Automatically listen after assistant finishes speaking',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _draft.conversationalMode,
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(conversationalMode: v),
                    ),
                  ),
                  if (_draft.conversationalMode) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pause duration',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '${_draft.pauseDuration.toStringAsFixed(1)}s',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Slider(
                      value: _draft.pauseDuration,
                      min: 0.5,
                      max: 3.0,
                      divisions: 25,
                      onChanged: (v) => setState(
                        () => _draft = _draft.copyWith(pauseDuration: v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Silence duration before ending your turn',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save Settings')),
          const SizedBox(height: 24),
          if (_versionInfo.isNotEmpty)
            Center(
              child: Text(
                _versionInfo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ============ Helper Classes ============

class _AgentFormResult {
  final AgentConfig agent;
  final OpenClawServer? newServer;

  const _AgentFormResult({
    required this.agent,
    this.newServer,
  });
}

// ============ Dialogs ============

class _AgentTypePickerDialog extends StatelessWidget {
  const _AgentTypePickerDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Agent Type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Claude'),
            subtitle: const Text('Anthropic Claude models'),
            onTap: () => Navigator.pop(context, AgentType.claude),
          ),
          ListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: const Text('OpenAI'),
            subtitle: const Text('OpenAI models'),
            onTap: () => Navigator.pop(context, AgentType.openai),
          ),
          ListTile(
            leading: const Icon(Icons.hub),
            title: const Text('OpenClaw'),
            subtitle: const Text('OpenClaw agent gateway'),
            onTap: () => Navigator.pop(context, AgentType.openclaw),
          ),
        ],
      ),
    );
  }
}

class _VoiceProviderPickerDialog extends StatelessWidget {
  const _VoiceProviderPickerDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Voice Provider'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text('ElevenLabs'),
            subtitle: const Text('High-quality AI voices'),
            onTap: () => Navigator.pop(context, VoiceProvider.elevenlabs),
          ),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('OpenAI TTS'),
            subtitle: const Text('OpenAI text-to-speech'),
            onTap: () => Navigator.pop(context, VoiceProvider.openai),
          ),
        ],
      ),
    );
  }
}

class _AgentFormDialog extends StatefulWidget {
  final AgentType agentType;
  final AgentConfig? agent;
  final List<VoiceConfig> voices;
  final List<OpenClawServer> servers;

  const _AgentFormDialog({
    required this.agentType,
    this.agent,
    required this.voices,
    required this.servers,
  });

  @override
  State<_AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends State<_AgentFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _agentNameController;
  late String _selectedVoiceId;
  late String? _selectedServerId;
  bool _obscureApiKey = true;
  final _formKey = GlobalKey<FormState>();
  OpenClawServer? _newServer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.agent?.name ?? '');
    _apiKeyController = TextEditingController(text: widget.agent?.apiKey ?? '');
    _modelController =
        TextEditingController(text: widget.agent?.model ?? _defaultModel());
    _baseUrlController = TextEditingController(
      text: widget.agent?.baseUrl ?? 'https://api.openai.com/v1',
    );
    _agentNameController =
        TextEditingController(text: widget.agent?.agentName ?? '');
    _selectedVoiceId =
        widget.agent?.voiceId ?? widget.voices.firstOrNull?.id ?? 'system';
    _selectedServerId = widget.agent?.serverId;
  }

  String _defaultModel() {
    switch (widget.agentType) {
      case AgentType.claude:
        return 'claude-opus-4-6';
      case AgentType.openai:
        return 'gpt-4o';
      case AgentType.openclaw:
        return '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    _agentNameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final agentName = _agentNameController.text.trim();

    AgentConfig result;
    switch (widget.agentType) {
      case AgentType.claude:
        result = AgentConfig.claude(
          name: name,
          apiKey: apiKey,
          model: model.isNotEmpty ? model : 'claude-opus-4-6',
          voiceId: _selectedVoiceId,
        );
      case AgentType.openai:
        result = AgentConfig.openai(
          name: name,
          apiKey: apiKey,
          model: model.isNotEmpty ? model : 'gpt-4o',
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.openai.com/v1',
          voiceId: _selectedVoiceId,
        );
      case AgentType.openclaw:
        if (_selectedServerId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a server')),
          );
          return;
        }
        result = AgentConfig.openclaw(
          name: name,
          serverId: _selectedServerId!,
          agentName: agentName,
          voiceId: _selectedVoiceId,
        );
    }

    // Preserve ID if editing
    if (widget.agent != null) {
      result = result.copyWith(id: widget.agent!.id);
    }

    Navigator.pop(
      context,
      _AgentFormResult(agent: result, newServer: _newServer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.agent != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Agent' : 'Add Agent'),
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
                  hintText: 'My Agent',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              // Claude-specific fields
              if (widget.agentType == AgentType.claude) ...[
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-ant-...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureApiKey = !_obscureApiKey),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'API Key is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'claude-opus-4-6',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              // OpenAI-specific fields
              if (widget.agentType == AgentType.openai) ...[
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureApiKey = !_obscureApiKey),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'API Key is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com/v1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'gpt-4o',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              // OpenClaw-specific fields
              if (widget.agentType == AgentType.openclaw) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedServerId,
                  decoration: const InputDecoration(
                    labelText: 'Server',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    ...widget.servers.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                    const DropdownMenuItem(
                      value: '__add_new__',
                      child: Text('Add new server...'),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == '__add_new__') {
                      final newServer = await showDialog<OpenClawServer>(
                        context: context,
                        builder: (_) => const _ServerFormDialog(),
                      );
                      if (newServer != null && mounted) {
                        // Track new server to return to parent
                        setState(() {
                          _newServer = newServer;
                          _selectedServerId = newServer.id;
                        });
                      }
                    } else {
                      setState(() => _selectedServerId = v);
                    }
                  },
                  validator: (v) => v == null ? 'Server is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _agentNameController,
                  decoration: const InputDecoration(
                    labelText: 'Agent Name',
                    hintText: 'main',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Agent name is required'
                      : null,
                ),
              ],

              const SizedBox(height: 12),

              // Voice picker
              DropdownButtonFormField<String>(
                initialValue: _selectedVoiceId,
                decoration: const InputDecoration(
                  labelText: 'Voice',
                  border: OutlineInputBorder(),
                ),
                items: widget.voices.map((v) {
                  return DropdownMenuItem(
                    value: v.id,
                    child: Text(v.name),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedVoiceId = v);
                },
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
          onPressed: _save,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _VoiceFormDialog extends StatefulWidget {
  final VoiceProvider provider;
  final VoiceConfig? voice;

  const _VoiceFormDialog({required this.provider, this.voice});

  @override
  State<_VoiceFormDialog> createState() => _VoiceFormDialogState();
}

class _VoiceFormDialogState extends State<_VoiceFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _voiceIdController;
  late final TextEditingController _modelIdController;
  late double _rate;
  late double _pitch;
  bool _obscureApiKey = true;
  String? _presetVoiceId;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.voice?.name ?? '');
    _apiKeyController = TextEditingController(text: widget.voice?.apiKey ?? '');
    _voiceIdController =
        TextEditingController(text: widget.voice?.voiceId ?? _defaultVoiceId());
    _modelIdController =
        TextEditingController(text: widget.voice?.modelId ?? _defaultModelId());
    _rate = widget.voice?.rate ?? 0.5;
    _pitch = widget.voice?.pitch ?? 1.0;
    _presetVoiceId = widget.voice?.voiceId;
  }

  String _defaultVoiceId() {
    switch (widget.provider) {
      case VoiceProvider.onDevice:
        return '';
      case VoiceProvider.elevenlabs:
        return ElevenLabsVoice.rachel.voiceId;
      case VoiceProvider.openai:
        return 'alloy';
    }
  }

  String _defaultModelId() {
    switch (widget.provider) {
      case VoiceProvider.onDevice:
        return '';
      case VoiceProvider.elevenlabs:
        return 'eleven_turbo_v2_5';
      case VoiceProvider.openai:
        return 'tts-1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _voiceIdController.dispose();
    _modelIdController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();

    VoiceConfig result;
    switch (widget.provider) {
      case VoiceProvider.onDevice:
        result = VoiceConfig.system(rate: _rate, pitch: _pitch);
        result = result.copyWith(name: name.isNotEmpty ? name : 'System');
      case VoiceProvider.elevenlabs:
        final apiKey = _apiKeyController.text.trim();
        final voiceId = _voiceIdController.text.trim();
        final modelId = _modelIdController.text.trim();
        result = VoiceConfig.elevenlabs(
          name: name,
          voiceId:
              voiceId.isNotEmpty ? voiceId : ElevenLabsVoice.rachel.voiceId,
          apiKey: apiKey.isNotEmpty ? apiKey : null,
          modelId: modelId.isNotEmpty ? modelId : 'eleven_turbo_v2_5',
        );
      case VoiceProvider.openai:
        final apiKey = _apiKeyController.text.trim();
        final voiceId = _voiceIdController.text.trim();
        final modelId = _modelIdController.text.trim();
        result = VoiceConfig.openai(
          name: name,
          voiceId: voiceId.isNotEmpty ? voiceId : 'alloy',
          apiKey: apiKey.isNotEmpty ? apiKey : null,
          modelId: modelId.isNotEmpty ? modelId : 'tts-1',
        );
    }

    // Preserve ID if editing
    if (widget.voice != null) {
      result = result.copyWith(id: widget.voice!.id);
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.voice != null;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(isEdit ? 'Edit Voice' : 'Add Voice'),
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
                  hintText: 'My Voice',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              // On-device voice settings
              if (widget.provider == VoiceProvider.onDevice) ...[
                Text('Speech Rate', style: theme.textTheme.labelMedium),
                Slider(
                  value: _rate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  label: '${(_rate * 100).round()}%',
                  onChanged: (v) => setState(() => _rate = v),
                ),
                const SizedBox(height: 8),
                Text('Pitch', style: theme.textTheme.labelMedium),
                Slider(
                  value: _pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  label: '${(_pitch * 100).round()}%',
                  onChanged: (v) => setState(() => _pitch = v),
                ),
              ],

              // ElevenLabs voice settings
              if (widget.provider == VoiceProvider.elevenlabs) ...[
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: 'API Key (optional)',
                    hintText: 'Your ElevenLabs API key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureApiKey = !_obscureApiKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _presetVoiceId,
                  decoration: const InputDecoration(
                    labelText: 'Preset Voice',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    ...ElevenLabsVoice.values.map(
                      (v) => DropdownMenuItem(
                          value: v.voiceId, child: Text(v.label)),
                    ),
                    const DropdownMenuItem(
                      value: '__custom__',
                      child: Text('Custom...'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _presetVoiceId = v;
                      if (v != null && v != '__custom__') {
                        _voiceIdController.text = v;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _voiceIdController,
                  decoration: const InputDecoration(
                    labelText: 'Voice ID',
                    hintText: '21m00Tcm4TlvDq8ikWAM',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _modelIdController,
                  decoration: const InputDecoration(
                    labelText: 'Model ID',
                    hintText: 'eleven_turbo_v2_5',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              // OpenAI TTS voice settings
              if (widget.provider == VoiceProvider.openai) ...[
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: 'API Key (optional)',
                    hintText: 'Uses global OpenAI key if empty',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureApiKey = !_obscureApiKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _voiceIdController.text.isNotEmpty
                      ? _voiceIdController.text
                      : 'alloy',
                  decoration: const InputDecoration(
                    labelText: 'Voice',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'alloy', child: Text('Alloy')),
                    DropdownMenuItem(value: 'echo', child: Text('Echo')),
                    DropdownMenuItem(value: 'fable', child: Text('Fable')),
                    DropdownMenuItem(value: 'onyx', child: Text('Onyx')),
                    DropdownMenuItem(value: 'nova', child: Text('Nova')),
                    DropdownMenuItem(value: 'shimmer', child: Text('Shimmer')),
                  ],
                  onChanged: (v) {
                    if (v != null) _voiceIdController.text = v;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _modelIdController.text.isNotEmpty
                      ? _modelIdController.text
                      : 'tts-1',
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'tts-1', child: Text('tts-1')),
                    DropdownMenuItem(
                        value: 'tts-1-hd', child: Text('tts-1-hd')),
                  ],
                  onChanged: (v) {
                    if (v != null) _modelIdController.text = v;
                  },
                ),
              ],
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
          onPressed: _save,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _ServerFormDialog extends StatefulWidget {
  final OpenClawServer? server;

  const _ServerFormDialog({this.server});

  @override
  State<_ServerFormDialog> createState() => _ServerFormDialogState();
}

class _ServerFormDialogState extends State<_ServerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _obscureToken = true;
  late bool _allowBadCertificate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.server?.name ?? '');
    _urlController = TextEditingController(text: widget.server?.baseUrl ?? '');
    _tokenController = TextEditingController(text: widget.server?.token ?? '');
    _allowBadCertificate = widget.server?.allowBadCertificate ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    final result = OpenClawServer(
      id: widget.server?.id ?? const Uuid().v4(),
      name: name,
      baseUrl: url,
      token: token.isNotEmpty ? token : null,
      allowBadCertificate: _allowBadCertificate,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.server != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Server' : 'Add Server'),
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
                    return 'Enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tokenController,
                obscureText: _obscureToken,
                decoration: InputDecoration(
                  labelText: 'Token (optional)',
                  hintText: 'Bearer token',
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
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow invalid TLS certificate'),
                subtitle: const Text(
                  'Use for self-signed certs',
                  style: TextStyle(fontSize: 12),
                ),
                value: _allowBadCertificate,
                onChanged: (v) => setState(() => _allowBadCertificate = v),
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
          onPressed: _save,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ============ List Tiles ============

class _AgentTile extends StatelessWidget {
  final AgentConfig agent;
  final List<VoiceConfig> voices;
  final List<OpenClawServer> servers;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AgentTile({
    required this.agent,
    required this.voices,
    required this.servers,
    required this.onEdit,
    required this.onDelete,
  });

  String _getSubtitle() {
    final voice = voices.firstWhereOrNull((v) => v.id == agent.voiceId);
    final voiceLabel = voice?.name ?? 'Unknown voice';

    switch (agent.type) {
      case AgentType.claude:
        return '${agent.model} • $voiceLabel';
      case AgentType.openai:
        return '${agent.model} • $voiceLabel';
      case AgentType.openclaw:
        final server = servers.firstWhereOrNull((s) => s.id == agent.serverId);
        final serverLabel = server?.name ?? 'Unknown server';
        return '$serverLabel / ${agent.agentName} • $voiceLabel';
    }
  }

  IconData _getIcon() {
    switch (agent.type) {
      case AgentType.claude:
        return Icons.auto_awesome;
      case AgentType.openai:
        return Icons.settings_ethernet;
      case AgentType.openclaw:
        return Icons.hub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_getIcon()),
      title: Text(agent.name),
      subtitle: Text(_getSubtitle(), overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  final VoiceConfig voice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VoiceTile({
    required this.voice,
    required this.onEdit,
    required this.onDelete,
  });

  String _getSubtitle() {
    switch (voice.provider) {
      case VoiceProvider.onDevice:
        return 'On-device TTS';
      case VoiceProvider.elevenlabs:
        return 'ElevenLabs • ${voice.voiceId}';
      case VoiceProvider.openai:
        return 'OpenAI TTS • ${voice.voiceId}';
    }
  }

  IconData _getIcon() {
    switch (voice.provider) {
      case VoiceProvider.onDevice:
        return Icons.phone_android;
      case VoiceProvider.elevenlabs:
        return Icons.record_voice_over;
      case VoiceProvider.openai:
        return Icons.mic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = voice.id != 'system';
    return ListTile(
      leading: Icon(_getIcon()),
      title: Text(voice.name),
      subtitle: Text(_getSubtitle(), overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  final OpenClawServer server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServerTile({
    required this.server,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.dns),
      title: Text(server.name),
      subtitle: Text(server.baseUrl, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
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
