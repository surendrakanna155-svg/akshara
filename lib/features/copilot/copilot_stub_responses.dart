import 'copilot_role_intelligence.dart';
import 'copilot_screen_context.dart';

String buildContextAwareStubReply({
  required String userMessage,
  required CopilotScreenContext? screenContext,
}) {
  final ctx = screenContext;
  final persona = ctx?.personaRole ?? CopilotPersonaRole.directorCorrespondent;
  final focus = persona.intelligenceFocus.take(3).join(', ');
  final screen = ctx?.screen ?? 'ERP';
  final module = ctx?.module ?? 'general';
  final kpis = ctx?.kpis ?? const [];
  final filters = ctx?.filters ?? const {};
  final records = ctx?.records ?? const {};

  final buffer = StringBuffer()
    ..writeln('**${persona.label} Copilot (context-aware stub)**')
    ..writeln()
    ..writeln('You asked: "${userMessage.trim()}"')
    ..writeln()
    ..writeln('**Context**')
    ..writeln('- Screen: $screen')
    ..writeln('- Module: $module')
    ..writeln('- Role focus: $focus');

  if (ctx?.schoolId.isNotEmpty ?? false) {
    buffer.writeln('- School: ${ctx!.schoolId}');
  }
  if (ctx?.activeChildId != null) {
    buffer.writeln('- Active child: ${ctx!.activeChildId}');
  }
  if (filters.isNotEmpty) {
    buffer.writeln('- Filters: ${filters.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
  }
  if (kpis.isNotEmpty) {
    buffer.writeln('- KPIs on screen:');
    for (final kpi in kpis.take(6)) {
      buffer.writeln('  • ${kpi.label}: ${kpi.value}');
    }
  }
  if (records.isNotEmpty) {
    buffer.writeln('- Records: ${records.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
  }

  buffer
    ..writeln()
    ..writeln(_personaInsight(persona, module))
    ..writeln()
    ..writeln('_Read-only guidance. No records were modified._');

  return buffer.toString();
}

String _personaInsight(CopilotPersonaRole persona, String module) {
  return switch (persona) {
    CopilotPersonaRole.platformOwner =>
      '**Platform insight:** Compare schools by revenue and enrollment; prioritize expansion where conversion exceeds 15%.',
    CopilotPersonaRole.organizationOwner =>
      '**Trust insight:** Review portfolio health across schools; align fee collection targets before Q3 admissions push.',
    CopilotPersonaRole.directorCorrespondent =>
      '**Director insight:** Fee collection and admissions funnel on $module need weekly review; correlate defaulters with class attendance.',
    CopilotPersonaRole.principal =>
      '**Principal insight:** Monitor attendance dips and at-risk students; schedule teacher effectiveness reviews for underperforming sections.',
    CopilotPersonaRole.academicCoordinator =>
      '**Academic insight:** Resolve timetable conflicts and track weak chapters before term assessments.',
    CopilotPersonaRole.teacher =>
      '**Teacher insight:** Follow up on missing homework and attendance alerts for your class roster.',
    CopilotPersonaRole.parent =>
      '**Parent insight:** Review your child\'s attendance and upcoming homework deadlines; contact the class teacher for concerns.',
    CopilotPersonaRole.student =>
      '**Study insight:** Focus revision on weak subjects and upcoming exam topics from your timetable.',
  };
}
