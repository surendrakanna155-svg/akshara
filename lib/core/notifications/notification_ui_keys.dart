import 'package:flutter/material.dart';

/// Messenger key wired into [MaterialApp.router] so the push layer can show an
/// in-app banner for foreground notifications without a BuildContext.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
