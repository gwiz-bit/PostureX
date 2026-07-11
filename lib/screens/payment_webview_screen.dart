import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

/// Mở trang thanh toán VNPay trong WebView.
///
/// Dùng WebView thay vì mở trình duyệt ngoài vì quay lại app từ trình duyệt
/// cần deep link; ở đây chỉ cần bắt điều hướng là biết đã xong.
///
/// Pop trả về:
///   `true`  — VNPay đã redirect về `/payments/vnpay/return` và báo thành công
///   `false` — thanh toán thất bại / bị huỷ
///   `null`  — người dùng tự đóng giữa chừng (chưa rõ kết quả)
///
/// Lưu ý: kết quả này chỉ để hiển thị cho nhanh. **Nguồn sự thật là backend** —
/// màn gọi nó phải gọi lại `GET /subscriptions/me` để biết gói đã bật hay chưa,
/// vì chính backend mới là bên xác minh chữ ký và kích hoạt gói.
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
          onPageStarted: (url) => _checkForReturnUrl(url),
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.payUrl));
  }

  /// Backend redirect về `/api/v1/payments/vnpay/return?...` khi thanh toán
  /// xong. Bắt đúng đường dẫn đó — kết quả nằm trong `vnp_ResponseCode`
  /// ("00" là thành công).
  void _checkForReturnUrl(String url) {
    if (_finished || !url.contains('/payments/vnpay/return')) return;

    _finished = true;
    final code = Uri.parse(url).queryParameters['vnp_ResponseCode'];
    if (mounted) Navigator.of(context).pop(code == '00');
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
