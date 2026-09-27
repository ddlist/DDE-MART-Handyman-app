// DDE-Mart handyman app — staged OTP sign-in (original).
//
// Stage 1 collects the phone and sends the code; stage 2 verifies it with
// a resend cooldown. Debug codes surface outside production only.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import 'worker_auth_api.dart';

class WorkerLoginScreen extends ConsumerStatefulWidget {
  const WorkerLoginScreen({super.key});

  @override
  ConsumerState<WorkerLoginScreen> createState() =>
      _WorkerLoginScreenState();
}

class _WorkerLoginScreenState
    extends ConsumerState<WorkerLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busySend = false;
  bool _busyVerify = false;
  String? _error;
  String? _debugCode;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _send() async {
    final phone = _phone.text.trim();
    if (phone.length < 7) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() {
      _busySend = true;
      _error = null;
    });
    try {
      final debug =
          await ref.read(workerAuthApiProvider).otpRequest(phone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _debugCode = debug;
      });
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = apiMessage(e));
    } finally {
      if (mounted) setState(() => _busySend = false);
    }
  }

  Future<void> _verify() async {
    final phone = _phone.text.trim();
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code we sent you.');
      return;
    }
    setState(() {
      _busyVerify = true;
      _error = null;
    });
    try {
      final payload =
          await ref.read(workerAuthApiProvider).otpVerify(
                phone: phone,
                code: code,
              );
      await ref.read(authStoreProvider.notifier).signIn(
            token: '${payload['token']}',
            name: '${payload['name'] ?? ''}',
            phone: phone,
          );
      if (mounted) context.go('/jobs');
    } catch (e) {
      if (mounted) setState(() => _error = apiMessage(e));
    } finally {
      if (mounted) setState(() => _busyVerify = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Handyman sign in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall),
                  const SizedBox(height: 4),
                  const Text(
                      'Your provider registers your number. Sign in with a code.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            enabled: !_codeSent,
            decoration: InputDecoration(
              labelText: 'Phone',
              suffixIcon: _codeSent
                  ? TextButton(
                      onPressed: () => setState(() {
                        _codeSent = false;
                        _debugCode = null;
                      }),
                      child: const Text('Change'),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          if (!_codeSent)
            FilledButton(
              onPressed: _busySend ? null : _send,
              child: Text(
                  _busySend ? 'Sending…' : 'Send code'),
            )
          else ...[
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                  labelText: '6-digit code'),
              onChanged: (value) {
                if (value.trim().length >= 6 && !_busyVerify) {
                  _verify();
                }
              },
            ),
            if (_debugCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Debug code: $_debugCode',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .primary),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busyVerify ? null : _verify,
              child: Text(_busyVerify
                  ? 'Verifying…'
                  : 'Verify & sign in'),
            ),
            TextButton(
              onPressed:
                  (_busySend || _cooldown > 0) ? null : _send,
              child: Text(_cooldown > 0
                  ? 'Resend in $_cooldown s'
                  : 'Resend code'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
