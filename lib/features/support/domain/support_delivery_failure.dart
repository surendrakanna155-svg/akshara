/// ASIP Phase 1 — the honest-failure contract for the support WRITE path.
///
/// Why this type exists
/// --------------------
/// "Report an issue" is the one screen where a lie is unrecoverable: if the app
/// prints a ticket reference, the user stops reporting. They believe NIKSHA
/// Support has their problem. Nobody follows up, because nobody ever received
/// anything.
///
/// So the write path has exactly one rule: **a reference number may only ever be
/// shown when a server issued it.** Every implementation of the support write
/// surface (`createIncident` / `postMessage` / `uploadAttachment`) therefore
/// either returns a record that came back from the server, or throws this. There
/// is no third outcome — in particular there is no locally-invented id.
///
/// This is also why the in-memory stand-in throws instead of pretending: a mock
/// may substitute for *reading* data it does not have, never for *delivering*
/// something to a human being. Throwing keeps the honest-failure UI on the
/// developer's daily path instead of letting it rot behind a flag.
library;

/// Why a support write did not reach NIKSHA Support.
enum SupportDeliveryFailureReason {
  /// This build has no live support channel at all — the `/support` API is not
  /// enabled, so nothing was even attempted. Retrying in this build will fail
  /// the same way; the user still gets a truthful "not sent" and their words
  /// are kept.
  notConfigured,

  /// Delivery was attempted and did not complete: offline, timed out, or the
  /// server refused it. Retrying is worth doing.
  notDelivered,
}

/// Thrown when something the user asked us to send to NIKSHA Support did not
/// reach NIKSHA Support.
class SupportDeliveryFailure implements Exception {
  const SupportDeliveryFailure(this.reason, {this.cause});

  /// No live support channel exists in this build — nothing was attempted.
  const SupportDeliveryFailure.notConfigured()
      : this(SupportDeliveryFailureReason.notConfigured);

  /// A send was attempted and did not complete.
  const SupportDeliveryFailure.notDelivered({Object? cause})
      : this(SupportDeliveryFailureReason.notDelivered, cause: cause);

  final SupportDeliveryFailureReason reason;

  /// The underlying transport/server error, kept for logs only. It is never
  /// shown to the user (it can carry backend internals).
  final Object? cause;

  @override
  String toString() =>
      'SupportDeliveryFailure(${reason.name}${cause == null ? '' : ', cause: $cause'})';
}
