import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(const ChatState()) {
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.get('/chat');
      final messages = (response.data as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(messages: messages, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e),
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Failed to load messages.');
    }
  }

  Future<bool> sendMessage(String text) async {
    if (text.trim().isEmpty) return false;
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final response = await dio.post('/chat', data: {'message': text.trim()});
      final msg = ChatMessage.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        messages: [...state.messages, msg],
        isSending: false,
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSending: false,
        error: extractErrorMessage(e),
      );
      return false;
    } catch (_) {
      state = state.copyWith(isSending: false, error: 'Failed to send message.');
      return false;
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
