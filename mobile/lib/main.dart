import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/patients/providers/patients_provider.dart';
import 'features/appointments/providers/appointments_provider.dart';
import 'features/lab/providers/lab_provider.dart';
import 'features/pharmacy/providers/pharmacy_provider.dart';
import 'features/nurses/providers/nurses_provider.dart';
import 'features/ambulance/providers/ambulance_provider.dart';
import 'features/dashboard/screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HealthcareApp());
}

class HealthcareApp extends StatelessWidget {
  const HealthcareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(),
        ),
        ChangeNotifierProvider<PatientsProvider>(
          create: (_) => PatientsProvider(),
        ),
        ChangeNotifierProvider<AppointmentsProvider>(
          create: (_) => AppointmentsProvider(),
        ),
        ChangeNotifierProvider<LabProvider>(
          create: (_) => LabProvider(),
        ),
        ChangeNotifierProvider<PharmacyProvider>(
          create: (_) => PharmacyProvider(),
        ),
        ChangeNotifierProvider<NursesProvider>(
          create: (_) => NursesProvider(),
        ),
        ChangeNotifierProvider<AmbulanceProvider>(
          create: (_) => AmbulanceProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Healthcare App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00796B),
            primary: const Color(0xFF00796B),
            surface: const Color(0xFFF4F7F6),
          ),
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.tryAutoLogin();
    if (mounted) setState(() => _checkingSession = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7F6),
        body: Center(
          child: SpinKitPulse(color: Color(0xFF00796B), size: 60),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.authenticated) {
          return const MainNavigationScreen();
        }
        return const LoginScreen();
      },
    );
  }
}