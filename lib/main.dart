import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const GroceryPosApp());
}

class GroceryPosApp extends StatelessWidget {
  const GroceryPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tạp Hóa POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(), // Khởi động vào màn hình chính
      debugShowCheckedModeBanner: false,
    );
  }
}