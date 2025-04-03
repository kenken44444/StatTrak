import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:stattrak/providers/post_provider.dart';
import 'providers/SupabaseProvider.dart';
import 'providers/weather_provider.dart';
import 'package:stattrak/Sign-upPage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseProvider = SupabaseProvider();
  await supabaseProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SupabaseProvider>.value(
          value: supabaseProvider,
        ),
        ChangeNotifierProvider<WeatherProvider>(
          create: (_) => WeatherProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => PostProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StatTrak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SignUpPage(),
    );
  }
}
