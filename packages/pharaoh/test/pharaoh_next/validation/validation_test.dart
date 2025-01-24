import 'package:pharaoh/pharaoh_next.dart';
import 'package:spookie/spookie.dart';

import 'validation_test.reflectable.dart';

class TestDTO extends BaseDTO {
  String get username;

  String get lastname;

  int get age;
}

class TestSingleOptional extends BaseDTO {
  String get nationality;

  @ezOptional(String)
  String? get address;

  @ezOptional(String, defaultValue: 'Ghana')
  String get country;
}

class DTOTypeMismatch extends BaseDTO {
  @ezOptional(int)
  String? get name;
}

void main() {
  initializeReflectable();

  group('Validation', () {
    group('when `ezRequired`', () {
      test('when passed type as argument', () {
        final requiredValidator = ezRequired(String).validator.build();
        expect(requiredValidator(null), 'The field is required');
        expect(requiredValidator(24), 'The field must be a String type');
        expect(requiredValidator('Foo'), isNull);
      });

      test('when passed type through generics', () {
        final requiredValidator = ezRequired<int>().validator.build();
        expect(requiredValidator(null), 'The field is required');
        expect(requiredValidator('Hello'), 'The field must be a int type');
        expect(requiredValidator(24), isNull);
      });

      test('when mis-matched types', () {
        final requiredValidator = ezRequired<int>().validator.build();
        expect(requiredValidator(null), 'The field is required');
        expect(requiredValidator('Hello'), 'The field must be a int type');
        expect(requiredValidator(24), isNull);
      });
    });

    test('when `ezOptional`', () {
      final optionalValidator = ezOptional(String).validator.build();
      expect(optionalValidator(null), isNull);
      expect(optionalValidator(24), 'The field must be a String type');
      expect(optionalValidator('Foo'), isNull);
    });

    test('when `ezEmail`', () {
      final emailValidator = ezEmail().validator.build();
      expect(emailValidator('foo'), 'The field is not a valid email address');
      expect(emailValidator(24), 'The field must be a String type');
      expect(emailValidator('chima@yaroo.dev'), isNull);
    });

    test('when `ezMinLength`', () {
      final val1 = ezMinLength(4).validator.build();
      expect(val1('foo'), 'The field must be at least 4 characters long');
      expect(val1('foob'), isNull);
      expect(val1('foobd'), isNull);
    });

    test('when `ezMaxLength`', () {
      final val1 = ezMaxLength(10).validator.build();
      expect(val1('foobasdfkasdfasdf'),
          'The field must be at most 10 characters long');
      expect(val1('foobasdfk'), isNull);
    });

    test('when `ezDateTime`', () {
      var requiredValidator = ezDateTime().validator.build();
      final now = DateTime.now();
      expect(requiredValidator('foo'), 'The field must be a DateTime type');
      expect(requiredValidator(now), isNull);
      expect(requiredValidator(null), 'The field is required');

      requiredValidator = ezDateTime(optional: true).validator.build();
      expect(requiredValidator(null), isNull);
      expect(requiredValidator('df'), 'The field must be a DateTime type');
    });
  });

  group('when used in a class', () {
    final pharaoh = Pharaoh()
      ..onError((error, req, res) {
        final actualError = error.exception;
        if (actualError is RequestValidationError) {
          return res.json(actualError.errorBody, statusCode: 422);
        }

        return res.internalServerError(actualError.toString());
      });
    late Spookie appTester;

    setUpAll(() async => appTester = await request(pharaoh));

    test('when no metas', () async {
      final dto = TestDTO();
      final testData = {'username': 'Foo', 'lastname': 'Bar', 'age': 22};

      final app = pharaoh
        ..post('/', (req, res) {
          dto.validate(req);
          return res.json({
            'firstname': dto.username,
            'lastname': dto.lastname,
            'age': dto.age
          });
        });

      await appTester
          .post('/', {})
          .expectStatus(422)
          .expectJsonBody({
            'location': 'body',
            'errors': [
              'username: The field is required',
              'lastname: The field is required',
              'age: The field is required'
            ]
          })
          .test();

      await (await request(app))
          .post('/', testData)
          .expectStatus(200)
          .expectJsonBody(
              {'firstname': 'Foo', 'lastname': 'Bar', 'age': 22}).test();
    });

    test('when single property optional', () async {
      final dto = TestSingleOptional();

      final app = pharaoh
        ..post('/optional', (req, res) {
          dto.validate(req);

          return res.json({
            'nationality': dto.nationality,
            'address': dto.address,
            'country': dto.country
          });
        });

      await (await request(app))
          .post('/optional', {})
          .expectStatus(422)
          .expectJsonBody({
            'location': 'body',
            'errors': ['nationality: The field is required']
          })
          .test();

      await (await request(app))
          .post('/optional', {'nationality': 'Ghanaian'})
          .expectStatus(200)
          .expectJsonBody(
              {'nationality': 'Ghanaian', 'address': null, 'country': 'Ghana'})
          .test();

      await (await request(app))
          .post('/optional', {'nationality': 'Ghanaian', 'address': 344})
          .expectStatus(422)
          .expectJsonBody({
            'location': 'body',
            'errors': ['address: The field must be a String type']
          })
          .test();

      await (await request(app))
          .post('/optional',
              {'nationality': 'Ghanaian', 'address': 'Terminalia Street'})
          .expectStatus(200)
          .expectJsonBody({
            'nationality': 'Ghanaian',
            'address': 'Terminalia Street',
            'country': 'Ghana'
          })
          .test();
    });

    test('when type mismatch', () async {
      final dto = DTOTypeMismatch();

      pharaoh.post('/type-mismatch', (req, res) {
        dto.validate(req);
        return res.ok('Foo Bar');
      });

      await (await request(pharaoh))
          .post('/type-mismatch', {'name': 'Chima'})
          .expectStatus(500)
          .expectJsonBody({
            'error':
                'Invalid argument(s): Type Mismatch between ezOptional(int) & DTOTypeMismatch class property name->(String)'
          })
          .test();
    });
  });
}
