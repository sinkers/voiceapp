import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation_state.dart';
import '../models/settings.dart';
import '../providers/conversation_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/mic_button.dart';
import '../widgets/state_indicator.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConversationProvider>(
      builder: (context, provider, _) {
        // Auto-scroll when new content arrives
        if (provider.messages.isNotEmpty) {
          _scrollToBottom();
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text(
              'Voice Chat',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            actions: [
              if (provider.messages.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Clear conversation',
                  onPressed: () => _confirmClear(context, provider),
                ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: 'Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Error banner
              if (provider.errorMessage != null)
                _ErrorBanner(
                  message: provider.errorMessage!,
                  onDismiss: provider.clearError,
                ),

              // Setup prompt if no API key
              if (!provider.hasApiKey && provider.initialized)
                _SetupPrompt(
                  onSetup: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),

              // OpenClaw active instance indicator
              if (provider.settings.selectedInstance != null)
                _OpenClawChip(
                  instanceName: provider.settings.selectedInstance!.name,
                  agentId: provider.settings.selectedAgentId ?? 'main',
                ),

              // Message list
              Expanded(
                child: provider.messages.isEmpty
                    ? _EmptyState(state: provider.state)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        itemCount: provider.messages.length,
                        itemBuilder: (context, index) {
                          return MessageBubble(
                            message: provider.messages[index],
                          );
                        },
                      ),
              ),

              // Partial STT text preview
              if (provider.state == ConversationState.listening &&
                  provider.partialSttText.isNotEmpty)
                _PartialSttPreview(text: provider.partialSttText),

              // State indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: StateIndicator(state: provider.state),
              ),

              // Mic button
              Padding(
                padding: const EdgeInsets.only(bottom: 40, top: 8),
                child: MicButton(
                  state: provider.state,
                  onTap: provider.toggleConversation,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClear(
      BuildContext context, ConversationProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text(
            'This will delete all messages in the current conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      provider.clearMessages();
    }
  }
}

class _EmptyState extends StatelessWidget {
  final ConversationState state;
  const _EmptyState({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none_rounded,
            size: 72,
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap the mic to start talking',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartialSttPreview extends StatelessWidget {
  final String text;
  const _PartialSttPreview({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.shade300.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_rounded, size: 14, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupPrompt extends StatelessWidget {
  final VoidCallback onSetup;
  const _SetupPrompt({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add your API key to get started.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
          TextButton(
            onPressed: onSetup,
            child: const Text('Setup'),
          ),
        ],
      ),
    );
  }
}

class _OpenClawChip extends StatelessWidget {
  final String instanceName;
  final String agentId;

  const _OpenClawChip({required this.instanceName, required this.agentId});

  void _showInstanceSwitcher(BuildContext context) {
    final provider = context.read<ConversationProvider>();
    final instances = provider.settings.openclawInstances;
    final selectedInstanceId = provider.settings.selectedInstanceId;
    final selectedAgentId = provider.settings.selectedAgentId;

    if (instances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No instances configured. Add one in Settings.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => _InstanceSwitcherSheet(
        instances: instances,
        selectedInstanceId: selectedInstanceId,
        selectedAgentId: selectedAgentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: Icon(
            Icons.hub_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            '$instanceName · $agentId',
            style: theme.textTheme.labelSmall,
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          onPressed: () => _showInstanceSwitcher(context),
        ),
      ),
    );
  }
}

class _InstanceSwitcherSheet extends StatelessWidget {
  final List<OpenClawInstance> instances;
  final String? selectedInstanceId;
  final String? selectedAgentId;

  const _InstanceSwitcherSheet({
    required this.instances,
    required this.selectedInstanceId,
    required this.selectedAgentId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Switch OpenClaw Instance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: instances.length,
              itemBuilder: (context, index) {
                final instance = instances[index];
                final isSelected = instance.id == selectedInstanceId;
                return ListTile(
                  leading: Icon(
                    Icons.hub_rounded,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                  title: Text(instance.name),
                  subtitle: Text(
                      'Agent: ${isSelected ? selectedAgentId ?? 'main' : 'main'}'),
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  selected: isSelected,
                  onTap: () {
                    Navigator.pop(context);
                    context.read<ConversationProvider>().updateSettings(
                          context
                              .read<ConversationProvider>()
                              .settings
                              .copyWith(
                                selectedInstanceId: instance.id,
                                selectedAgentId: selectedAgentId ?? 'main',
                              ),
                        );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade800.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
