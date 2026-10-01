import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../widgets/item_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All Items';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: ValueListenableBuilder<List<ItemModel>>(
          valueListenable: ItemRepository.itemsNotifier,
          builder: (context, items, _) {
            final filteredItems = items.where((item) {
              final query = _searchController.text.trim().toLowerCase();
              final matchesQuery =
                  query.isEmpty ||
                  item.title.toLowerCase().contains(query) ||
                  item.location.toLowerCase().contains(query);

              final matchesCategory =
                  _selectedCategory == 'All Items' ||
                  _matchesCategory(item, _selectedCategory);

              return matchesQuery && matchesCategory;
            }).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'smartFind',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search for lost items...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryChip(
                                context,
                                'All Items',
                                _selectedCategory == 'All Items',
                              ),
                              _buildCategoryChip(
                                context,
                                'Electronics',
                                _selectedCategory == 'Electronics',
                              ),
                              _buildCategoryChip(
                                context,
                                'Pets',
                                _selectedCategory == 'Pets',
                              ),
                              _buildCategoryChip(
                                context,
                                'Wallets',
                                _selectedCategory == 'Wallets',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Recent Reports',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ItemCard(item: filteredItems[index]),
                      childCount: filteredItems.length,
                    ),
                  ),
                ),
                if (filteredItems.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No matching reports yet. Try another search or report one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _matchesCategory(ItemModel item, String category) {
    final title = item.title.toLowerCase();
    switch (category) {
      case 'Electronics':
        return title.contains('airpods') ||
            title.contains('phone') ||
            title.contains('earbud') ||
            title.contains('headphones');
      case 'Pets':
        return title.contains('dog') ||
            title.contains('pet') ||
            title.contains('cat');
      case 'Wallets':
        return title.contains('wallet') || title.contains('card');
      default:
        return true;
    }
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String label,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool value) {
          setState(() {
            _selectedCategory = label;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }
}
