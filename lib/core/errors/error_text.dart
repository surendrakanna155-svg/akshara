import 'api_failure_mapper.dart';

/// RT-27 — the user-facing message for any caught error, routed through the
/// standard [ApiFailureMapper] so raw exception text (e.g.
/// `ApiFailureException.toString()` or a Dio stack) is never shown in a SnackBar
/// or inline error. Server-provided validation messages survive (they come
/// through `ApiFailure.message`); everything else maps to a clean category
/// message.
String aksharaErrorMessage(Object error) =>
    apiFailureMapper.fromException(error).displayMessage;
