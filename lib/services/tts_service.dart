abstract class TtsService {
  Function()? onDone;

  Future<void> initialize({double rate = 0.5, double pitch = 1.0});
  void updateSettings(double rate, double pitch);
  void enqueue(String text);
  void markFinished();
  Future<void> waitUntilDone();
  Future<void> stop();
  Future<void> reset();
  void dispose();
}
