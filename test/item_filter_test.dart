import 'package:flutter_test/flutter_test.dart';
import 'package:smartfind/models/item_model.dart';
import 'package:smartfind/utils/item_filter.dart';

ItemModel _item(
  String id,
  String title, {
  String status = 'lost',
  String category = 'other',
  String location = 'Gymnasium',
  String description = '',
  bool reunited = false,
  String meetBuilding = '',
}) {
  final now = DateTime(2026, 3, 1);
  return ItemModel(
    id: id,
    title: title,
    description: description,
    category: category,
    status: status,
    location: location,
    latitude: 35.1,
    longitude: 129.1,
    reporterId: 'u',
    reporterName: 'U',
    contactInfo: '',
    imageUrl: '',
    createdAt: now,
    updatedAt: now,
    reunited: reunited,
    meetBuilding: meetBuilding,
  );
}

void main() {
  final items = [
    _item('1', 'Black wallet', category: 'wallets', location: 'Front Gate'),
    _item('2', 'Blue umbrella', status: 'found', category: 'accessories'),
    _item('3', 'Wallet with cards', status: 'found', category: 'wallets', description: 'brown leather'),
    _item('4', 'Old keys', category: 'keys', reunited: true),
  ];

  test('an empty filter shows every open report and is not active', () {
    const f = ItemFilter();
    expect(f.isActive, isFalse);
    expect(f.apply(items).map((i) => i.id), ['1', '2', '3']);
  });

  test('words are matched one by one, in any order', () {
    expect(const ItemFilter(query: 'wallet black').apply(items).map((i) => i.id), ['1']);
    expect(const ItemFilter(query: 'leather').apply(items).map((i) => i.id), ['3']);
  });

  test('status, category and building narrow the list', () {
    expect(const ItemFilter(status: 'found').apply(items).map((i) => i.id), ['2', '3']);
    expect(const ItemFilter(category: 'wallets').apply(items).map((i) => i.id), ['1', '3']);
    expect(const ItemFilter(building: 'front gate').apply(items).map((i) => i.id), ['1']);
  });

  test('the person can be found in the chosen building too', () {
    final withMeet = [_item('5', 'Scarf', location: 'Tennis Court', meetBuilding: 'Front Gate')];
    expect(const ItemFilter(building: 'Front Gate').apply(withMeet), isNotEmpty);
  });

  test('copyWith changes only what is given, so clearing returns everything', () {
    final f = const ItemFilter(query: 'x', status: 'lost').copyWith(query: '', status: 'all');
    expect(f.isActive, isFalse);
    expect(f.apply(items), hasLength(3));
  });

  test('reunited reports can be included', () {
    expect(const ItemFilter(onlyOpen: false).apply(items), hasLength(4));
  });
}
