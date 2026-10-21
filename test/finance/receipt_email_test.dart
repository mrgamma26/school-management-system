import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/finance/data/receipt_email_service.dart';
import 'package:school_management_app/features/finance/domain/models/payment_receipt.dart';
import 'package:school_management_app/features/finance/domain/receipt_email.dart';
import 'package:school_management_app/features/finance/presentation/widgets/receipt_card.dart';
import 'package:school_management_app/features/settings/domain/school_settings.dart';
import 'package:school_management_app/features/settings/presentation/settings_providers.dart';

final _receipt = PaymentReceiptData(
  receiptNumber: 'RCP-0042',
  paymentId: 'p1',
  studentName: 'Ada Banda',
  className: 'Form 2A',
  feeType: 'Tuition',
  paymentDate: DateTime(2026, 10, 19),
  amount: 50000,
  method: 'MOBILE_MONEY',
  reference: 'SECRET-REF-123',
  previousBalance: 80000,
  remainingBalance: 30000,
);

const _mary = ReceiptRecipient(
  guardianId: 'g1',
  name: 'Mary Banda',
  email: 'mary@example.test',
  relationship: 'Mother',
);
const _john = ReceiptRecipient(
  guardianId: 'g2',
  name: 'John Banda',
  email: ' john@example.test ',
  relationship: 'Father',
);
const _noEmail = ReceiptRecipient(guardianId: 'g3', name: 'Uncle Pete');
const _badEmail = ReceiptRecipient(
  guardianId: 'g4',
  name: 'Aunt Sue',
  email: 'not-an-email',
);

void main() {
  group('message builder', () {
    test('subject carries the receipt number', () {
      expect(receiptEmailSubject(_receipt), 'Payment receipt RCP-0042');
    });

    test('body has the receipt facts and nothing more', () {
      final body = buildReceiptEmailMessage(
        schoolName: ' Mai Halima School ',
        receipt: _receipt,
      );
      expect(body, contains('Mai Halima School'));
      expect(body, contains('Receipt number: RCP-0042'));
      expect(body, contains('Student: Ada Banda'));
      expect(body, contains('Amount received: MWK 50,000.00'));
      expect(body, contains('Payment date: 19 Oct 2026'));
      expect(body, contains('Method: MOBILE MONEY'));
      expect(body, contains('Remaining balance: MWK 30,000.00'));
      expect(body, isNot(contains('SECRET-REF-123')));
      expect(body, isNot(contains('Reference')));
    });

    test('blank school name falls back to a neutral label', () {
      final body = buildReceiptEmailMessage(schoolName: '  ', receipt: _receipt);
      expect(body, startsWith('Payment receipt from School'));
    });
  });

  group('guardian selection', () {
    final all = [_mary, _noEmail, _john, _badEmail, _mary];

    test('only guardians with a usable email, each once', () {
      expect(recipientsWithEmail(all).map((g) => g.guardianId), ['g1', 'g2']);
    });

    test('default selection is every guardian with an email', () {
      expect(defaultRecipientSelection(all), {'g1', 'g2'});
    });

    test('selected recipients ignore unknown ids and guardians without email', () {
      expect(
        selectedRecipients(all, {'g2', 'g3', 'nope'}).map((g) => g.guardianId),
        ['g2'],
      );
      expect(selectedRecipients(all, <String>{}), isEmpty);
    });

    test('note explains why nobody can be emailed', () {
      expect(noRecipientNote(const []), contains('No guardian is linked'));
      expect(
        noRecipientNote([_noEmail, _badEmail]),
        contains('No linked guardian has an email'),
      );
      expect(noRecipientNote([_noEmail, _mary]), isNull);
    });

    test('email validation', () {
      expect(isUsableEmail('a@b.co'), isTrue);
      expect(isUsableEmail(' a@b.co '), isTrue);
      expect(isUsableEmail(''), isFalse);
      expect(isUsableEmail(null), isFalse);
      expect(isUsableEmail('a@b'), isFalse);
    });
  });

  test('outcome message reports sent and failed guardians', () {
    expect(
      receiptEmailOutcomeMessage(const ReceiptEmailResult(sent: [_mary, _john])),
      'Receipt queued for email to 2 guardians.',
    );
    expect(
      receiptEmailOutcomeMessage(
        const ReceiptEmailResult(sent: [_mary], failed: {_john: 'x'}),
      ),
      'Receipt queued for email to 1 guardian. Could not send to John Banda.',
    );
  });

  group('receipt card', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<ReceiptRecipient> guardians,
      ReceiptEmailSender? sender,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolBrandingProvider.overrideWith(
              (ref) async => const SchoolBranding(schoolName: 'Test School'),
            ),
            receiptRecipientsProvider('s1').overrideWith((ref) async => guardians),
            if (sender != null)
              receiptEmailSenderProvider.overrideWithValue(sender),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReceiptCard(
                  receipt: _receipt,
                  studentId: 's1',
                  onDone: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is disabled with a note when no guardian has an email', (
      tester,
    ) async {
      await pump(tester, guardians: [_noEmail]);
      expect(
        find.textContaining('No linked guardian has an email address'),
        findsOneWidget,
      );
      await tester.tap(find.text('Email receipt'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Send to 1 guardian'), findsNothing);
    });

    testWidgets('confirms recipients then sends one send per chosen guardian', (
      tester,
    ) async {
      List<ReceiptRecipient>? sentTo;
      await pump(
        tester,
        guardians: [_mary, _john, _noEmail],
        sender:
            ({
              required PaymentReceiptData receipt,
              required String schoolName,
              required List<ReceiptRecipient> recipients,
            }) async {
              sentTo = recipients;
              expect(schoolName, 'Test School');
              return ReceiptEmailResult(sent: recipients);
            },
      );
      await tester.tap(find.text('Email receipt'));
      await tester.pumpAndSettle();

      // Both guardians with an email are ticked; the one without is not.
      expect(find.text('Send to 2 guardians'), findsOneWidget);
      expect(find.textContaining('mary@example.test'), findsWidgets);
      expect(find.text('No email address on file'), findsOneWidget);

      // Untick John.
      await tester.tap(find.byKey(const ValueKey('receipt-guardian-g2')));
      await tester.pumpAndSettle();
      expect(find.text('Send to 1 guardian'), findsOneWidget);

      await tester.tap(find.text('Send to 1 guardian'));
      await tester.pumpAndSettle();
      expect(sentTo!.map((g) => g.guardianId), ['g1']);
      expect(
        find.text('Receipt queued for email to 1 guardian.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the dialog sends nothing', (tester) async {
      var calls = 0;
      await pump(
        tester,
        guardians: [_mary],
        sender:
            ({
              required PaymentReceiptData receipt,
              required String schoolName,
              required List<ReceiptRecipient> recipients,
            }) async {
              calls++;
              return ReceiptEmailResult(sent: recipients);
            },
      );
      await tester.tap(find.text('Email receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });
  });
}
