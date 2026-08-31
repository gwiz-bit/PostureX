import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_locale.dart';

/// Static privacy policy shown in-app (Profile > Privacy Policy) and meant
/// to also be published at a public URL for the App Store Connect / Google
/// Play "Privacy Policy" field — required whenever the app collects
/// personal or health data, which PostureX does (camera-based posture
/// analysis, fitness profile).
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen>
    with AppLocaleMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          AppLocale.t('privacy_title'),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _Section(
              title: AppLocale.t('privacy_section_data_collected'),
              body:
                  'Account info: name, email, and password (stored as a hash, never in plain text).\n\n'
                  'Fitness profile: gender, height, weight, age, fitness level, and weekly goal, '
                  'used to personalize your workout plan.\n\n'
                  'Posture & workout data: rep counts, accuracy scores, and joint-angle feedback '
                  'produced by analyzing your movement.\n\n'
                  'Camera & video: during a live analyze session, camera frames are processed in '
                  'real time to detect your pose and are not stored afterward. If you upload a '
                  'workout video for review, that video file is stored so the same analysis can '
                  'run on it.\n\n'
                  'Device info: a push-notification token, only if you enable reminders.',
            ),
            _Section(
              title: AppLocale.t('privacy_section_how_used'),
              body:
                  'To personalize your workout plan and posture feedback, track your progress over '
                  'time, and send optional reminders (break reminders, daily summaries) if enabled.',
            ),
            _Section(
              title: AppLocale.t('privacy_section_sharing'),
              body:
                  'We do not sell your data. If you sign in with Google, we only receive the name '
                  'and email you consent to share. Payments are processed by our payment provider; '
                  'they receive transaction details only, never your posture or fitness data.',
            ),
            _Section(
              title: AppLocale.t('privacy_section_storage'),
              body:
                  'Your data is stored in our database and your session token is stored in your '
                  "device's secure storage (Android Keystore / iOS Keychain), never in plain "
                  'app storage.',
            ),
            _Section(
              title: AppLocale.t('privacy_section_rights'),
              body:
                  'You can review and edit your profile at any time from the Profile tab. To '
                  'request deletion of your account and associated data, contact support from '
                  'within the app.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
