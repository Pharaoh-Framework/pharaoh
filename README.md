# Pharaoh 🏇

[![Dart CI](https://github.com/codekeyz/pharaoh/workflows/Dart/badge.svg)](https://github.com/codekeyz/pharaoh/actions/workflows/dart.yml)
[![Pub Version](https://img.shields.io/pub/v/pharaoh?color=green)](https://pub.dev/packages/pharaoh)
[![popularity](https://img.shields.io/pub/popularity/pharaoh?logo=dart)](https://pub.dev/packages/pharaoh/score)
[![likes](https://img.shields.io/pub/likes/pharaoh?logo=dart)](https://pub.dev/packages/pharaoh/score)
[![style: flutter lints](https://img.shields.io/badge/linter-dart__lints-blue)](https://pub.dev/packages/lints)

## Features

- Robust routing
- Focus on high performance
- Super-high test coverage
- HTTP helpers (redirection, caching, etc)

## Installing:

In your pubspec.yaml

```yaml
dependencies:
  pharaoh: ^0.0.1 # requires Dart => ^3.1.5
```

## Basic Usage:

```dart
import 'package:pharaoh/pharaoh.dart';

final app = Pharaoh();

void main() async {

  app.use(logRequests);

  app.get('/foo', (req, res) => res.ok("bar"));

  final guestRouter = app.router()
    ..get('/user', (req, res) => res.ok("Hello World"))
    ..post('/post', (req, res) => res.json({"mee": "moo"}))
    ..put('/put', (req, res) => res.json({"pookey": "reyrey"}));

  app.group('/guest', guestRouter);

  await app.listen(); // port => 3000
}

```

## Philosophy

The Pharaoh philosophy is to provide small, robust tooling for HTTP servers, making
it a great solution for single page applications, websites, hybrids, or public
HTTP APIs.

## Contributors ✨

The Pharaoh project welcomes all constructive contributions. Contributions take many forms,
from code for bug fixes and enhancements, to additions and fixes to documentation, additional
tests, triaging incoming pull requests and issues, and more!

### Running Tests

To run the test suite, first install the dependencies, then run `dart test`:

```console
$ dart pub get
$ dart test
```

## People

The original author of Pharaoh is [Chima Precious](https://github.com/codekeyz)

[List of all contributors](https://github.com/codekeyz/pharaoh/graphs/contributors)

## License

[MIT](LICENSE)
