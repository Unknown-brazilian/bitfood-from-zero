import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../theme.dart';
import '../queries.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(document: gql(myRestaurantQuery), fetchPolicy: FetchPolicy.cacheAndNetwork),
      builder: (result, {fetchMore, refetch}) {
        final restaurant = result.data?['myRestaurant'];
        final categories = (restaurant?['categories'] as List?) ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddFoodSheet(context, categories, refetch),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Adicionar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          body: RefreshIndicator(
            onRefresh: () async { refetch?.call(); },
            color: AppColors.primary,
            child: result.isLoading && result.data == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Cardápio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      const SizedBox(height: 16),
                      if (categories.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.restaurant_menu, size: 56, color: AppColors.textLight),
                                SizedBox(height: 12),
                                Text('Cardápio vazio', style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                                SizedBox(height: 4),
                                Text('Toque em "Adicionar" para criar seu cardápio', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...categories.map((cat) => _CategorySection(category: cat, refetch: refetch)),
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _showAddFoodSheet(BuildContext context, List categories, Refetch? refetch) {
    final client = GraphQLProvider.of(context).value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddFoodSheet(categories: categories, client: client, onSaved: () { refetch?.call(); }),
    );
  }
}

class _AddFoodSheet extends StatefulWidget {
  final List categories;
  final GraphQLClient client;
  final VoidCallback onSaved;
  const _AddFoodSheet({required this.categories, required this.client, required this.onSaved});

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _newCatCtrl = TextEditingController();
  String? _selectedCategoryId;
  late bool _creatingNewCat;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _creatingNewCat = widget.categories.isEmpty;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _newCatCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext ctx) async {
    final title = _titleCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text.trim());
    if (title.isEmpty) {
      setState(() => _error = 'Digite o nome do item');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Digite o preço em satoshis');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final client = widget.client;

      String? categoryId = _selectedCategoryId;

      // Create new category first if needed
      if (_creatingNewCat) {
        final catTitle = _newCatCtrl.text.trim();
        if (catTitle.isEmpty) {
          setState(() { _loading = false; _error = 'Digite o nome da categoria'; });
          return;
        }
        final catResult = await client.mutate(MutationOptions(
          document: gql(addCategoryMutation),
          variables: {'title': catTitle},
        ));
        if (catResult.hasException) throw catResult.exception!;
        final cats = catResult.data?['addCategory']?['categories'] as List?;
        categoryId = cats?.last?['_id'];
      }

      if (categoryId == null) {
        setState(() { _loading = false; _error = 'Selecione ou crie uma categoria'; });
        return;
      }

      final result = await client.mutate(MutationOptions(
        document: gql(addFoodMutation),
        variables: {
          'categoryId': categoryId,
          'title': title,
          'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          'priceSats': price,
        },
      ));
      if (result.hasException) throw result.exception!;

      widget.onSaved();
      if (mounted) Navigator.pop(ctx);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll(RegExp(r'OperationException.*?:\s?'), '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Adicionar Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],

          // Category selection
          const Text('Categoria', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          if (widget.categories.isNotEmpty && !_creatingNewCat) ...[
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(filled: true, fillColor: Color(0xFFF5F5F5), border: OutlineInputBorder()),
              hint: const Text('Selecione uma categoria'),
              items: widget.categories.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem(
                value: cat['_id'] as String,
                child: Text(cat['title'] as String),
              )).toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() { _creatingNewCat = true; _selectedCategoryId = null; }),
              child: const Text('+ Criar nova categoria', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ] else ...[
            TextField(
              controller: _newCatCtrl,
              decoration: InputDecoration(
                hintText: 'Nome da nova categoria',
                filled: true, fillColor: const Color(0xFFF5F5F5), border: const OutlineInputBorder(),
                suffixIcon: widget.categories.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() { _creatingNewCat = false; _newCatCtrl.clear(); }),
                      )
                    : null,
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Food title
          const Text('Nome do item', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(hintText: 'ex: Pizza Margherita', filled: true, fillColor: Color(0xFFF5F5F5), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          // Description
          const Text('Descrição (opcional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(hintText: 'ex: Molho de tomate, mussarela, manjericão', filled: true, fillColor: Color(0xFFF5F5F5), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          // Price
          const Text('Preço em satoshis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'ex: 5000',
              prefixIcon: Icon(Icons.electric_bolt, color: AppColors.orange, size: 18),
              suffixText: 'sats',
              filled: true, fillColor: Color(0xFFF5F5F5), border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _submit(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Adicionar ao Cardápio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final Map<String, dynamic> category;
  final Refetch? refetch;
  const _CategorySection({required this.category, this.refetch});

  @override
  Widget build(BuildContext context) {
    final foods = (category['foods'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(category['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ),
        ...foods.map((food) => _FoodTile(food: food, refetch: refetch)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FoodTile extends StatelessWidget {
  final Map<String, dynamic> food;
  final Refetch? refetch;
  const _FoodTile({required this.food, this.refetch});

  Future<void> _toggle(BuildContext context, bool current) async {
    final client = GraphQLProvider.of(context).value;
    await client.mutate(MutationOptions(
      document: gql(updateFoodMutation),
      variables: {'foodId': food['_id'], 'isActive': !current},
    ));
    refetch?.call();
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  Row(children: [
                    const Icon(Icons.electric_bolt, color: AppColors.orange, size: 13),
                    const SizedBox(width: 2),
                    Text('${food['priceSats'] ?? 0} sats', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ]),
                ],
              ),
            ),
            Switch(
              value: food['isActive'] == true,
              onChanged: (v) => _toggle(context, food['isActive'] == true),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      );
}
