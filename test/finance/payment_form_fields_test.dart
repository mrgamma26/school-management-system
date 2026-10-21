import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/finance/domain/models/fee_structure.dart';
import 'package:school_management_app/features/finance/domain/models/payment.dart';
import 'package:school_management_app/features/finance/presentation/widgets/payment_form_fields.dart';

const _tuition = FeeStructure(
  feeStructureId: 'f1',
  academicYearId: 'y1',
  feeType: 'Term 2 tuition',
  amount: 150000,
);
const _levy = FeeStructure(
  feeStructureId: 'f2',
  academicYearId: 'y1',
  feeType: 'Development levy',
  amount: 30000,
);

Widget host(
  GlobalKey<PaymentFormFieldsState> key, {
  FeeStructure? initial,
  ValueChanged<PaymentFormSnapshot>? onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PaymentFormFields(
          key: key,
          fees: const [_tuition, _levy],
          initialFee: initial,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

void main() {
  test('deposit slip files enforce type and 5 MB limit', () {
    expect(depositSlipMimeTypeForName('proof.JPG'), 'image/jpeg');
    expect(depositSlipMimeTypeForName('proof.pdf'), 'application/pdf');
    expect(depositSlipMimeTypeForName('proof.exe'), isNull);
    expect(isDepositSlipSizeAllowed(1), isTrue);
    expect(isDepositSlipSizeAllowed(maxDepositSlipBytes), isTrue);
    expect(isDepositSlipSizeAllowed(maxDepositSlipBytes + 1), isFalse);
  });
  testWidgets('prefills the amount from the initial fee and builds a request', (
    tester,
  ) async {
    final key = GlobalKey<PaymentFormFieldsState>();
    PaymentFormSnapshot? last;
    await tester.pumpWidget(
      host(key, initial: _tuition, onChanged: (s) => last = s),
    );
    await tester.pumpAndSettle();

    expect(last?.fee, _tuition);
    expect(last?.amount, 150000);

    final request = key.currentState!.validate();
    expect(request, isNotNull);
    expect(request!.fee, _tuition);
    expect(request.amount, 150000);
    expect(request.method, 'CASH');
    expect(request.channelId, isNull);
  });

  testWidgets('rejects submission without a fee', (tester) async {
    final key = GlobalKey<PaymentFormFieldsState>();
    await tester.pumpWidget(host(key));
    await tester.pumpAndSettle();

    expect(key.currentState!.validate(), isNull);
    await tester.pump();
    expect(find.text('Select a fee type.'), findsWidgets);
  });

  testWidgets('rejects a zero or empty amount', (tester) async {
    final key = GlobalKey<PaymentFormFieldsState>();
    await tester.pumpWidget(host(key, initial: _levy));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.pump();
    expect(key.currentState!.validate(), isNull);
    await tester.pump();
    expect(find.text('Enter a valid positive amount.'), findsOneWidget);
  });

  testWidgets('accepts an amount above the selected fee as account credit', (
    tester,
  ) async {
    final key = GlobalKey<PaymentFormFieldsState>();
    await tester.pumpWidget(host(key, initial: _levy));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '45000');
    await tester.pump();
    final request = key.currentState!.validate();

    expect(request, isNotNull);
    expect(request!.amount, 45000);
  });

  test('deposit is a supported payment method', () {
    expect(kPaymentMethods, contains('DEPOSIT'));
  });
}
