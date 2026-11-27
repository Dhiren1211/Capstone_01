import 'package:flutter_test/flutter_test.dart';
import 'package:smartfind/utils/validators.dart';

void main() {
  group('email', () {
    test('accepts normal addresses', () {
      expect(AppValidators.email('student@ks.ac.kr'), isNull);
      expect(AppValidators.email('  first.last+tag@mail.example.com '), isNull);
    });

    test('rejects empty and malformed addresses', () {
      expect(AppValidators.email(''), isNotNull);
      expect(AppValidators.email(null), isNotNull);
      expect(AppValidators.email('student@'), isNotNull);
      expect(AppValidators.email('student.ks.ac.kr'), isNotNull);
    });
  });

  group('campusEmailError', () {
    const allowed = ['ks.ac.kr'];

    test('accepts the university domain and its sub-domains', () {
      expect(
        AppValidators.campusEmailError('a@ks.ac.kr', allowedDomains: allowed),
        isNull,
      );
      expect(
        AppValidators.campusEmailError(
          'a@mail.ks.ac.kr',
          allowedDomains: allowed,
        ),
        isNull,
      );
    });

    test('rejects other domains, including look-alikes', () {
      expect(
        AppValidators.campusEmailError('a@gmail.com', allowedDomains: allowed),
        isNotNull,
      );
      expect(
        AppValidators.campusEmailError(
          'a@evilks.ac.kr',
          allowedDomains: allowed,
        ),
        isNotNull,
      );
    });

    test('accepts everything when no domain is configured', () {
      expect(
        AppValidators.campusEmailError('a@gmail.com', allowedDomains: []),
        isNull,
      );
    });
  });

  group('password', () {
    test('needs at least 8 characters', () {
      expect(AppValidators.password('1234567'), isNotNull);
      expect(AppValidators.password('12345678'), isNull);
      expect(AppValidators.password(''), isNotNull);
    });

    test('confirmation has to match', () {
      expect(AppValidators.confirmPassword('abc12345', 'abc12345'), isNull);
      expect(AppValidators.confirmPassword('abc12346', 'abc12345'), isNotNull);
      expect(AppValidators.confirmPassword('', 'abc12345'), isNotNull);
    });
  });

  group('studentId', () {
    test('is exactly 10 digits', () {
      expect(AppValidators.studentId('2020123456'), isNull);
      expect(AppValidators.studentId('20201234'), isNotNull);
      expect(AppValidators.studentId('202012345'), isNotNull);
      expect(AppValidators.studentId('20201234567'), isNotNull);
      expect(AppValidators.studentId('2020ab3456'), isNotNull);
      expect(AppValidators.studentId(''), isNotNull);
    });
  });

  group('report form', () {
    test('item name length limits', () {
      expect(AppValidators.itemName('ab'), isNotNull);
      expect(AppValidators.itemName('Backpack'), isNull);
      expect(AppValidators.itemName('x' * AppValidators.maxItemName), isNull);
      expect(
        AppValidators.itemName('x' * (AppValidators.maxItemName + 1)),
        isNotNull,
      );
    });

    test('description length limits', () {
      expect(AppValidators.description('too short'), isNotNull);
      expect(AppValidators.description('a long enough description'), isNull);
      expect(
        AppValidators.description('x' * (AppValidators.maxDescription + 1)),
        isNotNull,
      );
    });

    test('contact info is an e-mail or a phone number', () {
      expect(AppValidators.contactInfo('me@ks.ac.kr'), isNull);
      expect(AppValidators.contactInfo('010-1234-5678'), isNull);
      expect(AppValidators.contactInfo('+82 10 1234 5678'), isNull);
      expect(AppValidators.contactInfo('call me maybe'), isNotNull);
      expect(AppValidators.contactInfo(''), isNotNull);
    });

    test('optional free text only has an upper limit', () {
      expect(AppValidators.optionalMax('', 10), isNull);
      expect(AppValidators.optionalMax(null, 10), isNull);
      expect(AppValidators.optionalMax('1234567890', 10), isNull);
      expect(AppValidators.optionalMax('12345678901', 10), isNotNull);
    });
  });
}
