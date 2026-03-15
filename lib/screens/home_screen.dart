import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent_config.dart';
import '../models/conversation_state.dart';
import '../providers/agent_switcher_provider.dart';
import '../providers/conversation_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/mic_button.dart';
import '../widgets/state_indicator.dart';
import 'settings_screen.dart';

/// Root screen: a [PageView] with one [AgentConversationPage] per agent.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final switcher = context.read<AgentSwitcherProvider>();
    _pageController = PageController(initialPage: switcher.currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentSwitcherProvider>(
      builder: (context, switcher, _) {
        final agents = switcher.agents;
        if (agents.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Sync PageController when restored index differs (e.g. after init).
        if (_pageController.hasClients &&
            _pageController.page?.round() != switcher.currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(switcher.currentIndex);
            }
          });
        }
        return Scaffold(
          body: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: agents.length,
                onPageChanged: (index) => switcher.setCurrentIndex(index),
                itemBuilder: (context, index) {
                  final agent = agents[index];
                  return ChangeNotifierProvider.value(
                    value: switcher.providerFor(agent),
                    child: AgentConversationPage(agent: agent),
                  );
                },
              ),
              if (agents.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _PageDots(
                    count: agents.length,
                    currentIndex: switcher.currentIndex,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Page indicator dots.
class _PageDots extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _PageDots({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 10 : 6,
            height: active ? 10 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          );
        }),
      ),
    );
  }
}

/// Single agent conversation page. Reads [ConversationProvider] from context
/// (injected by [HomeScreen] per page).
class AgentConversationPage extends StatefulWidget {
  final AgentConfig agent;

  const AgentConversationPage({super.key, required this.agent});

  @override
  State<AgentConversationPage> createState() => _AgentConversationPageState();
}

class _AgentConversationPageState extends State<AgentConversationPage> {
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
        if (provider.messages.isNotEmpty) _scrollToBottom();

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.agent.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                _ProviderBadge(label: widget.agent.providerLabel),
              ],
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
              if (provider.errorMessage != null)
                _ErrorBanner(
                  message: provider.errorMessage!,
                  onDismiss: provider.clearError,
                ),
              if (!provider.hasApiKey && provider.initialized)
                _SetupPrompt(
                  onSetup: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
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
              if (provider.state == ConversationState.listening &&
                  provider.partialSttText.isNotEmpty)
                _PartialSttPreview(text: provider.partialSttText),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: StateIndicator(state: provider.state),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 48, top: 8),
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

class _ProviderBadge extends StatelessWidget {
  final String label;
  const _ProviderBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
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
