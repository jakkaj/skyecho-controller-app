import 'package:flutter/foundation.dart';

import 'gdl_service.dart';
import 'gdl_service_interface.dart';
import 'mock_gdl_service.dart';

/// Factory for creating GDL service instances based on environment.
///
/// Automatically selects between mock and real services based on:
/// - Debug vs release mode
/// - Compile-time flags
/// - Manual override
class GdlServiceFactory {
  /// Create appropriate GDL service based on debug mode and configuration.
  ///
  /// Returns [MockGdlService] when:
  /// - Running in debug mode AND
  /// - `USE_MOCK_GDL` environment variable is true OR
  /// - [useMockData] parameter is explicitly true
  ///
  /// Otherwise returns real [GdlService] connected to hardware.
  ///
  /// Example usage:
  /// ```dart
  /// // Auto-detect (uses mock in debug mode with flag)
  /// final service = GdlServiceFactory.create();
  ///
  /// // Force mock data
  /// final mockService = GdlServiceFactory.create(useMockData: true);
  ///
  /// // Force real hardware
  /// final realService = GdlServiceFactory.create(useMockData: false);
  /// ```
  ///
  /// To enable mock mode during development:
  /// ```bash
  /// flutter run --dart-define=USE_MOCK_GDL=true
  /// ```
  static GdlServiceInterface create({bool? useMockData}) {
    // Check compile-time flag
    const useMockFlag =
        bool.fromEnvironment('USE_MOCK_GDL', defaultValue: false);

    // Determine if we should use mock:
    // 1. Explicit override (useMockData parameter) takes precedence
    // 2. Otherwise use flag if in debug mode
    final shouldUseMock =
        useMockData ?? (kDebugMode && useMockFlag);

    if (shouldUseMock) {
      debugPrint('[GDL] Using MockGdlService (debug mode)');
      debugPrint('[GDL] Mock data: Ownship at Heck Field (YHEC), 1000ft');
      debugPrint('[GDL] Mock data: 3 traffic targets within 10nm');
      return MockGdlService();
    } else {
      debugPrint('[GDL] Using real GdlService (hardware on UDP 4000)');
      return GdlService();
    }
  }
}
