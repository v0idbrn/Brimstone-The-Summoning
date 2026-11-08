import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: BrimstoneApp()));
}

class BrimstoneApp extends StatelessWidget {
  const BrimstoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brimstone: The Summoning',
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(child: Text('Brimstone: The Summoning')),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
