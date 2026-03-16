import 'package:flutter/material.dart';
import '../models/conversation_state.dart';

class MicButton extends StatefulWidget {
  final ConversationState state;
  final VoidCallback onTap;

  const MicButton({super.key, required this.state, required this.onTap});

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = widget.state == ConversationState.listening;
    final isProcessing = widget.state == ConversationState.processing;
    final isSpeaking = widget.state == ConversationState.speaking;

    Color buttonColor;
    Color iconColor;
    IconData icon;
    String tooltip;

    if (isListening) {
      buttonColor = Colors.red.shade600;
      iconColor = Colors.white;
      icon = Icons.stop_rounded;
      tooltip = 'Stop listening';
    } else if (isProcessing) {
      buttonColor = theme.colorScheme.surfaceContainerHighest;
      iconColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
      icon = Icons.mic_rounded;
      tooltip = 'Processing...';
    } else if (isSpeaking) {
      buttonColor = Colors.orange.shade700;
      iconColor = Colors.white;
      icon = Icons.stop_rounded;
      tooltip = 'Interrupt';
    } else {
      buttonColor = theme.colorScheme.primary;
      iconColor = theme.colorScheme.onPrimary;
      icon = Icons.mic_rounded;
      tooltip = 'Start listening';
    }

    Widget button = Material(
      color: buttonColor,
      shape: const CircleBorder(),
      elevation: isListening || isSpeaking ? 8.0 : 4.0,
      child: InkWell(
        onTap: isProcessing ? null : widget.onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 88,
          height: 88,
          child: isProcessing
              ? const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white54,
                    ),
                  ),
                )
              : Center(child: Icon(icon, size: 44, color: iconColor)),
        ),
      ),
    );

    if (isListening) {
      button = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _pulseAnimation.value, child: child),
        child: button,
      );
    }

    return Tooltip(message: tooltip, child: button);
  }
}
