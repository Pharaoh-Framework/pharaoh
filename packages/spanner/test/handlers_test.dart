import 'package:pharaoh/pharaoh.dart';
import 'package:spookie/spookie.dart';

void main() {
  test('should execute request', () async {
    final app = Pharaoh()
      ..get('/users/<userId>', (req, res) => res.json(req.params))
      ..get('/home/chima', (req, res) => res.ok('Okay 🚀'))
      ..use((req, res, next) => next());

    await (await request(app))
        .get('/users/234')
        .expectStatus(200)
        .expectBody('{"userId":"234"}')
        .test();

    await (await request(app))
        .get('/home/chima')
        .expectStatus(200)
        .expectBody('Okay 🚀')
        .test();
  });
}
