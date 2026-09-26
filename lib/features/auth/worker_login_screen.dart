// DDE-Mart handyman app — OTP sign-in screen (original).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import 'worker_auth_api.dart';

class WorkerLoginScreen extends ConsumerStatefulWidget {
  const WorkerLoginScreen({super.key});

  @override
  ConsumerState<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends ConsumerState<WorkerLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _fail(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiMessage(e))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Handyman sign in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Your provider registers your number. Sign in with a code.'),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final debug = await ref
                          .read(workerAuthApiProvider)
                          .otpRequest(_phone.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              debug == null ? 'Code sent.' : 'Code sent (debug: $debug).',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) _fail(e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Send code'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '6-digit code'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final payload =
                          await ref.read(workerAuthApiProvider).otpVerify(
                                phone: _phone.text.trim(),
                                code: _code.text.trim(),
                              );
                      await ref.read(authStoreProvider.notifier).signIn(
                            token: '${payload['token']}',
                            name: '${payload['name'] ?? ''}',
                            phone: _phone.text.trim(),
                          );
                      if (context.mounted) context.go('/jobs');
                    } catch (e) {
                      if (context.mounted) _fail(e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Verify & sign in'),
          ),
        ],
      ),
    );
  }
}
