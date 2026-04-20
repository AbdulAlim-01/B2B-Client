import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/register_business_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase - set env variables in your local .env or CI.
  await Supabase.initialize(
    url: '',
    anonKey: '');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'B2BLead',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light().copyWith(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const RootRouter(),
      ),
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return StreamBuilder<AuthChangeEvent>(
      stream: Supabase.instance.client.auth.onAuthStateChange.map((e) => e.event),
      builder: (context, snapshot) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          return const LoginScreen();
        } else {
          // check if business profile exists
          return FutureBuilder<bool>(
            future: auth.hasBusinessProfile(user.id),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              final hasProfile = snap.data ?? false;
              if (!hasProfile) return RegisterBusinessScreen(userId: user.id);
              return DashboardScreen(userId: user.id);
            },
          );
        }
      },
    );
  }
}
