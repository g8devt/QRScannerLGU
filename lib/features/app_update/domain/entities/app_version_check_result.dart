/// Outcome of a [CheckAppUpdate] call.
///
/// [checkFailed] is distinct from [upToDate] on purpose: a network/server
/// error must never be treated as "no update needed" — AuthGate keeps the
/// user blocked and offers a retry instead of silently letting them in.
enum AppVersionCheckOutcome { upToDate, updateRequired, checkFailed }

class AppVersionCheckResult {
  const AppVersionCheckResult({
    required this.outcome,
    this.latestVersion,
    this.url,
  });

  final AppVersionCheckOutcome outcome;
  final String? latestVersion;
  final String? url;

  bool get blocksLogin => outcome != AppVersionCheckOutcome.upToDate;
}
