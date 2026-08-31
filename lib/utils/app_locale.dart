import 'package:flutter/material.dart';

/// Minimal i18n helper — no extra packages needed.
///
/// Usage in a StatefulWidget:
///   class _MyState extends State<MyWidget> with AppLocaleMixin { ... }
///   Then just call AppLocale.t('key') in build().
///
/// For parameterised strings call AppLocale.format('key', {'param': value}).
class AppLocale {
  static const en = 'en';
  static const vi = 'vi';

  static final ValueNotifier<String> notifier = ValueNotifier(en);

  static String get current => notifier.value;

  static void setLanguage(String lang) => notifier.value = lang;

  static String t(String key) =>
      _s[notifier.value]?[key] ?? _s[en]![key] ?? key;

  static String format(String key, Map<String, String> params) {
    String result = t(key);
    params.forEach((k, v) => result = result.replaceAll('{$k}', v));
    return result;
  }

  /// Translates backend phase strings (going_down, bottom, going_up, top).
  static String phase(String raw) => t('phase_$raw');

  /// Translates muscle group names from the DB (English) into the current
  /// locale. Exercise names are intentionally left untranslated; muscle
  /// group names are generic anatomy terms that have clear Vietnamese equivalents.
  static String muscleGroup(String raw) =>
      _muscleGroups[notifier.value]?[raw] ??
      _muscleGroups[en]?[raw] ??
      raw;

  static const _muscleGroups = <String, Map<String, String>>{
    en: {
      'Abs': 'Abs',
      'Back': 'Back',
      'Biceps': 'Biceps',
      'Calves': 'Calves',
      'Chest': 'Chest',
      'Core': 'Core',
      'Full Body': 'Full Body',
      'Glutes': 'Glutes',
      'Hamstrings': 'Hamstrings',
      'Hip Flexors': 'Hip Flexors',
      'Lats': 'Lats',
      'Lower Back': 'Lower Back',
      'Neck': 'Neck',
      'Quadriceps': 'Quadriceps',
      'Shoulders': 'Shoulders',
      'Traps': 'Traps',
      'Triceps': 'Triceps',
    },
    vi: {
      'Abs': 'Cơ bụng',
      'Back': 'Lưng',
      'Biceps': 'Bắp tay trước',
      'Calves': 'Bắp chân',
      'Chest': 'Ngực',
      'Core': 'Cơ lõi',
      'Full Body': 'Toàn thân',
      'Glutes': 'Mông',
      'Hamstrings': 'Đùi sau',
      'Hip Flexors': 'Cơ gấp hông',
      'Lats': 'Cơ lưng rộng',
      'Lower Back': 'Lưng dưới',
      'Neck': 'Cổ',
      'Quadriceps': 'Đùi trước',
      'Shoulders': 'Vai',
      'Traps': 'Cơ thang',
      'Triceps': 'Bắp tay sau',
    },
  };

