import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localconnect/data.dart';

final providerContainer = ProviderContainer();

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<Message>>((ref) {
  return ChatMessagesNotifier();
});

class ChatMessagesNotifier extends StateNotifier<List<Message>> {
  ChatMessagesNotifier() : super([]);

  void resetState() {
    state = [];
  }

  void addMessage(String message, bool you) {
    state = [...state, Message(message, you)];
  }
}
