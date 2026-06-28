import 'dart:async';

import 'package:akshara_erp/features/achievement_promotion/achievement_promotion_preview_screen.dart';
import 'package:akshara_erp/features/achievement_promotion/achievement_promotion_screen.dart';
import 'package:akshara_erp/features/phase5/phase5_models.dart';
import 'package:akshara_erp/features/phase5/phase5_providers.dart';
import 'package:akshara_erp/shared/widgets/akshara_empty_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-028 — Publisher post-create surface + AI poster/caption render
/// (`achievement_promotion_screen.dart` had ZERO Flutter coverage), plus forced
/// loading / empty / error states (the screen consumes a raw FutureProvider, so
/// the states are forced by overriding `achievementPromotionsProvider`).
/// QW3 · QA-F-029 — Approved promotion → destination multi-select → Publish.
/// NOTE: the Approve → destinations → Publish flow lives in the *list* screen's
/// `_advanceWorkflow` + `_pickDestinations` dialog (driven by tapping an
/// `approved` card), NOT in the preview screen the row originally pointed at.
/// The preview screen only renders metadata + Export/Share. Both are covered.

/// A published demo promotion with a poster + WhatsApp banner (AI poster/caption
/// metadata). Mirrors the shape returned by the demo repository.
AchievementPromotion _publishedPromotion() => const AchievementPromotion(
      id: 'promo_1',
      achievementType: 'gold_medal',
      title: 'Gold Medal — Science Olympiad',
      status: 'published',
      assets: {
        'poster': {
          'id': 'poster',
          'label': 'Poster',
          'headline': 'Celebrating Gold Medal — Science Olympiad',
          'caption': 'Official achievement poster',
          'format': 'image/png',
          'width': 1080,
          'height': 1920,
          'aspectRatio': '9:16',
        },
      },
      analytics: {'views': 120, 'shares': 34, 'downloads': 18},
    );

AchievementPromotion _approvedPromotion() => const AchievementPromotion(
      id: 'promo_appr',
      achievementType: 'competition_winner',
      title: 'Annual Fest Win',
      status: 'approved',
      assets: {},
      analytics: {'views': 0, 'shares': 0, 'downloads': 0},
    );

Future<void> _pumpList(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const AchievementPromotionScreen(),
      ),
    ),
  );
  if (settle) {
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('QA-F-028 · AchievementPromotionScreen', () {
    testWidgets('renders the create surface + a promotion card', (tester) async {
      await _pumpList(tester);

      expect(find.text('Promotion Center'), findsOneWidget);
      // Create surface: the FloatingActionButton with an add icon.
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      // Demo promotion card renders.
      expect(find.text('Gold Medal — Science Olympiad'), findsOneWidget);
    });

    testWidgets('shows the loading state when the future is pending',
        (tester) async {
      await _pumpList(
        tester,
        overrides: [
          // Never-completing future keeps the screen in its loading branch.
          achievementPromotionsProvider.overrideWith(
            (ref) => Completer<List<AchievementPromotion>>().future,
          ),
        ],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no promotions',
        (tester) async {
      await _pumpList(
        tester,
        overrides: [
          achievementPromotionsProvider.overrideWith((ref) async => const []),
        ],
      );

      expect(find.byType(AksharaEmptyState), findsOneWidget);
      expect(find.text('No promotions yet — create one'), findsOneWidget);
    });

    testWidgets('shows the error state when the future fails', (tester) async {
      await _pumpList(
        tester,
        overrides: [
          achievementPromotionsProvider.overrideWith(
            (ref) async => throw Exception('boom'),
          ),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });

    testWidgets('AI poster + caption metadata render in the preview screen',
        (tester) async {
      // The preview screen is the AI poster/caption surface: it lists each
      // generated asset's headline + caption + size from assetPreviews.
      useMobileViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides(),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: AchievementPromotionPreviewScreen(
              promotion: _publishedPromotion(),
            ),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // Poster asset metadata (the AI-generated headline + caption + format).
      expect(find.text('Poster'), findsOneWidget);
      expect(
        find.text('Celebrating Gold Medal — Science Olympiad'),
        findsOneWidget,
      );
      expect(find.text('Official achievement poster'), findsOneWidget);
      expect(find.text('Format: image/png'), findsOneWidget);
      // Image preview placeholder (Copilot gen interface) renders.
      expect(
        find.text('Image preview (Copilot gen interface ready)'),
        findsOneWidget,
      );
    });
  });

  group('QA-F-029 · Approve → destinations → publish', () {
    testWidgets('approved card opens the destination multi-select then publishes',
        (tester) async {
      // Seed an `approved` promotion so tapping its card runs _advanceWorkflow,
      // which opens the publish-destinations multi-select dialog.
      await _pumpList(
        tester,
        overrides: [
          achievementPromotionsProvider.overrideWith(
            (ref) async => [_approvedPromotion()],
          ),
        ],
      );

      expect(find.text('Annual Fest Win'), findsOneWidget);
      // Subtitle carries the "Tap to publish" workflow hint (combined Text).
      expect(find.textContaining('Tap to publish'), findsOneWidget);

      // Tap the approved card → destination multi-select dialog appears.
      await tester.tap(find.text('Annual Fest Win'));
      await tester.pumpAndSettle();

      expect(find.text('Select publish destinations'), findsOneWidget);
      // Channel options render (parent / student / teacher / WhatsApp / website).
      expect(find.text('Parent App'), findsOneWidget);
      expect(find.text('Student App'), findsOneWidget);
      expect(find.text('Teacher App'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('School Website'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);

      // Toggle WhatsApp on, then publish. The publish FilledButton is enabled
      // because the default selection is non-empty.
      await tester.tap(find.text('WhatsApp'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
      await tester.pumpAndSettle();

      // Dialog closes after the publish call resolves (mutation fired without
      // throwing — the demo repo returns a published promotion).
      expect(find.text('Select publish destinations'), findsNothing);
    });
  });
}
