// tests
// ignore_for_file: prefer_const_constructors

import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:phoenix_socket_client/src/phoenix_presence.dart';
import 'package:test/test.dart';

PhoenixMessage _presenceState(Map<String, dynamic> payload) => PhoenixMessage(
  topic: 'room:lobby',
  event: 'presence_state',
  payload: payload,
);

PhoenixMessage _presenceDiff(Map<String, dynamic> payload) => PhoenixMessage(
  topic: 'room:lobby',
  event: 'presence_diff',
  payload: payload,
);

void main() {
  late PhoenixPresence presence;

  setUp(() => presence = PhoenixPresence());

  group('presence_state', () {
    test('builds initial state from presence_state', () {
      presence.handleEvent(
        _presenceState({
          'user1': {
            'metas': [
              {'phx_ref': 'abc', 'online_at': '2024-01-01'},
            ],
          },
          'user2': {
            'metas': [
              {'phx_ref': 'def'},
            ],
          },
        }),
      );

      expect(presence.list.keys, containsAll(['user1', 'user2']));
      expect(presence.metasFor('user1').first.phxRef, 'abc');
      expect(
        presence.metasFor('user1').first.data,
        {'online_at': '2024-01-01'},
      );
    });

    test('replaces existing state on second presence_state', () {
      presence
        ..handleEvent(
          _presenceState({
            'user1': {
              'metas': [
                {'phx_ref': 'old'},
              ],
            },
          }),
        )
        ..handleEvent(
          _presenceState({
            'user2': {
              'metas': [
                {'phx_ref': 'new'},
              ],
            },
          }),
        );

      expect(presence.list.containsKey('user1'), isFalse);
      expect(presence.list.containsKey('user2'), isTrue);
    });
  });

  group('presence_diff joins', () {
    test('adds new user on join diff', () {
      presence.handleEvent(
        _presenceDiff({
          'joins': {
            'user1': {
              'metas': [
                {'phx_ref': 'r1'},
              ],
            },
          },
          'leaves': <String, dynamic>{},
        }),
      );

      expect(presence.metasFor('user1'), hasLength(1));
    });

    test('appends meta for existing user joining second device', () {
      presence
        ..handleEvent(
          _presenceState({
            'user1': {
              'metas': [
                {'phx_ref': 'r1'},
              ],
            },
          }),
        )
        ..handleEvent(
          _presenceDiff({
            'joins': {
              'user1': {
                'metas': [
                  {'phx_ref': 'r2'},
                ],
              },
            },
            'leaves': <String, dynamic>{},
          }),
        );

      expect(presence.metasFor('user1'), hasLength(2));
    });
  });

  group('presence_diff leaves', () {
    test('removes meta on leave diff', () {
      presence
        ..handleEvent(
          _presenceState({
            'user1': {
              'metas': [
                {'phx_ref': 'r1'},
                {'phx_ref': 'r2'},
              ],
            },
          }),
        )
        ..handleEvent(
          _presenceDiff({
            'joins': <String, dynamic>{},
            'leaves': {
              'user1': {
                'metas': [
                  {'phx_ref': 'r1'},
                ],
              },
            },
          }),
        );

      expect(presence.metasFor('user1'), hasLength(1));
      expect(presence.metasFor('user1').first.phxRef, 'r2');
    });

    test('removes user entirely when all metas leave', () {
      presence
        ..handleEvent(
          _presenceState({
            'user1': {
              'metas': [
                {'phx_ref': 'r1'},
              ],
            },
          }),
        )
        ..handleEvent(
          _presenceDiff({
            'joins': <String, dynamic>{},
            'leaves': {
              'user1': {
                'metas': [
                  {'phx_ref': 'r1'},
                ],
              },
            },
          }),
        );

      expect(presence.list.containsKey('user1'), isFalse);
    });

    test('silently ignores leave for unknown user', () {
      expect(
        () => presence.handleEvent(
          _presenceDiff({
            'joins': <String, dynamic>{},
            'leaves': {
              'ghost': {
                'metas': [
                  {'phx_ref': 'r1'},
                ],
              },
            },
          }),
        ),
        returnsNormally,
      );
    });
  });

  group('metasFor', () {
    test('returns empty list for unknown key', () {
      expect(presence.metasFor('nobody'), isEmpty);
    });
  });

  group('unknown events', () {
    test('ignores non-presence events silently', () {
      expect(
        () => presence.handleEvent(
          PhoenixMessage(
            topic: 'room:lobby',
            event: 'shout',
            payload: const {'body': 'hello'},
          ),
        ),
        returnsNormally,
      );
    });
  });
}
