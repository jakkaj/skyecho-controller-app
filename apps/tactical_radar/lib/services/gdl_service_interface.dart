/// Abstract interface for GDL90 service layer.
///
/// Enables unit tests to mock GDL90 stream without UDP sockets.
/// Concrete implementation wraps skyecho_gdl90 package per Discovery 04
/// (service layer boundaries).
abstract class GdlServiceInterface {
  /// Stream of GDL90 messages received from the device.
  ///
  /// Emits Gdl90Message objects as they are parsed from the UDP stream.
  /// UI layer should listen to this stream and batch updates at 10 FPS.
  Stream<dynamic> get messages;

  /// Stream of connection status updates.
  ///
  /// Emits `true` when actively receiving messages, `false` when connection
  /// is stale (no messages for 10s) or explicitly disconnected.
  Stream<bool> get connectionStatus;

  /// Stream of error messages from GDL90 parsing.
  ///
  /// Emits human-readable error strings when parse errors occur.
  /// These are non-fatal; the stream continues processing.
  Stream<String> get errors;

  /// Whether the service is currently connected and receiving data.
  bool get isConnected;

  /// Last received ownship report, or null if none received yet.
  ///
  /// Updated whenever an ownship message (ID 0x0A) is received.
  /// UI can use this for quick access without listening to full message stream.
  dynamic get lastOwnshipReport;

  /// Map of active traffic targets keyed by ICAO address.
  ///
  /// Targets are automatically expired after 30 seconds without update.
  /// Returns an unmodifiable view to prevent external modification.
  Map<int, dynamic> get activeTrafficTargets;

  /// Connect to the GDL90 stream and start receiving messages.
  ///
  /// Binds to UDP port 4000 on 0.0.0.0 (any interface).
  /// Starts health monitoring (marks connection stale after 10s).
  ///
  /// Throws exception if socket bind fails.
  Future<void> connect();

  /// Disconnect from the GDL90 stream.
  ///
  /// Pauses message reception but does not dispose resources.
  /// Can call [connect] again to resume.
  Future<void> disconnect();

  /// Dispose all resources and close streams.
  ///
  /// After calling dispose, this service instance cannot be reused.
  /// Create a new instance if reconnection is needed.
  void dispose();
}
