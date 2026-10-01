import 'package:flutter/foundation.dart';

class ItemModel {
  final String id;
  final String title;
  final String location;
  final String reporter;
  final String time;
  final String? imageUrl;
  final bool isLost;
  final String category;
  final String description;
  final String contactInfo;

  ItemModel({
    required this.id,
    required this.title,
    required this.location,
    required this.reporter,
    required this.time,
    this.imageUrl,
    required this.isLost,
    required this.category,
    required this.description,
    this.contactInfo = 'Not shared',
  });
}

final List<ItemModel> mockItems = [
  ItemModel(
    id: '1',
    title: 'Black Leather Wallet',
    location: '30th Bldg. 404',
    reporter: 'Prabina',
    time: '1h ago',
    imageUrl: 'https://images.unsplash.com/photo-1627123424574-724758594e93?auto=format&fit=crop&q=80&w=400',
    isLost: true,
    category: 'Wallets',
    description: 'Black leather wallet with a silver snap closure and a few cards inside.',
    contactInfo: 'james@example.com',
  ),
  ItemModel(
    id: '2',
    title: 'Golden Retriever',
    location: '30th Bldg. lounge area',
    reporter: 'Aliza',
    time: '3h ago',
    imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&q=80&w=400',
    isLost: false,
    category: 'Pets',
    description: 'Friendly golden retriever wearing a red collar. Found near the picnic area.',
    contactInfo: 'sarah@example.com',
  ),
  ItemModel(
    id: '3',
    title: 'AirPods Max (Blue)',
    location: '27th Bldg. 1404',
    reporter: 'Ming',
    time: '5h ago',
    imageUrl: null,
    isLost: true,
    category: 'Electronics',
    description: 'Blue AirPods Max case with a faded sticker on the side and a charging cable.',
    contactInfo: 'michael@example.com',
  ),
];

class ItemRepository {
  static final ValueNotifier<List<ItemModel>> itemsNotifier =
      ValueNotifier<List<ItemModel>>(List<ItemModel>.from(mockItems));

  static void addItem(ItemModel item) {
    final updatedItems = [item, ...itemsNotifier.value];
    itemsNotifier.value = updatedItems;
  }
}
