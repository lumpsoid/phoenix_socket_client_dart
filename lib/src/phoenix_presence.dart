import 'package:phoenix_socket_client/src/phoenix_message.dart';

/// A single presence entry returned by the server.
class PresenceMeta {
  const PresenceMeta({required this.phxRef, required this.data});

  /// Server-assigned unique key for this presence instance.
  final String phxRef;

  /// Arbitrary metadata the server attached (e.g. online_at, username).
  final Map<String, dynamic> data;

  @override
  String toString() => 'PresenceMeta(phxRef: $phxRef, data: $data)';
}

/// All presence entries for a single user key.
class PresenceEntry {
  PresenceEntry({required List<PresenceMeta> metas}) : _metas = metas;

  final List<PresenceMeta> _metas;
  List<PresenceMeta> get metas => List.unmodifiable(_metas);

  void addMeta(PresenceMeta meta) => _metas.add(meta);
  void removeMeta(String phxRef) =>
      _metas.removeWhere((m) => m.phxRef == phxRef);

  bool get isEmpty => _metas.isEmpty;

  @override
  String toString() => 'PresenceEntry(metas: $_metas)';
}

/// Tracks Phoenix Presence diffs (presence_state / presence_diff events).
///
/// Call [handleEvent] for every inbound [PhoenixMessage] on the channel;
/// it ignores non-presence events automatically.
///
/// ```dart
/// final presence = PhoenixPresence();
/// channel.on('presence_state').listen(presence.handleEvent);
/// channel.on('presence_diff').listen(presence.handleEvent);
///
/// presence.list.forEach((key, entry) => print('$key: ${entry.metas}'));
/// ```
class PhoenixPresence {
  final Map<String, PresenceEntry> _state = {};

  /// Immutable view of current presence state keyed by user ID / topic.
  Map<String, PresenceEntry> get list => Map.unmodifiable(_state);

  /// Returns the metas for a single key, or empty list if not present.
  List<PresenceMeta> metasFor(String key) => _state[key]?.metas ?? const [];

  /// Process a `presence_state` or `presence_diff` event.
  ///
  /// Unknown events are silently ignored.
  void handleEvent(PhoenixMessage msg) {
    switch (msg.event) {
      case 'presence_state':
        _handleState(msg.payload);
      case 'presence_diff':
        _handleDiff(msg.payload);
    }
  }

  void _handleState(Map<String, dynamic> payload) {
    _state.clear();
    payload.forEach((key, raw) {
      final entry = _parseEntry(raw as Map<String, dynamic>);
      if (!entry.isEmpty) _state[key] = entry;
    });
  }

  void _handleDiff(Map<String, dynamic> payload) {
    final joins = payload['joins'] as Map<String, dynamic>? ?? {};
    final leaves = payload['leaves'] as Map<String, dynamic>? ?? {};

    joins.forEach((key, raw) {
      final incoming = _parseEntry(raw as Map<String, dynamic>);
      final existing = _state.putIfAbsent(key, () => PresenceEntry(metas: []));
      incoming.metas.forEach(existing.addMeta);
    });

    leaves.forEach((key, raw) {
      final leaving = _parseEntry(raw as Map<String, dynamic>);
      final existing = _state[key];
      if (existing == null) return;
      for (final meta in leaving.metas) {
        existing.removeMeta(meta.phxRef);
      }
      if (existing.isEmpty) _state.remove(key);
    });
  }

  PresenceEntry _parseEntry(Map<String, dynamic> raw) {
    final rawMetas = raw['metas'] as List<dynamic>? ?? [];
    final metas = rawMetas.map((m) {
      final map = m as Map<String, dynamic>;
      return PresenceMeta(
        phxRef: map['phx_ref'] as String,
        data: Map<String, dynamic>.from(map)..remove('phx_ref'),
      );
    }).toList();
    return PresenceEntry(metas: metas);
  }
}
