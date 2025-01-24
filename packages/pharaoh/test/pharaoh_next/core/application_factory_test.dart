import 'package:pharaoh/pharaoh_next.dart';
import 'package:spookie/spookie.dart';

import 'application_factory_test.reflectable.dart';

class TestHttpController extends HTTPController {
  Future<Response> index() async {
    return response.ok('Hello World');
  }

  Future<Response> show(@query int userId) async {
    return response.ok('User $userId');
  }
}

void main() {
  initializeReflectable();

  group('ApplicationFactory', () {
    group('.buildControllerMethod', () {
      group('should return request handler', () {
        test('for method with no args', () async {
          final indexMethod = ControllerMethod((TestHttpController, #index));
          final handler = ApplicationFactory.buildControllerMethod(indexMethod);

          expect(handler, isA<RequestHandler>());

          await (await request(Pharaoh()..get('/', handler)))
              .get('/')
              .expectStatus(200)
              .expectBody('Hello World')
              .test();
        });

        test('for method with args', () async {
          final showMethod = ControllerMethod(
            (TestHttpController, #show),
            params: [ControllerMethodParam('userId', int, meta: query)],
          );

          final handler = ApplicationFactory.buildControllerMethod(showMethod);
          expect(handler, isA<RequestHandler>());

          await (await request(Pharaoh()..get('/test', handler)))
              .get('/test?userId=2345')
              .expectStatus(200)
              .expectBody('User 2345')
              .test();
        });
      });
    });
  });
}
