import type { AppConfig } from "../config.ts";
import { createTeacherMobileReadHandlers } from "../entity_read/mobile_read_handlers.ts";
import {
  listTeacherAttendanceClasses,
  listTeacherExamMarks,
  listTeacherLeaveRequests,
  listTeacherUpcomingExams,
  overlayTeacherAttendanceStudents,
  overlayTeacherDashboard,
  overlayTeacherHomeworkSubmissions,
} from "../pilot/pilot_operations_repository.ts";
import { teacherStore } from "./teacher_read_repository.ts";

const {
  handleSnapshot,
  handleSnapshotWithOverlay,
  handleTimetableSnapshot,
  handleList,
  handleListWithOverlay,
  handleComputedList,
} = createTeacherMobileReadHandlers(teacherStore);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  // TEACH-5 (MJ-C7): derive todaySchedule / pendingTasks / aiInsight /
  // attendanceSummary from the teacher's real timetable + submitted attendance
  // sessions + pending homework reviews instead of the canned seed payload.
  return await handleSnapshotWithOverlay(
    req,
    config,
    "snapshot_dashboard",
    "Failed to load teacher dashboard",
    async (db, orgId, schoolId, teacherUserId, snapshot) => {
      return await overlayTeacherDashboard(db, orgId, schoolId, teacherUserId, snapshot);
    },
  );
}

export async function handleAttendanceClasses(req: Request, config: AppConfig): Promise<Response> {
  // TEACH-1 (MJ-C7): real classes the teacher teaches (from the timetable), with
  // ids (class_<label>) that match the attendance roster's studentsByClass keys,
  // real enrolled counts and today's marked/pending flag. Empty => [].
  return await handleComputedList(
    req,
    config,
    "Failed to load attendance classes",
    async (db, orgId, schoolId, teacherUserId, pagination) => {
      return await listTeacherAttendanceClasses(db, orgId, schoolId, teacherUserId, pagination);
    },
  );
}

export async function handleAttendanceStudents(req: Request, config: AppConfig): Promise<Response> {
  // TEACH-1 (MJ-C7): build studentsByClass from this teacher's real classes
  // (timetable) + enrolled students, overlaying today's submitted attendance
  // marks. Empty school => studentsByClass:{}, never the seed roster.
  return await handleSnapshotWithOverlay(
    req,
    config,
    "snapshot_attendance_students",
    "Failed to load attendance students",
    async (db, orgId, schoolId, teacherUserId, snapshot) => {
      return await overlayTeacherAttendanceStudents(
        db,
        orgId,
        schoolId,
        teacherUserId,
        snapshot,
      );
    },
  );
}

export async function handleHomework(req: Request, config: AppConfig): Promise<Response> {
  // MJ-C2: overlay each assignment with its real submissions[] (joined from
  // homework_submissions) + pendingReviews so the teacher can see and grade work.
  return await handleListWithOverlay(
    req,
    config,
    "homework_assignment",
    "Failed to load homework assignments",
    async (db, orgId, schoolId, items) => {
      return await overlayTeacherHomeworkSubmissions(db, orgId, schoolId, items);
    },
  );
}

export async function handleExamsUpcoming(req: Request, config: AppConfig): Promise<Response> {
  // TEACH-1 (MJ-C7): real, not-yet-published exam_sessions for the teacher's
  // classes instead of the upcoming_exam seed. Empty => [].
  return await handleComputedList(
    req,
    config,
    "Failed to load upcoming exams",
    async (db, orgId, schoolId, teacherUserId, pagination) => {
      return await listTeacherUpcomingExams(db, orgId, schoolId, teacherUserId, pagination);
    },
  );
}

export async function handleExamsMarks(req: Request, config: AppConfig): Promise<Response> {
  // TEACH-1 (MJ-C7): real exam_mark_entries for the teacher's classes (not yet
  // published) instead of the exam_mark seed. Empty => [].
  return await handleComputedList(
    req,
    config,
    "Failed to load exam marks",
    async (db, orgId, schoolId, teacherUserId, pagination) => {
      return await listTeacherExamMarks(db, orgId, schoolId, teacherUserId, pagination);
    },
  );
}

export async function handleTimetable(req: Request, config: AppConfig): Promise<Response> {
  return await handleTimetableSnapshot(req, config, "Failed to load teacher timetable");
}

export async function handleLeave(req: Request, config: AppConfig): Promise<Response> {
  // TEACH-1 (MJ-C7): the teacher's own leave applications from the canonical
  // mobile_leave_requests store instead of the leave_request seed. Empty => [].
  return await handleComputedList(
    req,
    config,
    "Failed to load teacher leave history",
    async (db, orgId, schoolId, teacherUserId, pagination) => {
      return await listTeacherLeaveRequests(db, orgId, schoolId, teacherUserId, pagination);
    },
  );
}

export async function handleLeaveBalance(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_leave_balance", "Failed to load leave balance");
}

// PRA-N-13 (S0/T1a): `handleMessages` (GET /teacher/messages) was dead code —
// `routeCommunication` (dispatched before `routeTeacher` in app.ts) already owns
// that path via the governed `handleTeacherMessageThreads`. This handler read
// demo-seeded `teacher_entities` `message_thread` rows and was never reached.
