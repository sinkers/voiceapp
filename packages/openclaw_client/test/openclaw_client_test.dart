import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openclaw_client/openclaw_client.dart';
import 'package:test/test.dart';

void main() {
  group('OpenClawClient.listAgents', () {
    test('returns agents from /models response', () async {
      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/models');
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'openclaw:main'},
                {'id': 'openclaw:alex'},
                {'id': 'gpt-4'},
              ],
            }),
            200,
          );
        }),
      );

      final agents = await client.listAgents();
      expect(agents.length, 2);
      expect(agents[0].id, 'openclaw:main');
      expect(agents[0].displayName, 'main');
      expect(agents[1].id, 'openclaw:alex');
      expect(agents[1].displayName, 'alex');
    });

    test('falls back to openclaw:main on non-200 response', () async {
      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        httpClient: MockClient((_) async => http.Response('{}', 503)),
      );

      final agents = await client.listAgents();
      expect(agents.length, 1);
      expect(agents[0].id, 'openclaw:main');
    });

    test('falls back to openclaw:main when no matching agents found',
        () async {
      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        httpClient: MockClient((_) async => http.Response(
              jsonEncode({
                'data': [
                  {'id': 'gpt-4'},
                  {'id': 'llama-3'},
                ],
              }),
              200,
            )),
      );

      final agents = await client.listAgents();
      expect(agents.length, 1);
      expect(agents[0].id, 'openclaw:main');
    });

    test('includes bearer token when token is set', () async {
      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        token: 'mytoken',
        httpClient: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer mytoken');
          return http.Response(
              jsonEncode({'data': []}), 200);
        }),
      );

      await client.listAgents();
    });
  });

  group('OpenClawClient.chatCompletion', () {
    test('returns content from choices', () async {
      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/chat/completions');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], 'openclaw:main');
          expect(body['stream'], isNull);
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'Hello world'},
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await client.chatCompletion(
        'openclaw:main',
        [OpenClawMessage.user('Hi')],
      );
      expect(result, 'Hello world');
    });

    test('sends session key header when provided', () async {
      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        httpClient: MockClient((request) async {
          expect(
              request.headers['x-openclaw-session-key'], 'test-session-id');
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'OK'},
                },
              ],
            }),
            200,
          );
        }),
      );

      await client.chatCompletion(
        'openclaw:main',
        [OpenClawMessage.user('Hi')],
        sessionKey: 'test-session-id',
      );
    });

    test('throws OpenClawException on non-200 response', () async {
      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        httpClient: MockClient((_) async => http.Response('Unauthorized', 401)),
      );

      expect(
        () => client.chatCompletion('openclaw:main', []),
        throwsA(isA<OpenClawException>()),
      );
    });
  });

  group('OpenClawClient.streamChatCompletion', () {
    test('yields text deltas from SSE stream', () async {
      final sseBody = [
        'data: ${jsonEncode({
              'choices': [
                {'delta': {'content': 'Hello'}}
              ]
            })}',
        'data: ${jsonEncode({
              'choices': [
                {'delta': {'content': ' world'}}
              ]
            })}',
        'data: [DONE]',
      ].join('\n');

      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['stream'], true);
          return http.Response(sseBody, 200);
        }),
      );

      final chunks = await client
          .streamChatCompletion('openclaw:main', [OpenClawMessage.user('Hi')])
          .toList();
      expect(chunks, ['Hello', ' world']);
    });

    test('stops at [DONE] sentinel', () async {
      final sseBody = [
        'data: ${jsonEncode({
              'choices': [
                {'delta': {'content': 'first'}}
              ]
            })}',
        'data: [DONE]',
        'data: ${jsonEncode({
              'choices': [
                {'delta': {'content': 'should not appear'}}
              ]
            })}',
      ].join('\n');

      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        httpClient: MockClient((_) async => http.Response(sseBody, 200)),
      );

      final chunks = await client
          .streamChatCompletion('openclaw:main', [])
          .toList();
      expect(chunks, ['first']);
    });

    test('throws OpenClawException on non-200 status', () async {
      final client = OpenClawClient(
        baseUrl: 'http://localhost:1234/v1',
        httpClient: MockClient(
            (_) async => http.Response('Internal Server Error', 500)),
      );

      expect(
        () => client
            .streamChatCompletion('openclaw:main', [])
            .toList(),
        throwsA(isA<OpenClawException>()),
      );
    });
  });

  group('OpenClawInstance', () {
    test('toJson / fromJson round-trip', () {
      final instance = OpenClawInstance(
        id: 'inst-1',
        name: 'Home Pi',
        baseUrl: 'http://10.0.0.1:18789/v1',
        token: 'secret',
        sessionId: 'sess-abc',
        elevenLabsVoiceId: '21m00Tcm4TlvDq8ikWAM',
        elevenLabsSpeed: 1.2,
      );

      final json = instance.toJson();
      final restored = OpenClawInstance.fromJson(json);

      expect(restored.id, instance.id);
      expect(restored.name, instance.name);
      expect(restored.baseUrl, instance.baseUrl);
      expect(restored.token, instance.token);
      expect(restored.sessionId, instance.sessionId);
      expect(restored.elevenLabsVoiceId, instance.elevenLabsVoiceId);
      expect(restored.elevenLabsSpeed, instance.elevenLabsSpeed);
    });

    test('fromJson generates sessionId when missing', () {
      final json = {
        'id': 'x',
        'name': 'test',
        'baseUrl': 'http://localhost/v1',
      };
      final instance = OpenClawInstance.fromJson(json);
      expect(instance.sessionId, isNotEmpty);
    });
  });

  group('SessionManager', () {
    test('newSessionId returns a non-empty string', () {
      final id = SessionManager.newSessionId();
      expect(id, isNotEmpty);
    });

    test('newSessionId returns unique values', () {
      final ids = List.generate(10, (_) => SessionManager.newSessionId());
      expect(ids.toSet().length, 10);
    });
  });
}
