abstract final class AcademicOperationsApiPaths {
  static const String transitionsBase = '/academic/transitions';
  static const String operationsBase = '/academic/operations';

  static const String suggestMappings = '$transitionsBase/suggest-mappings';
  static const String previewTransition = '$transitionsBase/preview';

  static String executeTransition(String jobId) =>
      '$transitionsBase/$jobId/execute';
  static String transitionJob(String jobId) => '$transitionsBase/$jobId';

  static const String previewReshuffle = '$operationsBase/reshuffle/preview';
  static const String previewSectionBalance =
      '$operationsBase/section-balance/preview';
  static const String previewQuarterlyReshuffle =
      '$operationsBase/quarterly-reshuffle/preview';
  static const String previewPerformanceBalance =
      '$operationsBase/performance-balance/preview';

  static String executeReshuffle(String planId) =>
      '$operationsBase/reshuffle/$planId/execute';
  static String executeSectionBalance(String planId) =>
      '$operationsBase/section-balance/$planId/execute';
  static String executeQuarterlyReshuffle(String planId) =>
      '$operationsBase/quarterly-reshuffle/$planId/execute';
  static String executePerformanceBalance(String planId) =>
      '$operationsBase/performance-balance/$planId/execute';
}
