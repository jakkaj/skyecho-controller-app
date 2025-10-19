/// Pure-Dart library for receiving and parsing GDL90 aviation data streams.
library;

// CRC validation (Phase 2)
export 'src/crc.dart';

// Byte framing (Phase 3)
export 'src/framer.dart';

// Future exports (added in Phases 4-8):
// export 'src/parser.dart';
// export 'src/models/gdl90_message.dart';
// export 'src/models/gdl90_event.dart';
// export 'src/stream/gdl90_stream.dart';
