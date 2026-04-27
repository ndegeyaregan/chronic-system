import 'dart:convert';
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

  /// Safely converts Dio response data to a typed Map.
  static Map<String, dynamic> _safeMap(dynamic data) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);

  Future<void> fetchMessages() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dio.get('/chat');
      final raw = response.data;
      // Handle both bare list and { "data": [...] } wrapper
      final items = raw is Map ? (raw['data'] as List? ?? []) : (raw as List);
      final messages = items
          .map((e) => ChatMessage.fromJson(_safeMap(e)))
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
    final trimmed = text.trim();

    // Optimistic update — show the message in the UI immediately
    final optimistic = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      memberId: '',
      memberName: '',
      message: trimmed,
      isFromAdmin: false,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      isSending: true,
      clearError: true,
    );

    try {
      await dio.post('/chat', data: {'message': trimmed});
      // Re-fetch all messages from the server to stay in sync
      await _refreshMessages();
      return true;
    } on DioException catch (e) {
      // Remove the optimistic message on failure
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        isSending: false,
        error: extractErrorMessage(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        isSending: false,
        error: 'Failed to send message: ${e.toString()}',
      );
      return false;
    }
  }

  /// Silently refreshes messages from the server (no loading spinner).
  Future<void> _refreshMessages() async {
    try {
      final response = await dio.get('/chat');
      final raw = response.data;
      final items = raw is Map ? (raw['data'] as List? ?? []) : (raw as List);
      final messages =
          items.map((e) => ChatMessage.fromJson(_safeMap(e))).toList();
      state = state.copyWith(messages: messages, isSending: false);
    } catch (_) {
      // Keep optimistic message if refresh fails — it was already sent
      state = state.copyWith(isSending: false);
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
