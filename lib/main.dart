import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_story_screen.dart';
import 'screens/video_call_screen.dart';
import 'screens/voice_call_screen.dart';
import 'screens/chat_search_screen.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/notification_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/notification_service.dart';
import 'services/call_service.dart';
import 'utils/responsive_helper.dart';
import 'utils/responsive_screen_util.dart';

// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initializeNotifications();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Weekend Mingle',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.black),
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
          ),
        ),
        builder: (context, child) {
          // Initialize all responsive systems for the entire app
          ResponsiveHelper.init(context);
          ResponsiveScreenUtil.init(context);

          // Apply text scaling factor to ensure text is readable on all devices
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor:
                  MediaQuery.of(context).textScaleFactor.clamp(0.85, 1.3),
            ),
            child: child!,
          );
        },
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/create_story': (context) => const CreateStoryScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          // Clear providers when user logs out
          Provider.of<FeedProvider>(context, listen: false)
              .initializeFeed(null);
          Provider.of<NotificationProvider>(context, listen: false)
              .initializeNotifications(null);
          return const LoginScreen();
        }

        // Initialize user data when auth state changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final userProvider =
              Provider.of<UserProvider>(context, listen: false);
          userProvider.initializeUser().then((_) {
            if (userProvider.user != null) {
              Provider.of<FeedProvider>(context, listen: false)
                  .initializeFeed(userProvider.user!.uid);
              Provider.of<NotificationProvider>(context, listen: false)
                  .initializeNotifications(userProvider.user!.uid);
            }
          });
        });

        return const HomeScreen();
      },
    );
  }
}
