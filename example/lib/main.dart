import 'dart:math';

import 'package:async_tap_guard/async_tap_guard.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'async_tap_guard',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const ExamplePage(),
    );
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  int _orders = 0;
  bool _liked = false;

  Future<void> _placeOrder() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    setState(() => _orders++);
  }

  Future<void> _toggleLike() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    setState(() => _liked = !_liked);
  }

  Future<void> _flakyRequest() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (Random().nextBool()) throw Exception('Network error');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('async_tap_guard')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Orders placed: $_orders',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text('Tap as fast as you like: only one order is placed.'),
          const SizedBox(height: 12),
          AsyncTapGuard(
            onTap: _placeOrder,
            builder: (context, state, onTap) => FilledButton(
              onPressed: onTap,
              child: state.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Place order'),
            ),
          ),
          const Divider(height: 48),
          const Text('Works with any widget, with a cooldown afterwards.'),
          const SizedBox(height: 12),
          Center(
            child: AsyncTapGuard(
              onTap: _toggleLike,
              cooldown: const Duration(milliseconds: 500),
              builder: (context, state, onTap) => IconButton.filledTonal(
                onPressed: onTap,
                icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
              ),
            ),
          ),
          const Divider(height: 48),
          const Text('Errors are exposed to the builder and to onError.'),
          const SizedBox(height: 12),
          AsyncTapGuard(
            onTap: _flakyRequest,
            minBusyDuration: const Duration(milliseconds: 400),
            onError: (error, _) => _showSnackBar('$error'),
            builder: (context, state, onTap) => OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(state.hasError ? Icons.refresh : Icons.cloud_upload),
              label: Text(switch (state.status) {
                AsyncTapStatus.idle => 'Send request',
                AsyncTapStatus.busy => 'Sending...',
                AsyncTapStatus.failed => 'Failed, tap to retry',
              }),
            ),
          ),
        ],
      ),
    );
  }
}
