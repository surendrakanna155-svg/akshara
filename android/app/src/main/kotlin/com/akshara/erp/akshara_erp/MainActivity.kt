package com.akshara.erp.akshara_erp

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so the
// device biometric prompt (staff Face ID / fingerprint check-in, O5) can attach
// to a FragmentActivity host on Android.
class MainActivity : FlutterFragmentActivity()
