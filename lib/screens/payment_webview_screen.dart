import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

/// Mở trang thanh toán MoMo trong WebView.
///
/// Dùng WebView thay vì mở trình duyệt ngoài vì quay lại app từ trình duyệt
/// cần deep link; ở đây chỉ cần bắt điều hướng là biết đã xong.
///
/// Pop trả về:
///   `true`  — MoMo đã redirect về `/payments/momo/return`
///   `null`  — người dùng tự đóng giữa chừng (chưa rõ kết quả)
///
/// Lưu ý: giá trị này **không phải kết quả thanh toán**, chỉ là "đã quay về".
/// **Nguồn sự thật là backend** — màn gọi nó phải gọi lại `GET /subscriptions/me`
/// để biết gói đã bật hay chưa. Chính backend mới là bên hỏi MoMo xem đơn đã
/// trả tiền thật chưa (API `/query`), nên tham số trên URL này không đáng tin.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({super.key, required this.payUrl});

  final String payUrl;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigate,
          onPageStarted: _checkForReturnUrl,
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.payUrl));
  }

  /// Chặn mọi điều hướng **không phải http/https** và mở ra ngoài WebView.
  ///
  /// Bấm "Thanh toán bằng Ví MoMo", trang web gọi deeplink `momo://app?...` để
  /// bật app MoMo. WebView chỉ hiểu http/https nên gặp scheme lạ là chết với
  /// `ERR_UNKNOWN_URL_SCHEME`. Phải tự bắt lấy và giao cho hệ điều hành.
  Future<NavigationDecision> _onNavigate(NavigationRequest request) async {
    final uri = Uri.parse(request.url);
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return NavigationDecision.navigate;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _showAppMissing();
    } catch (_) {
      // Không có app nào đăng ký scheme này (emulator thường chưa cài MoMo).
      _showAppMissing();
    }
    return NavigationDecision.prevent;
  }

  void _showAppMissing() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Chưa cài ứng dụng MoMo trên máy này. '
          'Hãy quét mã QR bằng MoMo trên điện thoại, hoặc cài MoMo Test App.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  /// MoMo redirect về `/api/v1/payments/momo/return?...` khi xong. Bắt đúng
  /// đường dẫn đó rồi đóng WebView.
  ///
  /// **Cố ý không đọc `resultCode` trên URL.** Người dùng sửa được URL trong
  /// WebView, nên tin nó là tự cho phép kích hoạt Premium miễn phí. Backend đã
  /// hỏi thẳng MoMo rồi — màn gọi chỉ cần hỏi lại `/subscriptions/me`.
  void _checkForReturnUrl(String url) {
    if (_finished || !url.contains('/payments/momo/return')) return;

    _finished = true;
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          // pop(null): người dùng bỏ ngang, chưa biết kết quả.
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      ),
    );
  }
}
