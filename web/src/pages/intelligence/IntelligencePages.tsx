import { KpiPage } from '@/components/system/KpiPage';
import { MODULE_TABS } from '@/routes/navConfig';

const TABS = MODULE_TABS.intelligence;

/** Intelligence dashboards — live-wired to /intelligence/*; trust + ai-economics
 *  endpoints are pending (gap WEB-006) so those two render the awaiting state. */
export const IntelligenceHubPage = () => (
  <KpiPage title="Intelligence" subtitle="AI insights & priorities" icon="auto_awesome" tabs={TABS} endpoint="/intelligence/priorities" queryKey={['intel', 'priorities']} icons={['priority_high', 'lightbulb', 'insights', 'auto_awesome']} />
);
export const StudentSuccessPage = () => (
  <KpiPage title="Student success" subtitle="Risk, predictions & interventions" icon="school" tabs={TABS} endpoint="/intelligence/student-success/dashboard" queryKey={['intel', 'student-success']} icons={['school', 'trending_up', 'warning', 'psychology']} />
);
export const TeacherEffectivenessPage = () => (
  <KpiPage title="Teacher effectiveness" subtitle="Lesson quality & outcomes" icon="cast_for_education" tabs={TABS} endpoint="/intelligence/teacher-effectiveness/performance" queryKey={['intel', 'teacher-eff']} />
);
export const ExamIntelligencePage = () => (
  <KpiPage title="Exam intelligence" subtitle="Results, forecasts & weak areas" icon="grading" tabs={TABS} endpoint="/intelligence/exam/analytics" queryKey={['intel', 'exam']} icons={['grading', 'insights', 'trending_up', 'menu_book']} />
);
export const HomeworkIntelligencePage = () => (
  <KpiPage title="Homework intelligence" subtitle="Load, completion & planning" icon="assignment" tabs={TABS} endpoint="/intelligence/homework-intelligence/plan" queryKey={['intel', 'homework']} />
);
export const TrustIntelligencePage = () => (
  <KpiPage title="Trust & governance" subtitle="AI trust, safety & audit" icon="verified_user" tabs={TABS} endpoint="/intelligence/trust" queryKey={['intel', 'trust']}
    unavailableMessage="AI trust & governance metrics will load from /intelligence/trust once that endpoint is exposed (gap WEB-006). No simulated data is shown." />
);
export const AiEconomicsPage = () => (
  <KpiPage title="AI economics" subtitle="AI cost, tokens & savings" icon="savings" tabs={TABS} endpoint="/intelligence/ai-economics" queryKey={['intel', 'ai-economics']} icons={['savings', 'payments', 'bolt', 'trending_down']}
    unavailableMessage="AI cost/token economics will load from /intelligence/ai-economics once that endpoint is exposed (gap WEB-006). No simulated data is shown." />
);
