import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kgh_admin_app/modules/order/controller/order_controller.dart';
import 'package:kgh_admin_app/modules/order/model/delivery_models.dart';
import 'package:kgh_admin_app/modules/order/model/order_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late OrderController oc;

  Future<void> product(String id, {int stock = 10}) => db
      .collection('products')
      .doc(id)
      .set({'name': id, 'stock': stock, 'replaceCount': 0});

  Future<Map<String, dynamic>> doc(String col, String id) async =>
      (await db.collection(col).doc(id).get()).data()!;

  Future<int> stockOf(String id) async => (await doc('products', id))['stock'];
  Future<int> replaceCountOf(String id) async =>
      (await doc('products', id))['replaceCount'];
  Future<int> dueOf(String id) async => (await doc('users', id))['totalDue'];

  setUp(() async {
    db = FakeFirebaseFirestore();
    oc = OrderController(db: db);
    for (final p in ['A', 'B', 'C', 'D', 'E']) {
      await product(p);
    }
    await db.collection('users').doc('u1').set({'totalDue': 500});
    await db.collection('orders').doc('o1').set({
      'status': 'approved',
      'userId': 'u1',
      'shopName': 'Shop',
      'shopPhone': '017',
      'shopAddress': 'Addr',
      'totalAmount': 1000,
      'paidAmount': 0,
      'createdAt': Timestamp.now(),
      'items': [
        {'productId': 'A', 'productName': 'A', 'quantity': 2, 'pricePerUnit': 500, 'totalPrice': 1000},
      ],
    });
  });

  Future<OrderMoneyState> deliverFull() => oc.completeDelivery(
        orderId: 'o1',
        expectAlreadyDelivered: false,
        deliveryDate: DateTime(2026, 9, 21),
        payments: [
          {'amount': 300, 'method': 'হাতে'},
        ],
        paymentMethod: 'হাতে',
        discount: 50,
        replaceLines: const [
          ReplaceLine(productId: 'B', productName: 'B', quantity: 1, resolutionType: 'money_deduct', deductionAmount: 100),
          ReplaceLine(productId: 'C', productName: 'C', quantity: 1, resolutionType: 'product_replace'),
          ReplaceLine(productId: 'D', productName: 'D', quantity: 1, resolutionType: 'replace_given'),
        ],
        returnLines: const [
          ReturnLine(productId: 'A', productName: 'A', quantity: 1, unitPrice: 200),
        ],
      );

  test('first delivery applies stock, replace, return and due atomically', () async {
    final s = await deliverFull();

    // A: −2 order items, +1 sales return
    expect(await stockOf('A'), 9);
    // B: money deduct → replace section only
    expect(await stockOf('B'), 10);
    expect(await replaceCountOf('B'), 1);
    // C: replacement handed over now → stock out + replace section
    expect(await stockOf('C'), 9);
    expect(await replaceCountOf('C'), 1);
    // D: replace given → stock out
    expect(await stockOf('D'), 9);
    expect(await replaceCountOf('D'), 0);

    // due = 500 + 1000 − (300 cash + 100 deduct + 200 return) − 50 discount
    expect(await dueOf('u1'), 850);
    expect(s.newUserDue, 850);

    final o = await doc('orders', 'o1');
    expect(o['status'], 'delivered');
    expect(o['paidAmount'], 600);
    expect(o['deductionAmount'], 100);
    expect(o['returnAmount'], 200);
    expect(o['discountAmount'], 50);
    expect(o['previousDue'], 500);
    expect((o['replaceItems'] as List).length, 3);
    expect((o['replaceItems'] as List).every((m) => m['accounted'] == true), isTrue);

    final entries = await db.collection('admin_replace_entries').get();
    expect(entries.docs.length, 2);
    final c = entries.docs.firstWhere((d) => d['productId'] == 'C').data();
    expect(c['deliveredToCustomer'], isTrue);
    expect(c['customerResolutionType'], 'product_replace');

    final stockIns = await db.collection('stock_ins').get();
    expect(stockIns.docs.single['quantity'], 1);
    expect(stockIns.docs.single['orderId'], 'o1');
    final ret = (o['returnItems'] as List).single as Map;
    expect(ret['productId'], 'A');
    expect(ret['totalPrice'], 200);
    expect(ret['stockInId'], stockIns.docs.single.id);
  });

  test('second delivery of the same order is refused and changes nothing', () async {
    await deliverFull();
    await expectLater(deliverFull(), throwsA(isA<OrderOpException>()));
    expect(await stockOf('A'), 9);
    expect(await dueOf('u1'), 850);
    expect((await db.collection('admin_replace_entries').get()).docs.length, 2);
    expect((await db.collection('stock_ins').get()).docs.length, 1);
  });

  test('dispatched order is not stock-cut again on delivery', () async {
    await oc.dispatchOrder(orderId: 'o1', memoNumber: 'M1');
    expect(await stockOf('A'), 8);
    await expectLater(oc.dispatchOrder(orderId: 'o1', memoNumber: 'M1'),
        throwsA(isA<OrderOpException>()));
    expect(await stockOf('A'), 8);
    await oc.completeDelivery(
        orderId: 'o1', expectAlreadyDelivered: false, deliveryDate: DateTime.now());
    expect(await stockOf('A'), 8);
    expect(await dueOf('u1'), 1500);
  });

  test('re-opening a delivered order only credits the new amounts', () async {
    await deliverFull();
    // due changed elsewhere meanwhile (e.g. another order) — must be kept
    await db.collection('users').doc('u1').update({'totalDue': 2000});
    final s = await oc.completeDelivery(
      orderId: 'o1',
      expectAlreadyDelivered: true,
      deliveryDate: DateTime.now(),
      payments: [
        {'amount': 100, 'method': 'বিকাশ'},
      ],
      paymentMethod: 'বিকাশ',
    );
    expect(await dueOf('u1'), 1900);
    expect(s.paidAmount, 700);
    expect(s.previousDue, 500); // unchanged by a re-open
    expect(s.payments.length, 2);
    expect(await stockOf('A'), 9); // items not cut again
    // first payment dated on the delivery day, the new one today
    expect((s.payments[0]['date'] as Timestamp).toDate(), DateTime(2026, 9, 21));
    final today = OrderController.paymentDayKey(DateTime.now());
    expect((await doc('orders', 'o1'))['paymentDays'], containsAll({'2026-09-21', today}));
  });

  test('pending replace is handed over once; an already handed one is skipped', () async {
    Future<void> entry(String id, bool delivered) =>
        db.collection('admin_replace_entries').doc(id).set({
          'customerId': 'u1',
          'productId': 'B',
          'quantity': 2,
          'customerResolutionType': 'product_replace',
          'replaceProductId': 'E',
          'replaceProductName': 'E',
          'deliveredToCustomer': delivered,
          'status': 'at_shop',
        });
    await entry('p1', false);
    await entry('p2', true);
    final s = await oc.completeDelivery(
      orderId: 'o1',
      expectAlreadyDelivered: false,
      deliveryDate: DateTime.now(),
      pendingReplaceIds: ['p1', 'p2'],
    );
    expect(s.skippedPendingReplaces, 1);
    expect(await stockOf('E'), 8);
    expect((await doc('admin_replace_entries', 'p1'))['deliveredToCustomer'], isTrue);
  });

  test('order with a deleted product still delivers', () async {
    await db.collection('products').doc('A').delete();
    await oc.completeDelivery(
        orderId: 'o1', expectAlreadyDelivered: false, deliveryDate: DateTime.now());
    expect((await doc('orders', 'o1'))['status'], 'delivered');
    expect(await dueOf('u1'), 1500);
  });

  test('removing replace lines reverses exactly what adding them did', () async {
    await deliverFull();
    final items = List<Map<String, dynamic>>.from(
        ((await doc('orders', 'o1'))['replaceItems'] as List)
            .map((e) => Map<String, dynamic>.from(e)));

    final money = items.firstWhere((m) => m['resolutionType'] == 'money_deduct');
    await oc.removeReplaceFromOrder(orderId: 'o1', item: money);
    expect(await dueOf('u1'), 950);
    expect(await replaceCountOf('B'), 0);
    final o = await doc('orders', 'o1');
    expect(o['paidAmount'], 500);
    expect(o['deductionAmount'], 0);

    final given = items.firstWhere((m) => m['resolutionType'] == 'product_replace');
    await oc.removeReplaceFromOrder(orderId: 'o1', item: given);
    expect(await stockOf('C'), 10);
    expect(await replaceCountOf('C'), 0);
    expect((await db.collection('admin_replace_entries').get()).docs, isEmpty);

    // removing the same line twice is refused
    await expectLater(oc.removeReplaceFromOrder(orderId: 'o1', item: given),
        throwsA(isA<OrderOpException>()));
    expect(await stockOf('C'), 10);
  });

  test('adding a money-deduct replace on a delivered order credits the customer', () async {
    await deliverFull();
    await oc.addReplaceToOrder(
      orderId: 'o1',
      line: const ReplaceLine(productId: 'E', productName: 'E', quantity: 2, resolutionType: 'money_deduct', deductionAmount: 80),
    );
    expect(await dueOf('u1'), 770);
    expect(await replaceCountOf('E'), 2);
    expect(await stockOf('E'), 10);
    expect((await doc('orders', 'o1'))['deductionAmount'], 180);
  });

  test('money deducted before delivery is counted once at delivery', () async {
    await oc.addReplaceToOrder(
      orderId: 'o1',
      line: const ReplaceLine(productId: 'E', productName: 'E', quantity: 1, resolutionType: 'money_deduct', deductionAmount: 100),
    );
    expect(await dueOf('u1'), 500); // not delivered yet → due untouched
    await oc.completeDelivery(
        orderId: 'o1', expectAlreadyDelivered: false, deliveryDate: DateTime.now());
    expect(await dueOf('u1'), 1400); // 500 + 1000 − 100
  });

  test('manual corrections move the due by the difference only', () async {
    await deliverFull(); // due 850
    await db.collection('users').doc('u1').update({'totalDue': 3000});
    await oc.adjustOrderAmounts('o1', discountAmount: 80); // +30 discount
    expect(await dueOf('u1'), 2970);
    await oc.adjustOrderAmounts('o1', returnAmount: 150); // −50 return credit
    expect(await dueOf('u1'), 3020);
    final o = await doc('orders', 'o1');
    expect(o['paidAmount'], 550);
    await oc.adjustOrderAmounts('o1', previousDue: 400); // −100
    expect(await dueOf('u1'), 2920);
  });

  test('editing items of a delivered order moves stock and due', () async {
    await deliverFull(); // A stock 9, due 850
    await oc.updateOrderItems('o1', [
      OrderItem(productId: 'A', productName: 'A', image: '', quantity: 3, pricePerUnit: 500, totalPrice: 1500),
    ]);
    expect(await stockOf('A'), 8);
    expect(await dueOf('u1'), 1350);
  });

  test('status revert restores item stock once', () async {
    await oc.dispatchOrder(orderId: 'o1', memoNumber: 'M');
    await oc.updateOrderStatus('o1', 'cancelled');
    await oc.updateOrderStatus('o1', 'cancelled');
    expect(await stockOf('A'), 10);
  });

  test('order from the customer app (uid instead of userId) still updates the due', () async {
    await db.collection('orders').doc('o2').set({
      'status': 'approved',
      // the customer app saves the customer as `uid`
      'uid': 'u1',
      'shopName': 'Shop',
      'totalAmount': 700,
      'paidAmount': 0,
      'createdAt': Timestamp.now(),
      'items': [
        {'productId': 'A', 'productName': 'A', 'quantity': 1, 'pricePerUnit': 700, 'totalPrice': 700},
      ],
    });
    final s = await oc.completeDelivery(
      orderId: 'o2',
      expectAlreadyDelivered: false,
      deliveryDate: DateTime.now(),
      payments: [
        {'amount': 200, 'method': 'SR হাতে'},
      ],
      paymentMethod: 'SR হাতে',
    );
    expect(s.newUserDue, 1000); // 500 + 700 − 200
    expect(await dueOf('u1'), 1000);
    expect((await doc('orders', 'o2'))['previousDue'], 500);
  });

  test('customer found by phone when the order carries an unknown id', () async {
    await db.collection('users').doc('u9').set({'totalDue': 300, 'phone': '0177'});
    await db.collection('orders').doc('o3').set({
      'status': 'approved',
      'userId': 'auth-uid-not-a-user-doc',
      'shopName': 'Other Shop',
      'shopPhone': '0177',
      'totalAmount': 500,
      'paidAmount': 0,
      'createdAt': Timestamp.now(),
      'items': const [],
    });
    final s = await oc.completeDelivery(
      orderId: 'o3',
      expectAlreadyDelivered: false,
      deliveryDate: DateTime.now(),
    );
    expect(s.newUserDue, 800); // 300 + 500
    expect(await dueOf('u9'), 800);
    // the order now points at the real customer document
    expect((await doc('orders', 'o3'))['userId'], 'u9');
  });

  test('delivery without any customer reports that no due was updated', () async {
    await db.collection('orders').doc('o4').set({
      'status': 'approved',
      'shopName': 'Walk-in',
      'totalAmount': 100,
      'paidAmount': 0,
      'createdAt': Timestamp.now(),
      'items': const [],
    });
    final s = await oc.completeDelivery(
      orderId: 'o4',
      expectAlreadyDelivered: false,
      deliveryDate: DateTime.now(),
    );
    expect(s.newUserDue, isNull);
  });

  test('admin corrections also reach a customer linked only by uid', () async {
    await db.collection('orders').doc('o5').set({
      'status': 'delivered',
      'uid': 'u1', // customer-app order
      'shopName': 'Shop',
      'totalAmount': 1000,
      'paidAmount': 400,
      'previousDue': 500,
      'createdAt': Timestamp.now(),
      'items': const [],
    });
    // extra ৳100 collected later → the customer's due must drop
    await oc.adjustOrderAmounts('o5', paidAmount: 500);
    expect(await dueOf('u1'), 400);
  });

  test('correcting the delivery date moves that day\'s payments with it', () async {
    // delivered today, then corrected to 26 Sep
    await oc.completeDelivery(
      orderId: 'o1',
      expectAlreadyDelivered: false,
      deliveryDate: DateTime(2026, 9, 28),
      payments: [
        {'amount': 770, 'method': 'SR হাতে'},
      ],
      paymentMethod: 'SR হাতে',
    );
    // money taken later keeps its own day
    await oc.completeDelivery(
      orderId: 'o1',
      expectAlreadyDelivered: true,
      deliveryDate: DateTime(2026, 9, 28),
      payments: [
        {'amount': 100, 'method': 'SR হাতে'},
      ],
      paymentMethod: 'SR হাতে',
    );
    final later = ((await doc('orders', 'o1'))['payments'] as List)[1] as Map;
    final laterDate = (later['date'] as Timestamp).toDate();

    await oc.updateDeliveredAt('o1', DateTime(2026, 9, 26));

    final o = await doc('orders', 'o1');
    final payments = (o['payments'] as List).cast<Map>();
    expect((payments[0]['date'] as Timestamp).toDate(), DateTime(2026, 9, 26));
    // the later collection did not move
    expect((payments[1]['date'] as Timestamp).toDate(), laterDate);
    expect(o['paymentDays'], contains('2026-09-26'));
  });
}
