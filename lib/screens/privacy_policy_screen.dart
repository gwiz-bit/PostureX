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
                  'Camera & video: during a live analyze session, camera frames are processed on '
                  'your device to detect your pose; only joint coordinates (not images) are sent '
                  'to our server to score your technique. If that mode is unavailable, frames may '
                  'be sent briefly to the server for real-time processing. Frames are never stored. '
                  'If you upload a workout video for review, that video file is stored so the same '
                  'analysis can run on it.\n\n'
                  'AI Coach messages: what you chat with AI Coach is stored so you can see your '
                  'history, along with any reports you send about an AI reply.\n\n'
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
                  'We do not sell your data. It is shared only with service providers, only to run the app:\n\n'
                  'Google (Gemini API) — AI Coach and AI-generated plans: when you chat with AI '
                  'Coach or generate an AI plan, your message plus your profile (name, age, gender, '
                  'height, weight, BMI, fitness level, weekly goal) and a summary of your workout '
                  'history are sent to Google to produce the reply. We never send your email, '
                  'password or videos. Google processes this under its own policy.\n\n'
                  'Google Sign-In: if you sign in with Google, we only receive the name and email '
                  'you consent to share.\n\n'
                  'Email delivery: your email address is used to send confirmation codes '
                  '(sign-up, password reset, account deletion).\n\n'
                  'Payments: the app does not currently sell paid plans or collect payment '
                  'information. Any transaction data from earlier versions was processed by MoMo, '
                  'which only received transaction details, never your posture or fitness data.',
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
                  'You can review and edit your profile at any time from the Profile tab.\n\n'
                  'You can delete your account and data at any time, immediately and permanently, '
                  'with no support request needed: Profile → Settings → Delete account. If you no '
                  'longer have the app, use https://api.posturex1.com/delete-account (confirmed by '
                  'a code sent to your email).\n\n'
                  'Deleted: account info, fitness profile, workout history, plans, uploaded videos, '
                  'AI Coach chats and reports, notifications and subscription records.\n\n'
                  'Kept: completed payment invoices from earlier versions (if any), anonymized — '
                  'no longer linked to you, no name or email — to meet tax and accounting record '
                  'requirements (up to 10 years). Server backups may still hold your data for up '
                  'to 30 days after deletion, then expire.',
            ),
            _Section(
              title: AppLocale.t('privacy_section_ai'),
              body:
                  'AI Coach is an AI assistant that gives general fitness and nutrition '
                  'information. It is not a doctor, does not diagnose or treat conditions, and does '
                  'not replace professional medical advice; its answers can be wrong. If you have '
                  'an injury or health condition, or feel pain while training, stop and consult a '
                  'doctor. Posture feedback is an automatic suggestion from image analysis, not an '
                  'assessment by a coach or physiotherapist.\n\n'
                  'If an AI reply is inappropriate, wrong or unsafe, report it with the flag icon '
                  'under that reply.',
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
