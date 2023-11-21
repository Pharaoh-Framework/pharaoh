# supertest 🎌

I wrote this to work just like https://www.npmjs.com/package/supertest

## Installing:

In your pubspec.yaml

```yaml
dev_dependencies:
  supertest: ^1.0.0
```

## Basic Usage:

You can use `supertest` to test any framework or library that uses the Dart HttpServer underneath.

Your class just need to have a `handleRequest` method that accepts an `HttpRequest` type object.

Example testing of [Pharaoh](https://pub.dev/packages/pharaoh) using `supertest`

```dart
import 'package:pharaoh/pharaoh.dart';
import 'package:supertest/supertest.dart';

void main() async {

   test('should not override previous Content-Types', () async {
      final app = Pharaoh().get('/', (req, res) {
        return res
            .type(ContentType.parse('application/vnd.example+json'))
            .json({"hello": "world"});
      });

      await (await request<Pharaoh>(app))
          .get('/')
          .status(200)
          .contentType('application/vnd.example+json')
          .body('{"hello":"world"}')
          .test();
    });

}
```

## Tests

The cases in the `supertest_test.dart` are also used for automated testing. So if you want  
to contribute or just make sure that the package still works, simply run:

```shell
dart test
```
