import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';

class AIAssistantProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  final List<Map<String, String>> _chatMessages = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, String>> get chatMessages => _chatMessages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> sendQuery(String userQuery) async {
    final queryText = userQuery.trim();
    if (queryText.isEmpty) return;

    _chatMessages.add({'role': 'user', 'content': queryText});
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final history = _chatMessages
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList();

      final response = await _apiClient.dio.post(
        ApiConstants.aiMedicineQuery,
        data: {
          'message': queryText,
          'conversation_history': history,
        },
      );

      if (response.statusCode == 200) {
        final reply = response.data['reply'] as String;
        _chatMessages.add({'role': 'assistant', 'content': reply});
      } else {
        _errorMessage = 'Failed to get response from AI Assistant';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? 'Network error querying AI Assistant';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _chatMessages.clear();
    notifyListeners();
  }
}