  static const _s = <String, Map<String, String>>{
    // ── English ────────────────────────────────────────────────────────
    en: {
      // Navigation
      'nav_home': 'Home',
      'nav_exercises': 'Exercises',
      'nav_workout': 'Workout',
      'nav_progress': 'Progress',
      'nav_profile': 'Profile',

      // Shared / generic
      'retry': 'Retry',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'save': 'Save',
      'close': 'Close',
      'done': 'Done',
      'error_generic': 'Something went wrong. Please try again.',
      'error_generic_short': 'Something went wrong.',
      'error_no_connection': 'Could not reach the server. Check your connection.',

      // Shared fields
      'field_email_label': 'Email',
      'field_email_hint': 'you@example.com',
      'field_password_label': 'Password',
      'field_password_hint': 'Enter your password',
      'field_name_label': 'Name',
      'field_name_hint': 'Your name',

      // Shared validation
      'validation_enter_email': 'Enter your email',
      'validation_invalid_email': 'Enter a valid email',
      'validation_enter_password': 'Enter your password',
      'validation_enter_name': 'Enter your name',
      'validation_min_6_chars': 'At least 6 characters',
      'validation_min_8_chars': 'At least 8 characters',
      'validation_passwords_mismatch': 'Passwords do not match',
      'validation_invalid_age': 'Enter a valid age',
      'validation_unrealistic_age': 'Enter a realistic age',
      'validation_invalid_number': 'Enter a valid number',
      'validation_enter_code': 'Enter the code',
      'validation_code_6_digits': 'Code must be 6 digits',
      'validation_enter_reset_code': 'Enter the reset code',
      'validation_enter_new_password': 'Enter a new password',

      // Splash
      'splash_tagline': 'Move better. Stand taller.',

      // Login
      'login_title': 'Welcome back',
      'login_subtitle': 'Log in to continue your posture journey',
      'login_forgot_password': 'Forgot password?',
      'login_error_wrong_credentials': 'Incorrect email or password.',
      'login_error_account_not_found': 'This account no longer exists.',
      'login_error_not_verified': 'Your email is not verified yet.',
      'login_verify_now': 'Verify now',
      'login_google_error': 'Could not sign in with Google. Check your connection.',
      'login_button': 'Log in',
      'login_no_account': "Don't have an account? ",
      'login_sign_up_link': 'Sign up',

      // Register
      'register_title': 'Create your account',
      'register_subtitle': 'Tell us a bit about you to personalize your training',
      'register_password_hint': 'Create a password',
      'register_confirm_password_label': 'Confirm password',
      'register_confirm_password_hint': 'Re-enter your password',
      'register_tip_title': 'Your data stays private',
      'register_tip_body':
          'We only use your info to personalize your posture insights — never shared without your consent.',
      'register_error_email_taken': 'That email is already registered.',
      'register_button': 'Create account',
      'register_google_button': 'Sign up with Google',
      'register_have_account': 'Already have an account? ',
      'register_log_in_link': 'Log in',

      // OTP
      'otp_title': 'Check your email',
      'otp_subtitle': 'Enter the 6-digit code we sent to {email}',
      'otp_field_label': 'Verification code',
      'otp_field_hint': '123456',
      'otp_error_invalid': 'Incorrect or expired code. Please try again.',
      'otp_error_not_found': 'Account not found.',
      'otp_resend_success': 'A new code has been sent to your email.',
      'otp_verify_button': 'Verify',
      'otp_no_code': "Didn't get the code? ",
      'otp_sending': 'Sending...',
      'otp_resend': 'Resend',

      // Forgot password
      'forgot_title': 'Forgot password?',
      'forgot_subtitle':
          "Enter your account email — we'll send you a code to reset your password.",
      'forgot_tip_title': 'Check your inbox',
      'forgot_tip_body':
          "The reset code expires in 30 minutes. Be sure to check your spam folder if it doesn't show up in a couple of minutes.",
      'forgot_send_button': 'Send reset code',
      'forgot_already_have_code': 'I already have a code',

      // Reset password
      'reset_title': 'Reset password',
      'reset_subtitle_no_email': 'Paste the code from your email and choose a new password.',
      'reset_subtitle_with_email': 'Paste the code we sent to {email} and choose a new password.',
      'reset_code_label': 'Reset code',
      'reset_code_hint': 'Paste the code from your email',
      'reset_new_password_label': 'New password',
      'reset_new_password_hint': 'Create a new password',
      'reset_confirm_password_label': 'Confirm new password',
      'reset_confirm_password_hint': 'Re-enter your new password',
      'reset_success_snack': 'Password reset — you can log in with your new password now.',
      'reset_submit_button': 'Reset password',
      'tip_strong_password_title': 'Choose a strong password',
      'tip_strong_password_body':
          'At least 8 characters, with an uppercase letter, a lowercase letter, a number, and a special character.',

      // Onboarding
      'onboarding_finish_button': 'Finish',
      'onboarding_step1_title': 'Choose your goals',
      'onboarding_step2_title': 'Choose your gender',
      'onboarding_gender_female': 'Female',
      'onboarding_gender_male': 'Male',
      'onboarding_gender_other': 'Other',
      'onboarding_step3_title': 'What motivates your exercise?',
      'onboarding_step4_title': 'Choose your focus areas',
      'onboarding_step5_title': 'Choose your fitness level',
      'onboarding_level_beginner': 'Beginner',
      'onboarding_level_beginner_desc': "I'm new or have only tried it for a bit",
      'onboarding_level_intermediate': 'Intermediate',
      'onboarding_level_intermediate_desc': "I've lifted weights before",
      'onboarding_level_advanced': 'Advanced',
      'onboarding_level_advanced_desc': "I've stuck to a balanced routine for years!",
      'onboarding_step6_title': 'Choose your activity level',
      'onboarding_activity_sedentary': 'Sedentary',
      'onboarding_activity_sedentary_desc': 'Little or no exercise, office job',
      'onboarding_activity_light': 'Light active',
      'onboarding_activity_light_desc': 'Light exercise/sports 1-3 days/week',
      'onboarding_activity_moderate': 'Moderate active',
      'onboarding_activity_moderate_desc': 'Moderate exercise/sports 3-5 days/week',
      'onboarding_activity_very': 'Very active',
      'onboarding_activity_very_desc': 'Hard exercise 6-7 days/week',
      'onboarding_activity_extra': 'Extra active',
      'onboarding_activity_extra_desc': 'Very hard exercise & physical job',
      'onboarding_step7_title': 'How tall are you?',
      'onboarding_height_tip_title': 'Calculating your BMI',
      'onboarding_height_tip_body':
          'We use your height to personalize your posture and fitness insights.',
      'onboarding_step8_title': 'How old are you?',
      'onboarding_age_tip_title': 'Personalized for your age',
      'onboarding_age_tip_body':
          'Age helps us tailor session intensity and recovery to you.',
      'onboarding_step9_title': 'What is your current weight?',
      'onboarding_weight_tip_title': 'Track your progress over time',
      'onboarding_weight_tip_body':
          'We use your weight to personalize load recommendations and track trends.',
      'onboarding_step10_title': 'What is your target weight?',
      'onboarding_target_tip_title': 'Set a realistic goal',
      'onboarding_target_tip_body':
          'Small, steady changes lead to lasting results — you can adjust this anytime.',
      'onboarding_step11_title': 'Any health issues?',
      'onboarding_step12_title': 'What equipment do you have?',
      'onboarding_step13_title': 'How often would you like to work out?',
      'onboarding_step13_subtitle':
          'Our recommended plan adapts to how often you train.',
      'onboarding_step14_title': 'Set your workout days',

      // Plan generating
      'plan_gen_title': 'Building your training plan',
      'plan_gen_subtitle':
          'Personalizing 4 weeks of workouts based on your goals',

      // Home
      'home_welcome_back': 'Welcome back',
      'home_ai_plan_ready': 'Your personalized plan is ready!',
      'home_load_error': 'Could not load your workout data.',
      'home_posture_score_label': 'POSTURE SCORE',
      'posture_label_no_data': 'No data',
      'posture_label_excellent': 'Excellent',
      'posture_label_strong': 'Strong',
      'posture_label_fair': 'Fair',
      'posture_label_needs_work': 'Needs work',
      'home_no_sets_logged': 'No sets logged yet',
      'home_weekly_goal': 'Weekly Goal',
      'home_goal_reached': 'Goal reached this week!',
      'home_sessions_to_go': '{n} session(s) to go this week',
      'home_this_week': 'This Week',
      'home_daily_posture_avg': 'Daily posture average',
      'home_training_plan': 'Training Plan',
      'home_week_of_total': 'Week {n} of {total}',
      'home_tap_day_hint': 'Tap a day to see that session',
      'home_generating': 'Generating...',
      'home_personalize_ai': 'Personalize with AI',
      'home_quick_start': 'Quick Start',
      'home_quick_start_subtitle': 'Jump into a guided session',
      'home_full_body_check_title': 'Full Body Check',
      'home_full_body_exercises': 'Squat · Row · Plank',

      // Exercises
      'exercises_title': 'Exercises',
      'exercises_search_hint': 'Search exercises',
      'exercises_empty': 'No exercises found',
      'exercises_tag_live_analysis': 'Live analysis',
      'exercises_filter_all': 'All',
      'exercise_detail_how_to': 'How to do it',
      'exercise_detail_start_analysis': 'Start Live Analysis',
      'exercise_detail_no_analysis':
          'Live posture analysis is not available for this exercise yet — follow the demo video instead.',
      'exercise_detail_upload_video': 'Upload a video instead',

      // Workout
      'workout_title': 'Workout',
      'workout_no_active_title': 'No Active Workout',
      'workout_no_active_subtitle':
          'Start a new session or pick exercises\nto begin recording your sets.',
      'workout_start_empty': 'Start Empty Workout',
      'workout_upload_video': 'Upload a video instead',
      'workout_suggested_routines': 'Suggested Routines',
      'workout_routines_hint': 'Tap a routine, then pick which exercise to check',
      'routine_full_body': 'Full Body Check',
      'routine_posture_primer': 'Posture Primer',
      'routine_strength_foundations': 'Strength Foundations',

      // Analyze session
      'analyze_starting_camera': 'Starting camera…',
      'analyze_connecting': 'Connecting to analysis server…',
      'analyze_permission_denied':
          'Camera permission is required to analyze your form.',
      'analyze_open_settings': 'Open Settings',
      'analyze_close': 'Close',
      'analyze_init_error':
          'Could not start the camera or reach the server.',
      'analyze_paused': 'PAUSED',
      'analyze_reps_label': 'REPS',
      'analyze_end_session': 'End Session',
      'phase_going_down': 'GOING DOWN',
      'phase_bottom': 'BOTTOM',
      'phase_going_up': 'GOING UP',
      'phase_top': 'TOP',

      // Workout summary
      'summary_title': 'Session complete',
      'summary_reps': 'Reps',
      'summary_duration': 'Duration',
      'summary_accuracy': 'Accuracy',
      'summary_mistakes_title': 'Most common mistakes',
      'summary_no_errors': 'No technique errors this session — great form!',
      'summary_done': 'Done',

      // Notifications
      'notifications_title': 'Notifications',
      'notifications_mark_all_read': 'Mark all read',
      'notifications_empty': 'No notifications yet',
      'time_just_now': 'Just now',
      'time_minutes_ago': '{n}m ago',
      'time_hours_ago': '{n}h ago',
      'time_days_ago': '{n}d ago',
      'notif_type_payment': 'Payment',
      'notif_type_workout': 'Workout',
      'notif_type_workout_reminder': 'Workout reminder',
      'notif_type_nutrition': 'Nutrition',
      'notif_type_break': 'Break reminder',
      'notif_type_daily_summary': 'Daily summary',
      'notif_type_subscription': 'Subscription',
      'notif_type_announcement': 'Announcement',
      'notif_type_default': 'Notification',
      'notif_detail_todays_exercises': "Today's exercises",

      // Edit profile
      'edit_profile_title': 'Edit profile',
      'edit_profile_full_name_label': 'Full name',
      'edit_profile_full_name_hint': 'Your name',
      'edit_profile_height_label': 'Height (cm)',
      'edit_profile_weight_label': 'Weight (kg)',
      'edit_profile_age_label': 'Age',
      'edit_profile_change_password': 'Change password',
      'edit_profile_password_hint_subtitle':
          'Leave blank to keep your current password.',
      'edit_profile_new_password_label': 'New password',
      'edit_profile_new_password_hint': 'Leave blank to keep current',
      'edit_profile_confirm_password_label': 'Confirm new password',
      'edit_profile_confirm_password_hint': 'Re-enter your new password',
      'edit_profile_save': 'Save changes',

      // Profile
      'profile_title': 'Profile',
      'profile_height': 'Height',
      'profile_weight': 'Weight',
      'profile_age': 'Age',
      'profile_sessions': 'Sessions',
      'profile_reps': 'Reps',
      'profile_posture': 'Posture',
      'profile_personal_info': 'Personal Info',
      'profile_weekly_goal': 'Weekly Goal',
      'profile_experience': 'Experience',
      'profile_focus_areas': 'Focus Areas',
      'profile_training_prefs': 'Training Preferences',
      'profile_ai_coach': 'AI Coach',
      'profile_settings': 'Settings',
      'profile_sessions_unit': 'sessions',

      // Settings
      'settings': 'Settings',
      'language': 'Language',
      'english': 'English',
      'vietnamese': 'Vietnamese',
      'premium': 'Premium',
      'account': 'Account',
      'subscribe': 'Subscribe',
      'privacy_policy': 'Privacy Policy',
      'delete_account': 'Delete Account',
      'delete_account_title': 'Delete Account?',
      'delete_account_body':
          'This will permanently delete your account and all your workout data. This action cannot be undone.',
      'log_out': 'Log out',
      'log_out_title': 'Log out?',
      'log_out_body': "You'll need to log in again to access your posture data.",

      // Subscription
      'subscription_title': 'Choose your plan',
      'subscription_no_plan_subtitle': 'Unlock your full potential',
      'subscription_cta_choose': 'Choose a plan',

      // AI Coach
      'coach_title': 'AI Coach',
      'coach_hint': 'Ask about training, nutrition...',
      'coach_empty': 'Ask AI Coach anything about\ntraining & nutrition',

      // Privacy Policy
      'privacy_title': 'Privacy Policy',
      'privacy_section_data_collected': 'Data we collect',
      'privacy_section_how_used': 'How we use your data',
      'privacy_section_sharing': 'Data sharing',
      'privacy_section_storage': 'Data storage & security',
      'privacy_section_rights': 'Your rights',
    },

    // ── Vietnamese ─────────────────────────────────────────────────────
    vi: {
      // Navigation
      'nav_home': 'Trang chủ',
      'nav_exercises': 'Bài tập',
      'nav_workout': 'Tập luyện',
      'nav_progress': 'Tiến độ',
      'nav_profile': 'Hồ sơ',

      // Shared / generic
      'retry': 'Thử lại',
      'cancel': 'Huỷ',
      'delete': 'Xoá',
      'save': 'Lưu',
      'close': 'Đóng',
      'done': 'Xong',
      'error_generic': 'Có lỗi xảy ra. Vui lòng thử lại.',
      'error_generic_short': 'Có lỗi xảy ra.',
      'error_no_connection': 'Không kết nối được máy chủ. Kiểm tra kết nối.',

      // Shared fields
      'field_email_label': 'Email',
      'field_email_hint': 'you@example.com',
      'field_password_label': 'Mật khẩu',
      'field_password_hint': 'Nhập mật khẩu',
      'field_name_label': 'Tên',
      'field_name_hint': 'Tên của bạn',

      // Shared validation
      'validation_enter_email': 'Nhập email',
      'validation_invalid_email': 'Email không hợp lệ',
      'validation_enter_password': 'Nhập mật khẩu',
      'validation_enter_name': 'Nhập tên của bạn',
      'validation_min_6_chars': 'Ít nhất 6 ký tự',
      'validation_min_8_chars': 'Ít nhất 8 ký tự',
      'validation_passwords_mismatch': 'Mật khẩu không khớp',
      'validation_invalid_age': 'Nhập tuổi hợp lệ',
      'validation_unrealistic_age': 'Tuổi không thực tế',
      'validation_invalid_number': 'Nhập số hợp lệ',
      'validation_enter_code': 'Nhập mã xác thực',
      'validation_code_6_digits': 'Mã phải có 6 chữ số',
      'validation_enter_reset_code': 'Nhập mã đặt lại',
      'validation_enter_new_password': 'Nhập mật khẩu mới',

      // Splash
      'splash_tagline': 'Cải thiện tư thế. Vươn cao hơn.',

      // Login
      'login_title': 'Chào mừng trở lại',
      'login_subtitle': 'Đăng nhập để tiếp tục hành trình tư thế',
      'login_forgot_password': 'Quên mật khẩu?',
      'login_error_wrong_credentials': 'Email hoặc mật khẩu không đúng.',
      'login_error_account_not_found': 'Tài khoản này không còn tồn tại.',
      'login_error_not_verified': 'Email của bạn chưa được xác thực.',
      'login_verify_now': 'Xác thực ngay',
      'login_google_error': 'Không thể đăng nhập bằng Google. Kiểm tra kết nối.',
      'login_button': 'Đăng nhập',
      'login_no_account': 'Chưa có tài khoản? ',
      'login_sign_up_link': 'Đăng ký',

      // Register
      'register_title': 'Tạo tài khoản',
      'register_subtitle': 'Cho chúng tôi biết về bạn để cá nhân hóa chương trình tập',
      'register_password_hint': 'Tạo mật khẩu',
      'register_confirm_password_label': 'Xác nhận mật khẩu',
      'register_confirm_password_hint': 'Nhập lại mật khẩu',
      'register_tip_title': 'Dữ liệu của bạn được bảo mật',
      'register_tip_body':
          'Chúng tôi chỉ dùng thông tin để cá nhân hóa phân tích tư thế — không chia sẻ khi chưa có sự đồng ý.',
      'register_error_email_taken': 'Email này đã được đăng ký.',
      'register_button': 'Tạo tài khoản',
      'register_google_button': 'Đăng ký bằng Google',
      'register_have_account': 'Đã có tài khoản? ',
      'register_log_in_link': 'Đăng nhập',

      // OTP
      'otp_title': 'Kiểm tra email',
      'otp_subtitle': 'Nhập mã 6 chữ số đã gửi đến {email}',
      'otp_field_label': 'Mã xác thực',
      'otp_field_hint': '123456',
      'otp_error_invalid': 'Mã không đúng hoặc đã hết hạn. Vui lòng thử lại.',
      'otp_error_not_found': 'Không tìm thấy tài khoản.',
      'otp_resend_success': 'Đã gửi mã mới đến email.',
      'otp_verify_button': 'Xác thực',
      'otp_no_code': 'Không nhận được mã? ',
      'otp_sending': 'Đang gửi...',
      'otp_resend': 'Gửi lại',

      // Forgot password
      'forgot_title': 'Quên mật khẩu?',
      'forgot_subtitle':
          'Nhập email tài khoản — chúng tôi sẽ gửi mã để đặt lại mật khẩu.',
      'forgot_tip_title': 'Kiểm tra hộp thư đến',
      'forgot_tip_body':
          'Mã đặt lại có hiệu lực trong 30 phút. Kiểm tra thư rác nếu không thấy.',
      'forgot_send_button': 'Gửi mã đặt lại',
      'forgot_already_have_code': 'Tôi đã có mã',

      // Reset password
      'reset_title': 'Đặt lại mật khẩu',
      'reset_subtitle_no_email': 'Dán mã từ email và chọn mật khẩu mới.',
      'reset_subtitle_with_email': 'Dán mã đã gửi đến {email} và chọn mật khẩu mới.',
      'reset_code_label': 'Mã đặt lại',
      'reset_code_hint': 'Dán mã từ email',
      'reset_new_password_label': 'Mật khẩu mới',
      'reset_new_password_hint': 'Tạo mật khẩu mới',
      'reset_confirm_password_label': 'Xác nhận mật khẩu mới',
      'reset_confirm_password_hint': 'Nhập lại mật khẩu mới',
      'reset_success_snack': 'Đặt lại thành công — đăng nhập bằng mật khẩu mới.',
      'reset_submit_button': 'Đặt lại mật khẩu',
      'tip_strong_password_title': 'Chọn mật khẩu mạnh',
      'tip_strong_password_body':
          'Ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',

      // Onboarding
      'onboarding_finish_button': 'Hoàn thành',
      'onboarding_step1_title': 'Chọn mục tiêu của bạn',
      'onboarding_step2_title': 'Chọn giới tính',
      'onboarding_gender_female': 'Nữ',
      'onboarding_gender_male': 'Nam',
      'onboarding_gender_other': 'Khác',
      'onboarding_step3_title': 'Điều gì thúc đẩy bạn tập?',
      'onboarding_step4_title': 'Chọn nhóm cơ trọng điểm',
      'onboarding_step5_title': 'Chọn trình độ thể lực',
      'onboarding_level_beginner': 'Mới bắt đầu',
      'onboarding_level_beginner_desc': 'Chưa tập hoặc chỉ mới thử một chút',
      'onboarding_level_intermediate': 'Trung cấp',
      'onboarding_level_intermediate_desc': 'Đã có kinh nghiệm tập tạ',
      'onboarding_level_advanced': 'Nâng cao',
      'onboarding_level_advanced_desc': 'Duy trì thói quen tập đều đặn nhiều năm!',
      'onboarding_step6_title': 'Mức độ vận động hiện tại',
      'onboarding_activity_sedentary': 'Ít vận động',
      'onboarding_activity_sedentary_desc': 'Hầu như không tập, làm việc văn phòng',
      'onboarding_activity_light': 'Nhẹ nhàng',
      'onboarding_activity_light_desc': 'Tập nhẹ 1-3 ngày/tuần',
      'onboarding_activity_moderate': 'Vừa phải',
      'onboarding_activity_moderate_desc': 'Tập vừa 3-5 ngày/tuần',
      'onboarding_activity_very': 'Tích cực',
      'onboarding_activity_very_desc': 'Tập nặng 6-7 ngày/tuần',
      'onboarding_activity_extra': 'Rất tích cực',
      'onboarding_activity_extra_desc': 'Tập rất nặng và công việc thể chất',
      'onboarding_step7_title': 'Chiều cao của bạn?',
      'onboarding_height_tip_title': 'Tính chỉ số BMI',
      'onboarding_height_tip_body':
          'Chúng tôi dùng chiều cao để cá nhân hóa phân tích tư thế và thể lực.',
      'onboarding_step8_title': 'Tuổi của bạn?',
      'onboarding_age_tip_title': 'Cá nhân hóa theo tuổi',
      'onboarding_age_tip_body':
          'Tuổi giúp điều chỉnh cường độ buổi tập và thời gian phục hồi phù hợp.',
      'onboarding_step9_title': 'Cân nặng hiện tại của bạn?',
      'onboarding_weight_tip_title': 'Theo dõi tiến trình theo thời gian',
      'onboarding_weight_tip_body':
          'Chúng tôi dùng cân nặng để cá nhân hóa gợi ý và theo dõi xu hướng.',
      'onboarding_step10_title': 'Cân nặng mục tiêu của bạn?',
      'onboarding_target_tip_title': 'Đặt mục tiêu thực tế',
      'onboarding_target_tip_body':
          'Thay đổi nhỏ, bền vững dẫn đến kết quả lâu dài — có thể điều chỉnh bất cứ lúc nào.',
      'onboarding_step11_title': 'Bạn có vấn đề sức khoẻ nào không?',
      'onboarding_step12_title': 'Bạn có thiết bị gì?',
      'onboarding_step13_title': 'Bạn muốn tập bao nhiêu ngày/tuần?',
      'onboarding_step13_subtitle':
          'Kế hoạch gợi ý sẽ điều chỉnh theo tần suất tập của bạn.',
      'onboarding_step14_title': 'Chọn ngày tập trong tuần',

      // Plan generating
      'plan_gen_title': 'Đang tạo kế hoạch tập',
      'plan_gen_subtitle': 'Cá nhân hóa 4 tuần tập luyện theo mục tiêu của bạn',

      // Home
      'home_welcome_back': 'Chào mừng trở lại',
      'home_ai_plan_ready': 'Kế hoạch cá nhân của bạn đã sẵn sàng!',
      'home_load_error': 'Không thể tải dữ liệu tập luyện.',
      'home_posture_score_label': 'ĐIỂM TƯ THẾ',
      'posture_label_no_data': 'Chưa có dữ liệu',
      'posture_label_excellent': 'Xuất sắc',
      'posture_label_strong': 'Tốt',
      'posture_label_fair': 'Khá',
      'posture_label_needs_work': 'Cần cải thiện',
      'home_no_sets_logged': 'Chưa có buổi tập nào',
      'home_weekly_goal': 'Mục tiêu tuần',
      'home_goal_reached': 'Đã đạt mục tiêu tuần này!',
      'home_sessions_to_go': 'Còn {n} buổi tập trong tuần',
      'home_this_week': 'Tuần này',
      'home_daily_posture_avg': 'Tư thế trung bình ngày',
      'home_training_plan': 'Kế hoạch tập luyện',
      'home_week_of_total': 'Tuần {n} / {total}',
      'home_tap_day_hint': 'Nhấn vào ngày để xem buổi tập',
      'home_generating': 'Đang tạo...',
      'home_personalize_ai': 'Cá nhân hóa với AI',
      'home_quick_start': 'Bắt đầu nhanh',
      'home_quick_start_subtitle': 'Vào thẳng buổi tập có hướng dẫn',
      'home_full_body_check_title': 'Kiểm tra toàn thân',
      'home_full_body_exercises': 'Squat · Row · Plank',

      // Exercises
      'exercises_title': 'Bài tập',
      'exercises_search_hint': 'Tìm bài tập',
      'exercises_empty': 'Không tìm thấy bài tập',
      'exercises_tag_live_analysis': 'Phân tích trực tiếp',
      'exercises_filter_all': 'Tất cả',
      'exercise_detail_how_to': 'Cách thực hiện',
      'exercise_detail_start_analysis': 'Bắt đầu phân tích trực tiếp',
      'exercise_detail_no_analysis':
          'Chưa có phân tích trực tiếp cho bài này — xem video hướng dẫn thay thế.',
      'exercise_detail_upload_video': 'Tải video lên thay thế',

      // Workout
      'workout_title': 'Tập luyện',
      'workout_no_active_title': 'Chưa có buổi tập',
      'workout_no_active_subtitle':
          'Bắt đầu buổi mới hoặc chọn bài tập\nđể bắt đầu ghi nhận.',
      'workout_start_empty': 'Bắt đầu buổi tập mới',
      'workout_upload_video': 'Tải video lên',
      'workout_suggested_routines': 'Gợi ý bài tập',
      'workout_routines_hint': 'Chọn bài tập để kiểm tra tư thế',
      'routine_full_body': 'Toàn thân',
      'routine_posture_primer': 'Khởi động tư thế',
      'routine_strength_foundations': 'Nền tảng sức mạnh',

      // Analyze session
      'analyze_starting_camera': 'Đang khởi động camera...',
      'analyze_connecting': 'Đang kết nối máy chủ phân tích...',
      'analyze_permission_denied':
          'Cần quyền truy cập camera để phân tích tư thế.',
      'analyze_open_settings': 'Mở cài đặt',
      'analyze_close': 'Đóng',
      'analyze_init_error': 'Không thể khởi động camera hoặc kết nối máy chủ.',
      'analyze_paused': 'TẠM DỪNG',
      'analyze_reps_label': 'REPS',
      'analyze_end_session': 'Kết thúc',
      'phase_going_down': 'ĐANG XUỐNG',
      'phase_bottom': 'SÂU NHẤT',
      'phase_going_up': 'ĐANG LÊN',
      'phase_top': 'ĐỨNG THẲNG',

      // Workout summary
      'summary_title': 'Hoàn thành buổi tập',
      'summary_reps': 'Reps',
      'summary_duration': 'Thời gian',
      'summary_accuracy': 'Độ chính xác',
      'summary_mistakes_title': 'Lỗi thường gặp nhất',
      'summary_no_errors': 'Không có lỗi kỹ thuật — tư thế tuyệt vời!',
      'summary_done': 'Xong',

      // Notifications
      'notifications_title': 'Thông báo',
      'notifications_mark_all_read': 'Đánh dấu tất cả đã đọc',
      'notifications_empty': 'Chưa có thông báo',
      'time_just_now': 'Vừa xong',
      'time_minutes_ago': '{n} phút trước',
      'time_hours_ago': '{n} giờ trước',
      'time_days_ago': '{n} ngày trước',
      'notif_type_payment': 'Thanh toán',
      'notif_type_workout': 'Tập luyện',
      'notif_type_workout_reminder': 'Nhắc tập luyện',
      'notif_type_nutrition': 'Dinh dưỡng',
      'notif_type_break': 'Nhắc nghỉ ngơi',
      'notif_type_daily_summary': 'Tổng kết ngày',
      'notif_type_subscription': 'Gói đăng ký',
      'notif_type_announcement': 'Thông báo',
      'notif_type_default': 'Thông báo',
      'notif_detail_todays_exercises': 'Bài tập hôm nay',

      // Edit profile
      'edit_profile_title': 'Chỉnh sửa hồ sơ',
      'edit_profile_full_name_label': 'Họ và tên',
      'edit_profile_full_name_hint': 'Tên của bạn',
      'edit_profile_height_label': 'Chiều cao (cm)',
      'edit_profile_weight_label': 'Cân nặng (kg)',
      'edit_profile_age_label': 'Tuổi',
      'edit_profile_change_password': 'Đổi mật khẩu',
      'edit_profile_password_hint_subtitle': 'Để trống nếu không muốn đổi.',
      'edit_profile_new_password_label': 'Mật khẩu mới',
      'edit_profile_new_password_hint': 'Để trống nếu không đổi',
      'edit_profile_confirm_password_label': 'Xác nhận mật khẩu mới',
      'edit_profile_confirm_password_hint': 'Nhập lại mật khẩu mới',
      'edit_profile_save': 'Lưu thay đổi',

      // Profile
      'profile_title': 'Hồ sơ',
      'profile_height': 'Chiều cao',
      'profile_weight': 'Cân nặng',
      'profile_age': 'Tuổi',
      'profile_sessions': 'Buổi tập',
      'profile_reps': 'Reps',
      'profile_posture': 'Tư thế',
      'profile_personal_info': 'Thông tin cá nhân',
      'profile_weekly_goal': 'Mục tiêu tuần',
      'profile_experience': 'Kinh nghiệm',
      'profile_focus_areas': 'Nhóm cơ trọng điểm',
      'profile_training_prefs': 'Sở thích tập luyện',
      'profile_ai_coach': 'AI Coach',
      'profile_settings': 'Cài đặt',
      'profile_sessions_unit': 'buổi',

      // Settings
      'settings': 'Cài đặt',
      'language': 'Ngôn ngữ',
      'english': 'English',
      'vietnamese': 'Tiếng Việt',
      'premium': 'Cao cấp',
      'account': 'Tài khoản',
      'subscribe': 'Đăng ký gói',
      'privacy_policy': 'Chính sách bảo mật',
      'delete_account': 'Xoá tài khoản',
      'delete_account_title': 'Xoá tài khoản?',
      'delete_account_body':
          'Thao tác này sẽ xoá vĩnh viễn tài khoản và toàn bộ dữ liệu tập luyện. Không thể hoàn tác.',
      'log_out': 'Đăng xuất',
      'log_out_title': 'Đăng xuất?',
      'log_out_body': 'Bạn sẽ cần đăng nhập lại để truy cập dữ liệu tư thế.',

      // Subscription
      'subscription_title': 'Chọn gói của bạn',
      'subscription_no_plan_subtitle': 'Khai phá toàn bộ tiềm năng',
      'subscription_cta_choose': 'Chọn gói',

      // AI Coach
      'coach_title': 'AI Coach',
      'coach_hint': 'Hỏi về chế độ tập, dinh dưỡng...',
      'coach_empty': 'Hỏi AI Coach bất cứ điều gì về\ntập luyện & dinh dưỡng',

      // Privacy Policy
      'privacy_title': 'Chính sách bảo mật',
      'privacy_section_data_collected': 'Dữ liệu chúng tôi thu thập',
      'privacy_section_how_used': 'Cách chúng tôi sử dụng dữ liệu',
      'privacy_section_sharing': 'Chia sẻ dữ liệu',
      'privacy_section_storage': 'Lưu trữ & bảo mật dữ liệu',
      'privacy_section_rights': 'Quyền của bạn',
    },
  };
}

/// Add to any StatefulWidget's State class to auto-rebuild when the
/// app language changes:
///   class _MyState extends State<My> with AppLocaleMixin { ... }
mixin AppLocaleMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    AppLocale.notifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.notifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }
}
