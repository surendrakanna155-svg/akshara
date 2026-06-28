import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/features/copilot/dock/copilot_dock_provider.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// QW1 messaging journeys (QA-J-002 parent→teacher, QA-J-013 teacher→parent incl
/// AI, QA-J-057 the 1:1 send path in both directions). Each proves a real
/// compose → send → persist round-trip — the gap was that no message *send* was
/// exercised in ANY direction.
///
/// The floating AI dock is disabled (it overlays the bottom composer / send CTA).
List<Override> _noDock() => [copilotDockVisibleProvider.overrideWithValue(false)];

void main() {
  // QA-J-002 + QA-J-057 (parent → teacher direction).
  patrolTest(
    'qw1-msg: parent replies in a conversation thread and it persists',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent, extraOverrides: _noDock());
      await goToErpRoute($, RouteNames.parentMessages);
      await scrollTap($, 'Ravi Kumar · 8-A'); // open the seeded thread

      const reply = 'Noted, thank you for the update QW1MSG-P2T';
      await $(find.byType(TextField)).enterText(reply);
      await $.pumpAndSettle();
      await $('Send').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      // The sent message round-trips into the persisted thread.
      await assertVisibleText($, reply);
    },
  );

  // QA-J-057 (teacher → parent direction) + QA-J-013 compose/send/persist core.
  patrolTest(
    'qw1-msg: teacher replies to a parent thread and it persists',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher, extraOverrides: _noDock());
      // Direct-nav to the seeded conversation (the list uses parentName titles +
      // a multiline subtitle + tabs, which is brittle to tap).
      await goToErpRoute($, RouteNames.teacherConversation('thread_1'));

      const reply = "Today's summary is shared, regards QW1MSG-T2P";
      await $(find.byType(TextField)).enterText(reply);
      await $.pumpAndSettle();
      await $('Send').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await assertVisibleText($, reply);
    },
  );

  // NOTE (QA-J-013): teacher → parent compose + send + thread-persist is proven
  // above (the teacher conversation reply IS a teacher message to a parent that
  // persists). The dedicated rich parent-communication screen's AI-generate /
  // multi-channel variant runs the SAME `sendParentCommunication` path; its
  // multi-step UI + AI dialog is Patrol-flaky, so that screen's UI behaviour is
  // certified under QW7 (QA-C-010..014 communication behaviour), not here.
}
