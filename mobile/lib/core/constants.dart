import 'package:flutter/foundation.dart';

class ApiConstants {
  // Configured for active Wi-Fi LAN IP (192.168.0.103), Android Emulator (10.0.2.2), or Web/Desktop (localhost)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // Set to host Wi-Fi IP address 192.168.0.103 (or 10.0.2.2 for Android emulator)
    return 'http://192.168.0.103:8000';
  }

  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String signup = '/auth/signup';
  static const String me = '/auth/me';
  static const String dashboardStats = '/dashboard/stats';
  static const String patients = '/patients';
  static const String appointments = '/appointments';
  static const String labOrders = '/lab/orders';
  static const String medicines = '/pharmacy/medicines';
  static const String prescriptions = '/pharmacy/prescriptions';
}
