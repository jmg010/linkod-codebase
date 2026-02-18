import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'reapply_screen.dart';

/// Shown when the user logs in but their account status is "declined".
/// Uses same design as account registration (green top, white card).
class DeclinedStatusScreen extends StatelessWidget {
  const DeclinedStatusScreen({
    super.key,
    required this.adminNote,
    this.reapplyType = 'full',
  });

  final String adminNote;
  /// 'proof_only' = resubmit proof of residence only; 'full' = fill credentials again.
  final String reapplyType;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final double buttonWidth = MediaQuery.of(context).size.width * 0.7;
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
                          'Your application was declined',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reason:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              adminNote.isEmpty ? 'No reason provided.' : adminNote,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        reapplyType == 'proof_only'
                            ? 'You can resubmit a valid proof of residence and re-apply for approval.'
                            : 'You can update your information and proof of residence, then re-apply for approval.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: SizedBox(
                          width: buttonWidth,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: uid == null
                                ? null
                                : () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => ReapplyScreen(
                                          uid: uid,
                                          reapplyType: reapplyType,
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A651),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              reapplyType == 'proof_only'
                                  ? 'Resubmit proof & Re-apply'
                                  : 'Update Info & Re-apply',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
