import 'package:flutter/widgets.dart';

/// Kunci navigator global supaya lapisan non-widget (mis. ApiClient) bisa
/// berpindah layar — dipakai untuk memaksa kembali ke /login saat sesi habis.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
