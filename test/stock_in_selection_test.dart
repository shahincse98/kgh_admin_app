import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kgh_admin_app/modules/stock_in/controller/stock_in_controller.dart';
import 'package:kgh_admin_app/modules/stock_in/view/stock_in_history_view.dart';

void main() {
  late FakeFirebaseFirestore db;
  late StockInController sc;

  Future<int> stockOf(String id) async =>
      (await db.collection('products').doc(id).get()).data()!['stock'];

  Future<List<String>> stockInIds() async =>
      (await db.collection('stock_ins').get()).docs.map((d) => d.id).toList()
        ..sort();

  Future<void> stockIn(
          String id, String productId, int qty, DateTime date, String source) =>
      db.collection('stock_ins').doc(id).set({
        'productId': productId,
        'productName': productId,
        'quantity': qty,
        'unitPrice': 100,
        'totalPrice': 100 * qty,
        'source': source,
        'note': '',
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(date),
      });

  Future<void> openPage(WidgetTester tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: StockInHistoryView()),
    );
    await tester.pumpAndSettle();
  }

  /// Lets the delete snackbar run out so no timer outlives the test.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    Get.testMode = true;
    db = FakeFirebaseFirestore();
    await db.collection('products').doc('A').set({'name': 'A', 'stock': 10});
    await db.collection('products').doc('B').set({'name': 'B', 'stock': 10});
    await stockIn('old1', 'A', 3, DateTime(2026, 8, 29), 'Supplier');
    await stockIn('old2', 'B', 2, DateTime(2026, 8, 20), 'Other');
    await stockIn('new1', 'A', 1, DateTime(2026, 9, 28), 'Supplier');
    sc = Get.put(StockInController(db: db));
  });

  tearDown(Get.reset);

  testWidgets('long press, mark another list, delete only the records',
      (tester) async {
    await openPage(tester);

    await tester.longPress(find.text('Other'));
    await tester.pump();
    expect(find.text('1 টি লিস্ট সিলেক্টেড'), findsOneWidget);

    // While marking, a tap marks instead of opening the list.
    await tester.tap(find.text('Supplier').last); // 29 Aug, the older one
    await tester.pump();
    expect(find.text('2 টি লিস্ট সিলেক্টেড'), findsOneWidget);

    await tester.tap(find.byTooltip('সিলেক্ট করা লিস্ট ডিলিট'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('শুধু রেকর্ড মুছুন'));
    await tester.pumpAndSettle();

    expect(await stockInIds(), ['new1']);
    expect(await stockOf('A'), 10);
    expect(await stockOf('B'), 10);
    // Back to the normal page once done.
    expect(find.byTooltip('লিস্ট সিলেক্ট করুন'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('select all within the date filter, delete with stock',
      (tester) async {
    sc.toDate.value = DateTime(2026, 8, 29);
    await openPage(tester);

    await tester.tap(find.byTooltip('লিস্ট সিলেক্ট করুন'));
    await tester.pump();
    await tester.tap(find.byTooltip('সব সিলেক্ট'));
    await tester.pump();
    expect(find.text('2 টি লিস্ট সিলেক্টেড'), findsOneWidget);

    await tester.tap(find.byTooltip('সিলেক্ট করা লিস্ট ডিলিট'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('স্টক থেকেও বাদ দিন'));
    await tester.pumpAndSettle();

    // The 28 Sep list was hidden by the filter, so it stays.
    expect(await stockInIds(), ['new1']);
    expect(await stockOf('A'), 7);
    expect(await stockOf('B'), 8);
    await finish(tester);
  });

  testWidgets('cancel leaves everything and the close button stops marking',
      (tester) async {
    await openPage(tester);

    await tester.longPress(find.text('Other'));
    await tester.pump();
    await tester.tap(find.byTooltip('সিলেক্ট করা লিস্ট ডিলিট'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('বাতিল'));
    await tester.pumpAndSettle();
    expect((await stockInIds()).length, 3);

    await tester.tap(find.byTooltip('বাতিল'));
    await tester.pump();
    expect(find.byTooltip('লিস্ট সিলেক্ট করুন'), findsOneWidget);
  });
}
