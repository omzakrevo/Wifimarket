import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Marketplace d'occasion : annonces publiées par les particuliers du pays.
class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});
  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  String? cat;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.publishedListings
        .where((l) => cat == null || l.categoryId == cat)
        .toList();
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: Text('Occasion ${app.country.flag}'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: w >= 900 ? 0 : 80),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewListingScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Publier une annonce'),
        ),
      ),
      body: MaxWidth(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Toutes'),
                      selected: cat == null,
                      onSelected: (_) => setState(() => cat = null),
                    ),
                  ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.name),
                        selected: cat == c.id,
                        onSelected: (_) => setState(() => cat = c.id),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Aucune annonce en ${app.country.name} dans cette catégorie.\nPubliez la première !',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 170),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridColumns(w),
                        childAspectRatio: .7,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: items.length,
                      itemBuilder: (c, i) => _ListingCard(listing: items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Listing listing;
  const _ListingCard({required this.listing});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = listing;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: l)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(l.imageUrl),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Badge2(l.condition.label, color: l.condition.color),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l.city} • ${timeAgo(l.createdAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.country.format(l.priceXof),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingDetailScreen extends StatelessWidget {
  final Listing listing;
  const ListingDetailScreen({super.key, required this.listing});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = listing;
    return Scaffold(
      appBar: AppBar(title: const Text('Annonce')),
      body: MaxWidth(
        max: 760,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(aspectRatio: 1.3, child: NetImage(l.imageUrl)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Badge2(l.condition.label, color: l.condition.color),
                const SizedBox(width: 8),
                Text(
                  categoryById(l.categoryId).name,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${app.country.format(l.priceXof)}${l.negotiable ? '  •  Négociable' : ''}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(l.description, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(l.sellerName),
                subtitle: Text(
                  '${l.city} • publié ${timeAgo(l.createdAt)} • ${l.views} vues',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '⚠️ Conseil sécurité : testez le matériel avant de payer et privilégiez la remise en main propre.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Contacter ${l.sellerName} : ${l.sellerPhone}'),
                ),
              ),
              icon: const Icon(Icons.call),
              label: const Text('CONTACTER LE VENDEUR'),
            ),
          ],
        ),
      ),
    );
  }
}

class NewListingScreen extends StatefulWidget {
  const NewListingScreen({super.key});
  @override
  State<NewListingScreen> createState() => _NewListingScreenState();
}

class _NewListingScreenState extends State<NewListingScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final desc = TextEditingController();
  final price = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final city = TextEditingController();
  String cat = categories.first.id;
  ListingCondition cond = ListingCondition.good;
  bool negotiable = true;

  static const _catImages = {
    'routers': Img.modem,
    'ap': Img.tower2,
    'ptp': Img.tower3,
    'switch': Img.switchPoe,
    'cables': Img.utp,
    'power': Img.serverRoom,
    'sat': Img.dish,
    'vouchers': Img.pos,
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    String? req(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle annonce')),
      body: MaxWidth(
        max: 640,
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 32,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Ajouter des photos (bientôt — image de catégorie par défaut)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: title,
                validator: req,
                decoration: const InputDecoration(
                  labelText: 'Titre (ex : MikroTik hAP ac² peu servi)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: cat,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => cat = v!),
              ),
              const SizedBox(height: 10),
              const Text('État', style: TextStyle(fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in ListingCondition.values)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: cond == c,
                      onSelected: (_) => setState(() => cond = c),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Prix invalide' : null,
                decoration: InputDecoration(
                  labelText: 'Prix',
                  suffixText: app.country.symbol,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: negotiable,
                onChanged: (v) => setState(() => negotiable = v),
                title: const Text('Prix négociable'),
              ),
              TextFormField(
                controller: desc,
                maxLines: 4,
                validator: req,
                decoration: const InputDecoration(
                  labelText:
                      'Description (état, accessoires, raison de la vente)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: name,
                validator: req,
                decoration: const InputDecoration(labelText: 'Votre nom'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phone,
                validator: req,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Téléphone / WhatsApp',
                  prefixText: '${app.country.phonePrefix} ',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: city,
                validator: req,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  final local = int.parse(price.text);
                  app.publishListing(
                    Listing(
                      id: 'l${DateTime.now().millisecondsSinceEpoch}',
                      sellerName: name.text.trim(),
                      sellerPhone:
                          '${app.country.phonePrefix} ${phone.text.trim()}',
                      countryCode: app.country.code,
                      city: city.text.trim(),
                      categoryId: cat,
                      title: title.text.trim(),
                      description: desc.text.trim(),
                      priceXof: (local / app.country.ratePerXof).round(),
                      negotiable: negotiable,
                      condition: cond,
                      imageUrl: _catImages[cat] ?? Img.router,
                    ),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Annonce envoyée ✅ Elle sera visible après validation.',
                      ),
                    ),
                  );
                },
                child: const Text('PUBLIER GRATUITEMENT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
