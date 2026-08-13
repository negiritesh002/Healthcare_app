import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../core/secure_storage.dart';
import '../models/messaging_model.dart';

class MessagingProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final SecureStorageService _storage = SecureStorageService();

  List<ConversationModel> _conversations = [];
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _activeConversationId;

  String? get activeConversationId => _activeConversationId;
  List<ConversationModel> get conversations => _conversations;
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> fetchConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(ApiConstants.conversations);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _conversations = data.map((item) => ConversationModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load conversations';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching conversations';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ConversationModel?> startConversation(String targetDoctorId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.conversations,
        data: {'target_doctor_id': targetDoctorId},
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final conv = ConversationModel.fromJson(response.data);
        await fetchConversations();
        _isSubmitting = false;
        notifyListeners();
        return conv;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Failed to start conversation';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
    return null;
  }

  Future<void> fetchMessages(String conversationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.conversations}/$conversationId/messages',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _messages = data.map((item) => MessageModel.fromJson(item)).toList();
      } else {
        _errorMessage = 'Failed to load messages';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error fetching messages';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectWebSocket(String conversationId) async {
    await disconnectWebSocket();
    _activeConversationId = conversationId;

    final token = await _storage.getToken();
    if (token == null) {
      _errorMessage = 'Authentication token missing';
      notifyListeners();
      return;
    }

    final wsUri = Uri.parse(
      '${ApiConstants.wsBaseUrl}/messaging/ws/$conversationId?token=$token',
    );

    try {
      _channel = WebSocketChannel.connect(wsUri);
      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> jsonMsg = json.decode(data as String);
            final newMsg = MessageModel.fromJson(jsonMsg);
            
            // Avoid duplicate message appending
            if (!_messages.any((m) => m.id == newMsg.id)) {
              _messages.add(newMsg);
              notifyListeners();
            }
          } catch (e) {
            if (kDebugMode) print('Error parsing WS message: $e');
          }
        },
        onError: (err) {
          if (kDebugMode) print('WS connection error: $err');
        },
        onDone: () {
          if (kDebugMode) print('WS connection closed');
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to connect real-time chat: $e';
      notifyListeners();
    }
  }

  void sendMessage(String content) {
    if (_channel == null || content.trim().isEmpty) return;

    final payload = json.encode({'content': content.trim()});
    _channel!.sink.add(payload);
  }

  Future<void> disconnectWebSocket() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _activeConversationId = null;
  }

  @override
  void dispose() {
    disconnectWebSocket();
    super.dispose();
  }
}
