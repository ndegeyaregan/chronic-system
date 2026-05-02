import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// Full-screen Terms & Conditions reader.
///
/// Shown when the member taps "Read Terms & Conditions" during registration.
/// The "I Agree & Continue" button is pinned to the bottom of the viewport
/// so it's always visible — the user can never miss it. Tapping it pops
/// the route with `true`; the back button or system gesture pops with
/// `false` so the calling screen can keep the checkbox in the correct state.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Default pop returns null → the caller treats null as "did not accept".
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close, color: kText),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          title: const Text(
            'Terms & Conditions',
            style: TextStyle(
              color: kText,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(kRadiusMd),
                          border: Border.all(
                              color: kPrimary.withValues(alpha: 0.15)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: kPrimary, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Please read these terms carefully. You must accept them to create an account.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: kText,
                                    height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        kTermsBody,
                        style: TextStyle(
                          fontSize: 14,
                          color: kText,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Sticky action bar — always on screen, never scrolls away.
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: kBorder, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kSubtext,
                          side: const BorderSide(color: kBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kRadiusMd)),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 20),
                        label: const Text(
                          'I Agree & Continue',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kRadiusMd)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const String kTermsBody = '''
Welcome to the Sanlam Chronic Care app. By creating an account, you agree to the following terms and conditions:

1. Eligibility. The app is provided to active members of Sanlam Health Insurance schemes and their registered dependants. Use of the app is restricted to the member named on your medical scheme account.

2. Account Security. You are responsible for safeguarding the credentials you set during registration. Do not share your member number or password with anyone. Notify Sanlam immediately if you suspect unauthorised access.

3. Personal Information. The app processes personal and health information you provide (visits, prescriptions, vitals, claims, etc.) in order to deliver care-management features. Information is processed in accordance with Sanlam's Privacy Policy and applicable data-protection law.

4. Medical Disclaimer. Information shown in the app — including benefits, claims status, co-pays, and educational content — is for informational purposes only and does not replace professional medical advice. Always consult a licensed healthcare provider for medical decisions.

5. Service Availability. The app relies on connectivity to Sanlam's servers. Features such as facility lookup, benefit balances and pre-authorisations may be temporarily unavailable during maintenance or due to network conditions.

6. Acceptable Use. You agree not to misuse the app, attempt to access another member's information, reverse-engineer the application, or use the service for unlawful purposes.

7. Updates to These Terms. Sanlam may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the updated terms.

8. Termination. Sanlam may suspend or terminate your access if these terms are violated, if your scheme membership lapses, or for security reasons.

9. Contact. For support or privacy enquiries please contact Sanlam Customer Service through the official channels listed on https://sanlam.com.

By tapping "I Agree & Continue" you acknowledge that you have read, understood and agree to be bound by these terms.
''';
