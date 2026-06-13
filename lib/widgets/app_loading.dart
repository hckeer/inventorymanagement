import 'package:flutter/material.dart';

/// Full-screen centered loading indicator styled to match the film palette.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFFE8A838),
        strokeWidth: 2.5,
      ),
    );
  }
}
