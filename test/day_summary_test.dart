import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kgh_admin_app/modules/sales/model/day_summary.dart';

void main() {
  final day = DateTime(2026, 9, 21);
  Timestamp at(int hour, {int dayOffset = 0}) =>
      Timestamp.fromDate(DateTime(2026, 9, 21 + dayOffset, hour));

  Map<String, dynamic> order({
    String user = 'u1',
    num total = 0,
    num previousDue = 0,
    List<Map<String, dynamic>> payments = const [],
    int hour = 10,
    num deduction = 0,
    num returnAmount = 0,
    num discount = 0,
  }) =>
      {
        'userId': user,
        'totalAmount': total,
        'previousDue': previousDue,
        'deductionAmount': deduction,
        'returnAmount': returnAmount,
        'discountAmount': discount,
        'payments': payments,
        'deliveredAt': at(hour),
        'items': const [],
      };

  DaySummary run(List<Map<String, dynamic>> orders,
          {List<Map<String, dynamic>> later = const [],
          List<Map<String, dynamic>> expenses = const [],
          List<Map<String, dynamic>> deposits = const [],
          List<Map<String, dynamic>> bank = const [],
          String? srId}) =>
      computeDaySummary(
        orders: orders,
        paymentOnlyOrders: later,
        expenses: expenses,
        deposits: deposits,
        bankInstallments: bank,
        productCost: const {},
        from: day,
        to: day,
        srId: srId,
      );

  test('user example: 12000 collected − 500 expenses − 11000 deposit = SR has 500', () {
    final s = run(
      [
        order(total: 12000, payments: [
          {'amount': 12000, 'method': 'SR হাতে'},
        ]),
      ],
      expenses: [
        {'amount': 300, 'category': 'কুরিয়ার খরচ'},
        {'amount': 200, 'category': 'যাতায়াত খরচ'},
      ],
      deposits: [
        {'amount': 11000, 'method': 'ব্যাংক'},
      ],
    );
    expect(s.srHand, 12000);
    expect(s.expenses, 500);
    expect(s.deposits, 11000);
    expect(s.srBalance, 500); // SR owes 500
    expect(s.expenseByCategory, {'কুরিয়ার খরচ': 300, 'যাতায়াত খরচ': 200});
  });

  group('bank deposit (কিস্তি + সঞ্চয়)', () {
    Map<String, dynamic> dep({num inst = 0, num savings = 0, String srId = ''}) => {
          'amount': inst + savings,
          'installment': inst,
          'savings': savings,
          if (srId.isNotEmpty) 'srId': srId,
        };

    test('800 instalment + 100 savings leaves profit alone and cuts SR cash by 900', () {
      final s = run(
        [
          order(total: 5000, payments: [
            {'amount': 5000, 'method': 'SR হাতে'},
          ]),
        ],
        bank: [dep(inst: 800, savings: 100, srId: 'sr1')],
      );
      expect(s.bankPaid, 900);
      expect(s.bankInstallment, 800);
      expect(s.bankSavings, 100);
      expect(s.bankFromSr, 900);
      expect(s.srBalance, 5000 - 900);
      // Repaying a loan and saving are not costs.
      expect(s.netProfit, s.grossProfit);
    });

    test('paid from bKash: the loan falls but no SR cash is touched', () {
      final s = run(
        [
          order(total: 5000, payments: [
            {'amount': 5000, 'method': 'SR হাতে'},
          ]),
        ],
        bank: [dep(inst: 800, savings: 100)],
      );
      expect(s.bankPaid, 900);
      expect(s.bankFromSr, 0);
      expect(s.srBalance, 5000);
    });

    test('older entry without a savings field counts fully as instalment', () {
      final s = run([], bank: [
        {'amount': 800, 'srId': 'sr1'},
      ]);
      expect(s.bankInstallment, 800);
      expect(s.bankSavings, 0);
      expect(s.bankPaid, 800);
    });

    test("one SR's account ignores another SR's deposit", () {
      final s = run([], srId: 'sr1', bank: [
        dep(inst: 800, savings: 100, srId: 'sr1'),
        dep(inst: 500, srId: 'sr2'),
      ]);
      expect(s.bankPaid, 900);
      expect(s.bankFromSr, 900);
    });
  });

  test('SR deposits more than he holds → negative balance (SR is owed)', () {
    final s = run(
      [
        order(total: 1000, payments: [
          {'amount': 1000, 'method': 'SR হাতে'},
        ]),
      ],
      expenses: [
        {'amount': 100},
      ],
      deposits: [
        {'amount': 1000},
      ],
    );
    expect(s.srBalance, -100);
  });

  test('bKash / Nagad reach the business directly, not the SR', () {
    final s = run([
      order(total: 3000, payments: [
        {'amount': 1000, 'method': 'SR হাতে'},
        {'amount': 1000, 'method': 'বিকাশ'},
        {'amount': 1000, 'method': 'নগদ অ্যাপ'},
      ]),
    ]);
    expect(s.srHand, 1000);
    expect(s.direct, 2000);
    expect(s.adjustments, 0);
    expect(s.srBalance, 1000);
  });

  test('old order without payments list: replace/return credit is not cash', () {
    final o = order(total: 1000, deduction: 100, returnAmount: 200)
      ..remove('payments')
      ..['paidAmount'] = 1000;
    final s = run([o]);
    expect(s.srHand, 700);
    expect(s.netSales, 700);
    expect(s.newDue, 0);
  });

  test('shop served twice in a day: due chains from the first order', () {
    final s = run([
      // listed newest first, as the query returns them
      order(total: 500, previousDue: 1300, hour: 15, payments: [
        {'amount': 200, 'method': 'SR হাতে'},
      ]),
      order(total: 1000, previousDue: 1000, hour: 9, payments: [
        {'amount': 700, 'method': 'SR হাতে'},
      ]),
    ]);
    expect(s.previousDue, 1000);
    expect(s.newDue, 1000 + 1000 - 700 + 500 - 200);
  });

  test('payment taken today for an order delivered earlier counts today only', () {
    final earlier = {
      'userId': 'u2',
      'totalAmount': 2000,
      'deliveredAt': at(10, dayOffset: -3),
      'payments': [
        {'amount': 500, 'method': 'SR হাতে', 'date': at(0, dayOffset: -3)},
        {'amount': 800, 'method': 'SR হাতে', 'date': at(0)},
      ],
    };
    final s = run(const [], later: [earlier]);
    expect(s.srHand, 800);
    expect(s.laterCollections, 800);
    expect(s.netSales, 0); // the sale belongs to its own day
  });

  test('a re-open payment dated another day is not counted on the delivery day', () {
    final s = run([
      order(total: 1000, payments: [
        {'amount': 600, 'method': 'SR হাতে', 'date': at(0)},
        {'amount': 400, 'method': 'SR হাতে', 'date': at(0, dayOffset: 2)},
      ]),
    ]);
    expect(s.srHand, 600);
  });

  test('expense page type codes map to the same categories', () {
    expect(expenseCategoryOf({'type': 'rent'}), 'ভাড়া');
    expect(expenseCategoryOf({'type': 'salary'}), 'কর্মচারী বেতন');
    expect(expenseCategoryOf({'category': 'কুরিয়ার খরচ', 'type': 'misc'}), 'কুরিয়ার খরচ');
    expect(expenseCategoryOf({}), 'অন্যান্য');
    expect(expenseTypeOf('ভাড়া'), 'rent');
    expect(expenseTypeOf('কুরিয়ার খরচ'), 'misc');
  });

  test("SR account counts only that SR's collections", () {
    final mine = order(total: 1000, payments: [
      {'amount': 600, 'method': 'SR হাতে', 'srId': 'sr1'},
      {'amount': 400, 'method': 'SR হাতে', 'srId': 'sr2'},
    ]);
    final legacyMine = order(user: 'u2', total: 500, payments: [
      {'amount': 500, 'method': 'SR হাতে'},
    ])
      ..['deliveredBySrId'] = 'sr1';
    final legacyOther = order(user: 'u3', total: 300, payments: [
      {'amount': 300, 'method': 'SR হাতে'},
    ])
      ..['deliveryAssignedSrId'] = 'sr2';
    final s = computeDaySummary(
      orders: [mine, legacyMine, legacyOther],
      expenses: const [
        {'amount': 100},
      ],
      deposits: const [
        {'amount': 800},
      ],
      productCost: const {},
      from: day,
      to: day,
      srId: 'sr1',
    );
    expect(s.srHand, 1100);
    expect(s.srBalance, 1100 - 100 - 800);
  });

  test('a replace credit larger than the order is not turned into profit', () {
    // cable ৳100 (cost ৳80); a defective AirPods bought earlier for ৳330 is
    // credited in full and goes back to the supplier (cost ৳290).
    final o = order(user: 'u3', total: 100, previousDue: 1000, deduction: 330)
      ..['items'] = [
        {'productId': 'cable', 'quantity': 1, 'totalPrice': 100, 'purchasePrice': 80},
      ]
      ..['replaceItems'] = [
        {'productId': 'airpods', 'quantity': 1, 'resolutionType': 'money_deduct', 'deductionAmount': 330},
      ];
    final s = computeDaySummary(
      orders: [o],
      expenses: const [],
      deposits: const [],
      productCost: const {'airpods': 290, 'cable': 80},
      from: day,
      to: day,
    );
    expect(s.netSales, -230);
    expect(s.recovered, 290);
    expect(s.grossProfit, -20); // was +210 when the sale was cut off at zero
    // the extra credit came off the shop's due
    expect(s.newDue, 1000 - 230);
  });
}
