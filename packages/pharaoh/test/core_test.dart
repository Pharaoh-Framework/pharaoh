import 'package:pharaoh/pharaoh.dart';
import 'package:spookie/spookie.dart';

void main() {
  group('pharaoh_core', () {
    test('should initialize without onError callback', () async {
      final app = Pharaoh()
        ..get('/', (req, res) => throw ArgumentError('Some weird error'));

      await (await request(app))
          .get('/')
          .expectStatus(500)
          .expectJsonBody(allOf(
            containsPair('error', 'Invalid argument(s): Some weird error'),
            contains('trace'),
          ))
          .test();
    });

    test('should use onError callback if provided', () async {
      final app = Pharaoh()
        ..use((req, res, next) => next(res.header('foo', 'bar')))
        ..onError((_, req, res) =>
            res.status(500).withBody('An error occurred just now'))
        ..get('/', (req, res) => throw ArgumentError('Some weird error'));

      await (await request(app))
          .get('/')
          .expectStatus(500)
          .expectBody('An error occurred just now')
          .expectHeader('foo', 'bar')
          .test();
    });
  });
}
