import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class _Pic {
  _Pic({this.bytes, this.ext = 'jpg', this.existing, this.isVideo = false});
  final Uint8List? bytes;
  final String ext;
  final Media? existing;
  final bool isVideo;
}

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key, this.editId});
  final String? editId;
  @override
  ConsumerState<ListingFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<ListingFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _model = TextEditingController();
  final _defects = TextEditingController();
  final _warranty = TextEditingController();
  final _exWanted = TextEditingController();
  final _city = TextEditingController();
  int? categoryId, brandId;
  String condition = 'used', currency = 'XOF', country = 'BF';
  String? shopId;
  bool delivery = false, negotiable = true, exchange = false, busy = false, loaded = false;
  final List<_Pic> pics = [];
  final List<Media> removed = [];
  Listing? editing;
  static const maxPhotos = 8;

  bool get isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = ref.read(countryProvider);
    if (c != null) country = c;
    if (isEdit) {
      final l = await Repo.listing(widget.editId!);
      if (l != null && mounted) {
        editing = l;
        _title.text = l.title;
        _desc.text = l.description;
        _price.text = l.price.toString();
        _qty.text = '${l.quantity}';
        _model.text = l.modelText ?? '';
        _defects.text = l.defects ?? '';
        _warranty.text = l.warranty ?? '';
        _exWanted.text = l.exchangeWanted ?? '';
        _city.text = l.city ?? '';
        categoryId = l.categoryId;
        brandId = l.brandId;
        condition = l.condition;
        currency = l.currency;
        country = l.country;
        shopId = l.shopId;
        delivery = l.delivery;
        negotiable = l.negotiable;
        exchange = l.exchange;
        pics.addAll(l.media.map((m) => _Pic(existing: m, isVideo: !m.isImage)));
      }
    } else {
      final p = await Repo.profile(myId!);
      if (p?.countryCode != null) country = p!.countryCode!;
      _city.text = p?.city ?? '';
    }
    if (mounted) setState(() => loaded = true);
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _price, _qty, _model, _defects, _warranty, _exWanted, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    if (pics.where((p) => !p.isVideo).length >= maxPhotos) return toast(context, context.t('form.err_max_photos'), error: true);
    try {
      if (src == ImageSource.gallery) {
        final files = await ImagePicker().pickMultiImage(maxWidth: 1800, imageQuality: 82);
        for (final f in files) {
          if (pics.where((p) => !p.isVideo).length >= maxPhotos) break;
          pics.add(_Pic(bytes: await f.readAsBytes(), ext: _ext(f.name)));
        }
      } else {
        final f = await ImagePicker().pickImage(source: src, maxWidth: 1800, imageQuality: 82);
        if (f != null) pics.add(_Pic(bytes: await f.readAsBytes(), ext: _ext(f.name)));
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) toast(context, context.t('form.err_image'), error: true);
    }
  }

  String _ext(String n) {
    final e = n.contains('.') ? n.split('.').last.toLowerCase() : 'jpg';
    return const ['jpg', 'jpeg', 'png', 'webp'].contains(e) ? (e == 'jpeg' ? 'jpg' : e) : 'jpg';
  }

  Future<void> _pickVideo() async {
    if (pics.any((p) => p.isVideo)) return;
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.length > 50 * 1024 * 1024) return toast(context, context.t('form.err_video'), error: true);
    final e = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'mp4';
    setState(() => pics.add(_Pic(bytes: bytes, ext: e == 'webm' ? 'webm' : 'mp4', isVideo: true)));
  }

  Future<void> _save(bool publish) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (categoryId == null) return toast(context, context.t('common.category'), error: true);
    setState(() => busy = true);
    try {
      final data = {
        'shop_id': shopId,
        'category_id': categoryId,
        'brand_id': brandId,
        'model_text': _model.text.trim().isEmpty ? null : _model.text.trim(),
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'condition': condition,
        'price': parseNum(_price.text) ?? 0,
        'currency_code': currency,
        'quantity': int.tryParse(_qty.text.trim()) ?? 1,
        'country_code': country,
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'delivery_available': delivery,
        'defects': _defects.text.trim().isEmpty ? null : _defects.text.trim(),
        'warranty': _warranty.text.trim().isEmpty ? null : _warranty.text.trim(),
        'negotiable': negotiable,
        'exchange_possible': exchange,
        'exchange_wanted': exchange && _exWanted.text.trim().isNotEmpty ? _exWanted.text.trim() : null,
        'status': publish ? 'active' : (editing != null && editing!.status != 'draft' && editing!.status != 'active' ? editing!.status : 'draft'),
      };
      if (!publish && editing?.status == 'active') data['status'] = 'paused';
      final id = await Repo.saveListing(widget.editId, data);
      for (final m in removed) {
        await Repo.deleteMedia(m.path);
      }
      var pos = 0;
      for (final p in pics) {
        if (p.existing == null) {
          await Repo.uploadListingMedia(id, p.bytes!, p.ext, p.isVideo ? 'video' : 'image', pos);
        } else if (p.existing!.position != pos) {
          await sb.from('listing_media').update({'position': pos}).eq('listing_id', id).eq('storage_path', p.existing!.path);
        }
        pos++;
      }
      final fresh = await Repo.listing(id);
      ref.invalidate(myListingsProvider);
      ref.invalidate(listingProvider(id));
      if (!mounted) return;
      final status = fresh?.status ?? data['status'];
      toast(context, status == 'pending_review' ? context.t('form.under_review') : (publish ? context.t('form.publish') : context.t('form.saved_draft')));
      context.go('/listing/$id');
    } catch (e) {
      if (mounted) toast(context, errMsg(context, e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return WPage(title: context.t('nav.sell'), child: const SkeletonList());
    final lang = context.lang;
    final cats = ref.watch(categoriesProvider).asData?.value ?? [];
    final brands = ref.watch(brandsProvider).asData?.value ?? [];
    final countries = ref.watch(countriesProvider).asData?.value ?? [];
    final cities = (ref.watch(citiesProvider).asData?.value ?? []).where((c) => c.country == country).toList();
    final shops = ref.watch(_myShopsProvider).asData?.value ?? [];
    final roots = cats.where((c) => c.parentId == null).toList();
    final cs = Theme.of(context).colorScheme;
    final catItems = <DropdownMenuItem<int>>[
      for (final r in roots) ...[
        for (final c in cats.where((c) => c.parentId == r.id)) DropdownMenuItem(value: c.id, child: Text('${r.name(lang)} › ${c.name(lang)}', overflow: TextOverflow.ellipsis)),
        if (!cats.any((c) => c.parentId == r.id)) DropdownMenuItem(value: r.id, child: Text(r.name(lang))),
      ]
    ];
    final cur = countries.where((c) => c.code == country).firstOrNull?.currency;

    return WPage(
      title: isEdit ? context.t('common.edit') : context.t('nav.sell'),
      maxWidth: 760,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.t('form.sell_sub'), style: Theme.of(context).textTheme.bodyMedium).reveal(),
          const SizedBox(height: 18),
          Text(context.t('form.photos'), style: Theme.of(context).textTheme.titleMedium),
          Text(context.t('form.photos_hint'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final (i, p) in pics.indexed)
                Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(fit: StackFit.expand, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: p.isVideo
                          ? Container(color: WM.ink, child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 34))
                          : (p.existing != null ? Net(p.existing!.url) : Image.memory(p.bytes!, fit: BoxFit.cover)),
                    ),
                    if (i == 0 && !p.isVideo) Positioned(left: 6, bottom: 6, child: Badge2(context.t('form.cover'), color: WM.signalDeep)),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Pressable(
                        onTap: () => setState(() {
                          if (p.existing != null) removed.add(p.existing!);
                          pics.removeAt(i);
                        }),
                        child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                      ),
                    ),
                    if (i > 0 && !p.isVideo)
                      Positioned(left: 4, top: 4, child: Pressable(onTap: () => setState(() => pics.insert(0, pics.removeAt(i))), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.star_rounded, size: 14, color: Colors.white)))),
                  ]),
                ).popIn(index: i),
              if (!kIsWeb) _AddTile(icon: Icons.photo_camera_rounded, label: context.t('form.take_photo'), onTap: () => _pick(ImageSource.camera)),
              _AddTile(icon: Icons.add_photo_alternate_rounded, label: context.t('form.add_photos'), onTap: () => _pick(ImageSource.gallery)),
              if (!pics.any((p) => p.isVideo)) _AddTile(icon: Icons.videocam_rounded, label: context.t('form.add_video'), onTap: _pickVideo),
            ]),
          ),
          const SizedBox(height: 22),
          field(_title, context.t('form.title'), hint: context.t('form.title_ph'), validator: (v) => (v ?? '').trim().length < 5 ? context.t('form.err_invalid') : null, maxLength: 120),
          DropdownButtonFormField<int>(
            initialValue: catItems.any((e) => e.value == categoryId) ? categoryId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.t('common.category')),
            items: catItems,
            onChanged: (v) => setState(() => categoryId = v),
            validator: (v) => v == null ? context.t('form.err_invalid') : null,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: brandId,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.t('common.brand')),
                items: [DropdownMenuItem<int?>(value: null, child: Text('—')), for (final b in brands) DropdownMenuItem(value: b.id, child: Text(b.name))],
                onChanged: (v) => setState(() => brandId = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: field(_model, context.t('listing.model'), hint: context.t('form.product'))),
          ]),
          const SizedBox(height: 4),
          Text(context.t('listing.condition'), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final c in conditions) ChoiceChip(label: Text(context.t('cond.$c')), selected: condition == c, onSelected: (_) => setState(() => condition = c))]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: field(_price, context.t('common.price'), hint: context.t('form.price_place'), type: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (parseNum(v) ?? -1) < 0 ? context.t('form.err_invalid') : null)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: InputDecoration(labelText: context.t('common.currency')),
                items: [for (final c in {'XOF', 'GNF', 'EUR', 'USD', 'NGN', 'GHS', if (cur != null) cur}) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => currency = v ?? currency),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: field(_qty, context.t('listing.quantity'), type: TextInputType.number, validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) < 1 ? context.t('form.err_invalid') : null)),
          ]),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: countries.any((c) => c.code == country) ? country : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.t('common.country')),
                items: [for (final c in countries) DropdownMenuItem(value: c.code, child: Text(c.name(lang)))],
                onChanged: (v) => setState(() {
                  country = v ?? country;
                  final c = countries.where((x) => x.code == country).firstOrNull;
                  if (c != null) currency = c.currency;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Autocomplete<String>(
                initialValue: TextEditingValue(text: _city.text),
                optionsBuilder: (t) => cities.map((c) => c.name).where((n) => n.toLowerCase().contains(t.text.toLowerCase())),
                onSelected: (v) => _city.text = v,
                fieldViewBuilder: (c, ctl, fn, _) => TextFormField(controller: ctl, focusNode: fn, onChanged: (v) => _city.text = v, decoration: InputDecoration(labelText: context.t('common.city'))),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          field(_desc, context.t('listing.description'), lines: 5, maxLength: 4000),
          field(_defects, context.t('listing.defects'), hint: context.t('form.defects_hint'), lines: 2),
          field(_warranty, context.t('listing.warranty')),
          Container(
            decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              SwitchListTile(title: Text(context.t('form.delivery')), value: delivery, onChanged: (v) => setState(() => delivery = v)),
              SwitchListTile(title: Text(context.t('form.negotiable')), value: negotiable, onChanged: (v) => setState(() => negotiable = v)),
              SwitchListTile(title: Text(context.t('form.exchange')), value: exchange, onChanged: (v) => setState(() => exchange = v)),
              AnimatedSize(duration: Motion.base, child: exchange ? Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: field(_exWanted, context.t('form.exchange_wanted'))) : const SizedBox(width: double.infinity)),
            ]),
          ),
          if (shops.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              initialValue: shopId,
              decoration: InputDecoration(labelText: context.t('form.publish_as')),
              items: [DropdownMenuItem<String?>(value: null, child: Text(context.t('form.as_individual'))), for (final s in shops) DropdownMenuItem(value: s.id, child: Text(s.name))],
              onChanged: (v) => setState(() => shopId = v),
            ),
          ],
          const SizedBox(height: 10),
          Text(context.t('form.moderation_note'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          GradientButton(label: context.t('form.publish'), icon: Icons.rocket_launch_rounded, loading: busy, onPressed: () => _save(true)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: busy ? null : () => _save(false), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(context.t('form.save_draft'))),
        ]),
      ),
    );
  }
}

final _myShopsProvider = FutureProvider.autoDispose<List<Shop>>((ref) {
  ref.watch(uidProvider);
  return Repo.myShops();
});

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: cs.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.primary.withValues(alpha: .4), width: 1.4)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: cs.primary), const SizedBox(height: 4), Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w700)))]),
      ),
    );
  }
}
