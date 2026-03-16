import '../models/message.dart';

abstract class LLMService {
  /// Streams text deltas (tokens) from the LLM.
  Stream<String> streamResponse(List<Message> history, String systemPrompt);

  void dispose();
}
