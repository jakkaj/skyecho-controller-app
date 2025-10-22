/// Pure-Dart library for receiving and parsing GDL90 aviation data streams.
library;

// CRC validation (Phase 2)
export 'src/crc.dart';

// Byte framing (Phase 3)
export 'src/framer.dart';

// Message routing & parser core (Phase 4)
export 'src/models/gdl90_message.dart';
export 'src/models/gdl90_event.dart';
export 'src/parser.dart';

// Stream transport layer (Phase 8)
export 'src/stream/gdl90_stream.dart';
