abstract final class WorkflowApiPaths {
  static const String definitions = '/workflow/definitions';
  static const String instances = '/workflow/instances';
  static const String triggers = '/workflow/triggers';
  static const String scheduledJobs = '/workflow/scheduled-jobs';

  static String definition(String id) => '$definitions/$id';
  static String instanceAction(String id) => '$instances/$id/actions';
  static const String runScheduled = '$scheduledJobs/run';
}
