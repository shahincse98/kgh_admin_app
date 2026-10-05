import 'package:flutter_test/flutter_test.dart';
import 'package:kgh_admin_app/modules/order/model/order_model.dart';

/// Profit rule: goods that come back (returned products, and defective units
/// taken against a replace credit) are not a loss — only the money given
/// above their purchase value is.
void main() {
  OrderItem item(String id, int qty, num price, num cost) => OrderItem(
        productId: id,
        productName: id,
        image: '',
        quantity: qty,
        pricePerUnit: price,
        totalPrice: price * qty,
        purchasePrice: cost,
      );

  // purchase prices used when the order did not store one
  const costs = {'cable': 55, 'bob': 240};
  num cost(String id) => (costs[id] ?? 0).toDouble();

  test('real order: replace credit and return are not a full loss', () {
    final o = OrderModel(
      id: 'o1',
      createdAt: DateTime(2026, 9, 26),
      status: 'delivered',
      totalAmount: 1230,
      paidAmount: 1210,
      shopName: 'আব্দুল্লাহ টেলিকম',
      shopAddress: '',
      items: [
        item('tws', 2, 290, 250),
        item('charger33', 1, 350, 310),
        item('bob', 1, 300, 240),
      ],
      deductionAmount: 300,
      returnAmount: 140,
      discountAmount: 20,
      replaceItems: const [
        {'productId': 'bob', 'quantity': 1, 'resolutionType': 'money_deduct', 'deductionAmount': 300},
      ],
      returnItems: const [
        {'productId': 'cable', 'quantity': 2, 'totalPrice': 140},
      ],
    );

    expect(o.netSales, 770); // 1230 − 300 − 140 − 20
    expect(o.purchaseCost(cost), 1050); // 500 + 310 + 240
    // 2 cables back at ৳55 + the defective unit at ৳240
    expect(o.recoveredGoodsValue(cost), 350);
    // 180 item profit − 20 discount − 30 lost on the return − 60 on the replace
    expect(o.profit(cost), 70);
  });

  test('recovery never exceeds the money credited', () {
    final o = OrderModel(
      id: 'o2',
      createdAt: DateTime(2026, 9, 26),
      status: 'delivered',
      totalAmount: 500,
      paidAmount: 450,
      shopName: 'Shop',
      shopAddress: '',
      items: [item('tws', 1, 500, 400)],
      returnAmount: 50,
      returnItems: const [
        // credited ৳50 although the product costs ৳55
        {'productId': 'cable', 'quantity': 1, 'totalPrice': 50},
      ],
    );
    expect(o.recoveredGoodsValue(cost), 50);
    // the sale's own profit stays: 450 net − 400 cost + 50 back
    expect(o.profit(cost), 100);
  });

  test('a real loss is still a loss', () {
    final o = OrderModel(
      id: 'o3',
      createdAt: DateTime(2026, 9, 26),
      status: 'delivered',
      totalAmount: 300,
      paidAmount: 300,
      shopName: 'Shop',
      shopAddress: '',
      items: [item('bob', 1, 300, 240)],
      discountAmount: 100,
    );
    expect(o.profit(cost), -40); // 200 net − 240 cost
  });

  test('older orders without the item lists fall back to the plain rule', () {
    final o = OrderModel(
      id: 'o4',
      createdAt: DateTime(2026, 9, 26),
      status: 'delivered',
      totalAmount: 1000,
      paidAmount: 900,
      shopName: 'Shop',
      shopAddress: '',
      items: [item('tws', 1, 1000, 800)],
      returnAmount: 100, // no returnItems saved
    );
    expect(o.recoveredGoodsValue(cost), 0);
    expect(o.profit(cost), 100); // 900 − 800
  });

  // memo 850: the shop gave a new AirPods and took the defective one back
  // against a ৳330 credit — an exchange, so nothing is earned.
  test('a unit swapped within the order earns nothing', () {
    final o = OrderModel(
      id: 'o5',
      createdAt: DateTime(2026, 10, 4),
      status: 'delivered',
      totalAmount: 330,
      paidAmount: 330,
      shopName: 'তুহিন ইলেক্ট্রনিক্স',
      shopAddress: '',
      items: [item('airpods', 1, 330, 290)],
      deductionAmount: 330,
      replaceItems: const [
        {'productId': 'airpods', 'quantity': 1, 'resolutionType': 'money_deduct', 'deductionAmount': 330},
      ],
    );
    expect(o.profit(cost), 0);
    // valued at the price saved on the order, not the product's current one
    expect(o.profit((_) => 330), 0);
  });

  test('a credit larger than the order is a cost, not cut off at zero', () {
    // cable sold for ৳100 (cost ৳80); a defective AirPods bought earlier for
    // ৳330 (cost ৳290) is credited in full.
    final o = OrderModel(
      id: 'o6',
      createdAt: DateTime(2026, 10, 4),
      status: 'delivered',
      totalAmount: 100,
      paidAmount: 430,
      shopName: 'Shop',
      shopAddress: '',
      items: [item('cable', 1, 100, 80)],
      deductionAmount: 330,
      replaceItems: const [
        {'productId': 'airpods', 'quantity': 1, 'resolutionType': 'money_deduct', 'deductionAmount': 330},
      ],
    );
    num c(String id) => id == 'airpods' ? 290 : 80;
    expect(o.netSales, -230);
    // ৳20 on the cable − ৳40 given above the AirPods' value
    expect(o.profit(c), -20);
  });

  test('a replace line whose credit never reached the order brings nothing back', () {
    final o = OrderModel(
      id: 'o7',
      createdAt: DateTime(2026, 10, 4),
      status: 'delivered',
      totalAmount: 300,
      paidAmount: 300,
      shopName: 'Shop',
      shopAddress: '',
      items: [item('bob', 1, 300, 240)],
      replaceItems: const [
        // older entry: money not recorded on the order
        {'productId': 'bob', 'quantity': 1, 'resolutionType': 'money_deduct', 'deductionAmount': 300},
      ],
    );
    expect(o.recoveredGoodsValue(cost), 0);
    expect(o.profit(cost), 60);
  });

  test('raw order maps give the same result as the model', () {
    final p = orderProfitOf({
      'totalAmount': 330,
      'deductionAmount': 330,
      'items': [
        {'productId': 'airpods', 'quantity': 1, 'totalPrice': 330, 'purchasePrice': 290},
      ],
      'replaceItems': [
        {'productId': 'airpods', 'quantity': 1, 'resolutionType': 'money_deduct', 'deductionAmount': 330},
      ],
    }, (_) => 330);
    expect(p.netSales, 0);
    expect(p.purchaseCost, 290);
    expect(p.recovered, 290);
    expect(p.profit, 0);
  });
}
