import 'package:flutter_test/flutter_test.dart';

import 'package:gomi_pic/models/classification.dart';

void main() {
  test('GarbageCategory.fromJa maps Japanese labels', () {
    expect(GarbageCategory.fromJa('可燃'), GarbageCategory.burnable);
    expect(GarbageCategory.fromJa('可燃ごみ'), GarbageCategory.burnable);
    expect(GarbageCategory.fromJa('不燃'), GarbageCategory.nonBurnable);
    expect(GarbageCategory.fromJa('資源ごみ'), GarbageCategory.recyclable);
    expect(GarbageCategory.fromJa('粗大'), GarbageCategory.oversized);
    expect(GarbageCategory.fromJa(null), GarbageCategory.other);
  });

  test('Classification round-trips via encode/decode', () {
    const c = Classification(
      itemName: 'ペットボトル',
      category: GarbageCategory.recyclable,
      disposalMethod: 'キャップを外して洗う',
      collectionDay: '毎週水曜日',
      notes: 'ラベルは剥がす',
      municipality: '渋谷区',
    );
    final decoded = Classification.decode(c.encode());
    expect(decoded.itemName, c.itemName);
    expect(decoded.category, c.category);
    expect(decoded.municipality, c.municipality);
  });
}
