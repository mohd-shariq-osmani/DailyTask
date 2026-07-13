import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/colors.dart';
import 'ui/screens/task_list_screen.dart';
import 'viewmodel/task_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: const DailyTaskApp(),
    ),
  );
}

class DailyTaskApp extends StatelessWidget {
  const DailyTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailyTask',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: accentViolet,
          secondary: accentVioletLight,
          background: darkBackground,
          surface: darkSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const TaskListScreen(),
    );
  }
}
