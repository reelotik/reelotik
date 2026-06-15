import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added for Firestore settings

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/join_group_by_invite_screen.dart';

// Global Navigator Key for Deep Link handling
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background notification handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Firestore Offline Cache enabled
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const AppLockWrapper(child: ReelotikApp()));
}

// --- SECURE WRAPPER ---
class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAppLock();
  }

  Future<void> _checkAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool("app_lock_enabled") ?? false;

    if (!isEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    bool authenticated = await authenticateUser();
    if (authenticated) {
      if (mounted) setState(() => _isLoading = false);
    } else {
      SystemNavigator.pop();
    }
  }

  Future<bool> authenticateUser() async {
    try {
      return await auth.authenticate(
        localizedReason: 'Unlock Reelotik',
        options: const AuthenticationOptions(
          biometricOnly: false,
          useErrorDialogs: true,
          stickyAuth: true, 
        ),
      );
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xff0D1117),
          body: Center(child: CircularProgressIndicator(color: Color(0xff25D366))),
        ),
      );
    }
    return widget.child;
  }
}

// --- MAIN APP CLASS ---
class ReelotikApp extends StatelessWidget {
  const ReelotikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      debugShowCheckedModeBanner: false,
      title: 'Reelotik',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xff0D1117),
      ),
      home: const SplashScreen(),
    );
  }
}

// --- DEEP LINK HELPER ---
void handleDeepLink(String groupId) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => JoinGroupByInviteScreen(
        groupId: groupId,
      ),
    ),
  );
}