import 'crash_reporting_service.dart';

CrashReportingService createFirebaseCrashReportingService() =>
    const DebugCrashReportingService();
