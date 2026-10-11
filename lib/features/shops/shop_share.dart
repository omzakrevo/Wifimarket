import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/i18n/i18n.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Lien public d'une boutique, partageable tel quel (ouvre directement la boutique).
String shopUrl(String slug) => '${AppConfig.siteUrl}/shop/$slug';

/// Partage le lien de la boutique ; si le partage système n'existe pas (navigateur de bureau), le lien est copié.
Future<void> shareShop(BuildContext context, Shop s) async {
  final url = shopUrl(s.slug);
  try {
    final r = await SharePlus.instance.share(ShareParams(text: '${s.name} — $url'));
    if (r.status == ShareResultStatus.unavailable) throw StateError('share unavailable');
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) toast(context, context.t('shop.link_copied'));
  }
}

/// Carte « lien de la boutique » : lien affiché, bouton copier et bouton partager.
class ShopLinkCard extends StatelessWidget {
  const ShopLinkCard(this.shop, {super.key});
  final Shop shop;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = shopUrl(shop.slug);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: softCard(cs),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.link_rounded, size: 20, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('shop.share_link'), style: Theme.of(context).textTheme.bodySmall),
            SelectableText(url.replaceFirst(RegExp(r'^https?://'), ''), maxLines: 1, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
          ]),
        ),
        IconButton(
          tooltip: context.t('shop.copy_link'),
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) toast(context, context.t('shop.link_copied'));
          },
        ),
        IconButton(tooltip: context.t('shop.share'), icon: const Icon(Icons.ios_share_rounded), onPressed: () => shareShop(context, shop)),
      ]),
    );
  }
}
