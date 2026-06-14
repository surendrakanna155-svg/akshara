import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_names.dart';

class SchoolCompletionHubScreen extends StatelessWidget {
  const SchoolCompletionHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School Completion')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Subject Management'),
            subtitle: const Text('Catalog, codes, and grade mapping'),
            onTap: () => context.push(RouteNames.subjectsManagement),
          ),
          ListTile(
            leading: const Icon(Icons.history_edu_outlined),
            title: const Text('Lesson Logs'),
            subtitle: const Text('Record daily lesson outcomes'),
            onTap: () => context.push(RouteNames.lessonLogs),
          ),
          ListTile(
            leading: const Icon(Icons.auto_fix_high_outlined),
            title: const Text('Timetable Automation'),
            subtitle: const Text('Generate timetables from subjects'),
            onTap: () => context.push(RouteNames.timetableAutomation),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('School Branding'),
            subtitle: const Text('Colors, logo, and login theme'),
            onTap: () => context.push(RouteNames.schoolBranding),
          ),
          ListTile(
            leading: const Icon(Icons.grid_on_outlined),
            title: const Text('Subject Assignments'),
            subtitle: const Text('Class matrix, electives, teacher workload'),
            onTap: () => context.push(RouteNames.subjectAssignments),
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Lesson Analytics'),
            subtitle: const Text('Syllabus coverage and pending topics'),
            onTap: () => context.push(RouteNames.lessonAnalytics),
          ),
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: const Text('Timetable Optimization'),
            subtitle: const Text('Workload balance and conflict detection'),
            onTap: () => context.push(RouteNames.timetableOptimization),
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Communication Delivery'),
            subtitle: const Text('Template delivery analytics'),
            onTap: () => context.push(RouteNames.communicationDelivery),
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Broadcast Admin'),
            subtitle: const Text('Compose, templates, and broadcast history'),
            onTap: () => context.push(RouteNames.communicationBroadcastAdmin),
          ),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Communication Analytics'),
            subtitle: const Text('Campaigns, engagement, and parent adoption'),
            onTap: () => context.push(RouteNames.communicationAnalytics),
          ),
          ListTile(
            leading: const Icon(Icons.rocket_launch_outlined),
            title: const Text('Pilot Toolkit'),
            subtitle: const Text('First-school onboarding success'),
            onTap: () => context.push(RouteNames.pilotDashboard),
          ),
          ListTile(
            leading: const Icon(Icons.family_restroom_outlined),
            title: const Text('Parent Activation'),
            subtitle: const Text('Activation %, DAU, MAU, adoption'),
            onTap: () => context.push(RouteNames.parentActivationDashboard),
          ),
          ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: const Text('Room & Lab Allocation'),
            subtitle: const Text('Auto-assign rooms and science labs'),
            onTap: () => context.push(RouteNames.roomAllocation),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('WhatsApp Status'),
            subtitle: const Text('Read-only — provider managed by super admin'),
            onTap: () => context.push(RouteNames.whatsAppProvider),
          ),
          ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: const Text('Syllabus Automation'),
            subtitle: const Text('Templates, generation, and year cloning'),
            onTap: () => context.push(RouteNames.syllabusAutomation),
          ),
          ListTile(
            leading: const Icon(Icons.track_changes_outlined),
            title: const Text('Academic Progress'),
            subtitle: const Text('Teacher and principal coverage dashboards'),
            onTap: () => context.push(RouteNames.academicProgress),
          ),
          ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: const Text('Timetable Intelligence'),
            subtitle: const Text('Rooms, labs, exam timetable, scoring'),
            onTap: () => context.push(RouteNames.timetableIntelligence),
          ),
        ],
      ),
    );
  }
}
