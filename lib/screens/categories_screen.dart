import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const _images = {
    'routers': Img.router,
    'ap': Img.tower,
    'ptp': Img.tower3,
    'switch': Img.switchPoe,
    'cables': Img.cableRoll,
    'power': Img.space,
    'sat': Img.dish,
    'vouchers': Img.pos,
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories'),
        automaticallyImplyLeading: false,
      ),
      body: MaxWidth(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: w >= 900
                ? 4
                : w >= 600
                ? 3
                : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: categories.length,
          itemBuilder: (c, i) {
            final cat = categories[i];
            final count = app.visibleProducts
                .where((p) => p.categoryId == cat.id)
                .length;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SearchScreen(categoryId: cat.id, title: cat.name),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(_images[cat.id] ?? Img.router),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x110A1230), Color(0xEE0A1230)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(cat.icon, color: AppColors.primary),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '$count produit${count > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
