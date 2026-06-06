import 'package:flutter/material.dart';

/// Full-area centered loading indicator for screen bodies.
class AksharaLoadingState extends StatelessWidget {
  const AksharaLoadingState({
    super.key,
    this.semanticLabel = 'Loading',
  });

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
