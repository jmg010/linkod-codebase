import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shown when the user logs in but their account status is "suspended".
/// Same design as account registration (green top, white card).
class SuspendedStatusScreen extends StatelessWidget {
  const SuspendedStatusScreen({
    super.key,
    this.adminNote,
  });

  final String? adminNote;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00A651),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Semantics(
              label: 'LINKod logo',
              child: Image.asset(
                'assets/images/linkod_logo.png',
                width: 182,
                height: 143,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(height: 143),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Account suspended',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'Please visit the Barangay Hall to resolve this.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (adminNote != null && adminNote!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            adminNote!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Center(
                        child: TextButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text('Sign out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
