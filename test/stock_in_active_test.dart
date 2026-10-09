import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kgh_admin_app/modules/order/controller/order_controller.dart';
import 'package:kgh_admin_app/modules/order/model/delivery_models.dart';
import 'package:kgh_admin_app/modules/stock_in/controller/stock_in_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late StockInController sc;

  final listDate = DateTime(2026, 9, 28);
  final oldDate = DateTime(2026, 8, 29);

  Future<int> stockOf(String id) async =>
      (await db.collection('products').doc(id).get()).data()!['stock'];

  Future<void> stockIn(String id, String productId, int qty, DateTime date,
          {String source = 'Supplier', bool? active}) =>
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
        'active': ?active,
      });

  setUp(() async {
    db = FakeFirebaseFirestore();
    sc = StockInController(db: db);
    await db.collection('products').doc('A').set({'name': 'A', 'stock': 10});
    await db.collection('products').doc('B').set({'name': 'B', 'stock': 10});
    // Saved before the active flag existed: counts as active.
    await stockIn('s1', 'A', 3, listDate);
    await stockIn('s2', 'B', 2, listDate);
    await stockIn('s3', 'A', 1, oldDate);
    await sc.fetchEntries(force: true);
  });

  test('entries without the flag are active', () {
    expect(sc.entries.every((e) => e.active), isTrue);
  });

  test('switching a list off takes its pieces out of stock, on puts them back',
      () async {
    await sc.setGroupActive(listDate, 'Supplier', false);
    expect(await stockOf('A'), 7);
    expect(await stockOf('B'), 8);
    expect((await db.collection('stock_ins').doc('s1').get())['active'], false);
    // Another list of the same product is untouched.
    expect(sc.entries.firstWhere((e) => e.id == 's3').active, isTrue);

    await sc.setGroupActive(listDate, 'Supplier', true);
    expect(await stockOf('A'), 10);
    expect(await stockOf('B'), 10);
  });

  test('switching off twice changes the stock once', () async {
    await sc.setGroupActive(listDate, 'Supplier', false);
    await sc.setGroupActive(listDate, 'Supplier', false);
    expect(await stockOf('A'), 7);
  });

  test('a list already switched elsewhere is not counted twice', () async {
    // Another admin switched it off; this screen still thinks it is on.
    await db.collection('stock_ins').doc('s1').update({'active': false});
    await sc.setGroupActive(listDate, 'Supplier', false);
    expect(await stockOf('A'), 10);
    expect(await stockOf('B'), 8);
  });

  test('a deleted product does not stop the list from switching', () async {
    await stockIn('s4', 'GONE', 5, listDate);
    await sc.fetchEntries(force: true);
    await sc.setGroupActive(listDate, 'Supplier', false);
    expect(await stockOf('A'), 7);
    expect((await db.collection('stock_ins').doc('s4').get())['active'], false);
  });

  test('totals leave out inactive lists', () async {
    expect(sc.totalQuantity, 6);
    await sc.setGroupActive(listDate, 'Supplier', false);
    expect(sc.totalQuantity, 1);
    expect(sc.totalPurchaseValue, 100);
    expect(sc.hasInactiveFiltered, isTrue);
    expect(sc.filteredGroups.firstWhere((g) => g.date == listDate).active,
        isFalse);
  });

  test('deleting only the records keeps the stock', () async {
    await sc.deleteGroup(oldDate, 'Supplier', adjustStock: false);
    expect((await db.collection('stock_ins').doc('s3').get()).exists, isFalse);
    expect(await stockOf('A'), 10);
    expect(sc.entries.any((e) => e.id == 's3'), isFalse);
  });

  test('deleting with stock takes the active pieces out', () async {
    await sc.deleteGroup(listDate, 'Supplier', adjustStock: true);
    expect(await stockOf('A'), 7);
    expect(await stockOf('B'), 8);
    expect((await db.collection('stock_ins').get()).docs.length, 1);
  });

  test('deleting an inactive list never touches the stock', () async {
    await sc.setGroupActive(listDate, 'Supplier', false);
    await sc.deleteGroup(listDate, 'Supplier', adjustStock: true);
    expect(await stockOf('A'), 7);
    expect(await stockOf('B'), 8);
  });

  test('editing, deleting or adding inside an inactive list leaves stock alone',
      () async {
    await sc.setGroupActive(listDate, 'Supplier', false);
    final s1 = sc.entries.firstWhere((e) => e.id == 's1');

    await sc.updateEntry(
      id: 's1',
      productId: 'A',
      productName: 'A',
      quantity: 9,
      unitPrice: 100,
      source: 'Supplier',
      date: s1.date,
    );
    expect(await stockOf('A'), 7);
    expect(sc.entries.firstWhere((e) => e.id == 's1').active, isFalse);

    await sc.addStockIn(
      productId: 'B',
      productName: 'B',
      quantity: 4,
      source: 'Supplier',
      date: listDate,
      active: false,
    );
    expect(await stockOf('B'), 8);

    await sc.deleteEntry('s2');
    expect(await stockOf('B'), 8);
  });

  test('cancelling an order whose return list is inactive keeps stock right',
      () async {
    final oc = OrderController(db: db);
    await db.collection('users').doc('u1').set({'totalDue': 0});
    await db.collection('orders').doc('o1').set({
      'status': 'approved',
      'userId': 'u1',
      'shopName': 'Shop',
      'totalAmount': 1000,
      'paidAmount': 0,
      'createdAt': Timestamp.now(),
      'items': [
        {'productId': 'A', 'productName': 'A', 'quantity': 2, 'pricePerUnit': 500, 'totalPrice': 1000},
      ],
    });
    await oc.completeDelivery(
      orderId: 'o1',
      expectAlreadyDelivered: false,
      deliveryDate: DateTime(2026, 10, 1),
      returnLines: const [
        ReturnLine(productId: 'A', productName: 'A', quantity: 1, unitPrice: 200),
      ],
    );
    expect(await stockOf('A'), 9); // −2 sold, +1 returned

    await sc.fetchEntries(force: true);
    await sc.setGroupActive(DateTime(2026, 10, 1), 'Shop', false);
    expect(await stockOf('A'), 8);

    await oc.updateOrderStatus('o1', 'cancelled');
    expect(await stockOf('A'), 10); // the inactive return is not taken out again
  });
}
