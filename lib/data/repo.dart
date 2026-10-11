import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

SupabaseClient get sb => Supabase.instance.client;
String? get myId => sb.auth.currentUser?.id;
const _uuid = Uuid();

const listingSelect =
    '*, listing_media(storage_path,kind,position), categories(slug,name_fr,name_en,icon), brands(name,slug), profiles!listings_seller_id_fkey(id,display_name,avatar_url,verification_status,created_at)';

/// Traduit une erreur Supabase/Postgres en clé i18n `err.*`.
String errorKey(Object e) {
  final msg = e is PostgrestException ? e.message : (e is AuthException ? e.message : e.toString());
  final m = RegExp(r'[a-z_]{3,}').firstMatch(msg.toLowerCase().replaceAll('exception:', ''));
  var k = m?.group(0) ?? 'generic';
  if (e is AuthException) {
    final l = msg.toLowerCase();
    if (l.contains('invalid login')) return 'auth.err.invalid_credentials';
    if (l.contains('not confirmed')) return 'auth.err.email_not_confirmed';
    if (l.contains('already')) return 'auth.err.already_registered';
    if (l.contains('rate') || l.contains('seconds')) return 'auth.err.rate_limit';
    if (l.contains('weak') || l.contains('password')) return 'auth.err.weak_password';
    return 'auth.err.generic';
  }
  if (msg.contains('row-level security')) return 'err.not_allowed';
  if (msg.contains('Failed host lookup') || msg.contains('SocketException') || msg.contains('ClientException')) return 'offline.title';
  k = 'err.$k';
  return k;
}

class Repo {
  Repo._();

  // ---------- référentiels
  static Future<List<Category>> categories() async =>
      (await sb.from('categories').select().eq('enabled', true).order('sort_order')).map<Category>(Category.fromJson).toList();
  static Future<List<Brand>> brands() async =>
      (await sb.from('brands').select().eq('enabled', true).order('name')).map<Brand>(Brand.fromJson).toList();
  static Future<List<ProductModel>> models(int brandId) async =>
      (await sb.from('product_models').select('id,brand_id,name').eq('brand_id', brandId).order('name')).map<ProductModel>(ProductModel.fromJson).toList();
  static Future<List<Country>> countries() async =>
      (await sb.from('countries').select().eq('enabled', true).order('sort_order')).map<Country>(Country.fromJson).toList();
  static Future<List<City>> cities() async =>
      (await sb.from('cities').select().order('name')).map<City>(City.fromJson).toList();
  static Future<Map<String, dynamic>> settings() async {
    final rows = await sb.from('platform_settings').select('key,value');
    return {for (final r in rows) r['key'] as String: r['value']};
  }

  // ---------- annonces
  static Future<List<Listing>> search(SearchParams p, {int limit = 24, int offset = 0}) async {
    final ids = await sb.rpc('search_listings', params: {
      ...p.baseArgs(),
      'p_sort': p.sort,
      'p_limit': limit,
      'p_offset': offset,
    }) as List;
    if (ids.isEmpty) return [];
    final order = ids.map((e) => e['id'] as String).toList();
    final rows = await sb.from('listings').select(listingSelect).inFilter('id', order);
    final byId = {for (final r in rows) r['id'] as String: Listing.fromJson(r)};
    return [for (final id in order) if (byId[id] != null) byId[id]!];
  }

  static Future<int> count(SearchParams p) async => (await sb.rpc('count_listings', params: p.baseArgs())) as int;

  static Future<List<Listing>> latest({String? condition, String? country, bool sponsored = false, int limit = 12}) async {
    var q = sb.from('listings').select(listingSelect).eq('status', 'active');
    if (condition != null) q = q.eq('condition', condition);
    if (country != null) q = q.eq('country_code', country);
    if (sponsored) q = q.eq('is_sponsored', true).gte('sponsored_until', DateTime.now().toUtc().toIso8601String());
    final rows = await q.order('published_at', ascending: false).limit(limit);
    return rows.map<Listing>(Listing.fromJson).toList();
  }

  static Future<Listing?> listing(String id) async {
    final r = await sb.from('listings').select(listingSelect).eq('id', id).maybeSingle();
    return r == null ? null : Listing.fromJson(r);
  }

  static Future<List<Listing>> similar(Listing l) async {
    final rows = await sb
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active')
        .eq('category_id', l.categoryId)
        .neq('id', l.id)
        .order('published_at', ascending: false)
        .limit(8);
    return rows.map<Listing>(Listing.fromJson).toList();
  }

  static Future<List<Listing>> myListings() async {
    final rows = await sb.from('listings').select(listingSelect).eq('seller_id', myId!).order('created_at', ascending: false);
    return rows.map<Listing>(Listing.fromJson).toList();
  }

  static Future<void> view(String id) async {
    try {
      await sb.rpc('increment_listing_views', params: {'p_id': id});
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> attributes(String id) async {
    final rows = await sb.from('listing_attributes').select().eq('listing_id', id);
    return {for (final r in rows) r['key'] as String: r['value']};
  }

  static Future<void> setListingStatus(String id, String status) async => sb.from('listings').update({'status': status}).eq('id', id);
  static Future<void> renew(String id) async => sb.rpc('renew_listing', params: {'p_id': id});
  static Future<void> deleteListing(String id) async => sb.from('listings').delete().eq('id', id);

  /// Crée ou met à jour une annonce ; renvoie l'id. `data` utilise les noms de colonnes SQL.
  static Future<String> saveListing(String? id, Map<String, dynamic> data) async {
    if (id == null) {
      final r = await sb.from('listings').insert({...data, 'seller_id': myId!}).select('id').single();
      return r['id'] as String;
    }
    await sb.from('listings').update(data).eq('id', id);
    return id;
  }

  static Future<String> uploadListingMedia(String listingId, Uint8List bytes, String ext, String kind, int position) async {
    final safe = ext.toLowerCase().replaceAll('.', '');
    final path = '${myId!}/${_uuid.v4()}.$safe';
    final mime = kind == 'video' ? 'video/${safe == 'mov' ? 'quicktime' : safe}' : (safe == 'jpg' ? 'image/jpeg' : 'image/$safe');
    await sb.storage.from('listing-media').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    await sb.from('listing_media').insert({'listing_id': listingId, 'kind': kind, 'storage_path': path, 'position': position});
    return path;
  }

  static Future<void> deleteMedia(String path) async {
    await sb.from('listing_media').delete().eq('storage_path', path);
    try {
      await sb.storage.from('listing-media').remove([path]);
    } catch (_) {}
  }

  static Future<void> setCover(String listingId, List<Media> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      await sb.from('listing_media').update({'position': i}).eq('listing_id', listingId).eq('storage_path', ordered[i].path);
    }
  }

  // ---------- favoris & recherches
  static Future<Set<String>> favoriteIds() async {
    if (myId == null) return {};
    final rows = await sb.from('favorites').select('listing_id');
    return {for (final r in rows) r['listing_id'] as String};
  }

  static Future<List<Listing>> favorites() async {
    final rows = await sb.from('favorites').select('created_at, listings!inner($listingSelect)').order('created_at', ascending: false);
    return rows.map<Listing>((r) => Listing.fromJson(r['listings'] as Map<String, dynamic>)).toList();
  }

  static Future<void> toggleFavorite(String listingId, bool add) async {
    if (add) {
      await sb.from('favorites').upsert({'user_id': myId!, 'listing_id': listingId});
    } else {
      await sb.from('favorites').delete().eq('user_id', myId!).eq('listing_id', listingId);
    }
  }

  static Future<List<Map<String, dynamic>>> savedSearches() async =>
      List<Map<String, dynamic>>.from(await sb.from('saved_searches').select().order('created_at', ascending: false));

  static Future<void> saveSearch(SearchParams p, List<Category> cats, {String? label}) async {
    final cat = cats.where((c) => c.slug == p.category).firstOrNull;
    await sb.from('saved_searches').insert({
      'user_id': myId!,
      'label': label ?? ((p.q ?? '').isNotEmpty ? p.q : (cat?.nameFr ?? 'Recherche')),
      'query': p.q,
      'category_id': cat?.id,
      'country_code': p.country,
      'city': p.city,
      'condition': p.condition,
      'min_price': p.min,
      'max_price': p.max,
      'currency_code': p.currency,
      'notify': true,
    });
  }

  static Future<void> updateSavedSearch(String id, bool notify) async => sb.from('saved_searches').update({'notify': notify}).eq('id', id);
  static Future<void> deleteSavedSearch(String id) async => sb.from('saved_searches').delete().eq('id', id);

  // ---------- profils
  static Future<Profile?> profile(String id) async {
    final r = await sb.from('profiles').select().eq('id', id).maybeSingle();
    return r == null ? null : Profile.fromJson(r);
  }

  static Future<Map<String, dynamic>?> privateProfile() async =>
      myId == null ? null : await sb.from('private_profiles').select().eq('id', myId!).maybeSingle();

  static Future<void> updateProfile(Map<String, dynamic> pub, {String? whatsapp, bool touchWhatsapp = false}) async {
    if (pub.isNotEmpty) await sb.from('profiles').update(pub).eq('id', myId!);
    if (touchWhatsapp) await sb.from('private_profiles').upsert({'id': myId!, 'whatsapp_number': whatsapp});
  }

  static Future<String> uploadAvatar(Uint8List bytes, String ext) async {
    final path = '${myId!}/${_uuid.v4()}.${ext.toLowerCase()}';
    await sb.storage.from('avatars').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: 'image/${ext.toLowerCase() == 'jpg' ? 'jpeg' : ext.toLowerCase()}'));
    return sb.storage.from('avatars').getPublicUrl(path);
  }

  static Future<String?> whatsapp(String userId) async => (await sb.rpc('get_whatsapp', params: {'p_user': userId})) as String?;

  static Future<List<Map<String, dynamic>>> reviewsForSeller(String sellerId) async =>
      List<Map<String, dynamic>>.from(await sb
          .from('reviews')
          .select('id,rating,comment,created_at,profiles!reviews_reviewer_id_fkey(display_name,avatar_url)')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false)
          .limit(30));

  static Future<void> addReview({required String sellerId, required String orderId, String? listingId, String? shopId, required int rating, String? comment}) async =>
      sb.from('reviews').insert({'reviewer_id': myId!, 'seller_id': sellerId, 'order_id': orderId, 'listing_id': listingId, 'shop_id': shopId, 'rating': rating, 'comment': comment});

  // ---------- signalements, blocages
  static Future<void> report(String type, String target, String reason, String? details) async =>
      sb.from('reports').insert({'reporter_id': myId!, 'target_type': type, 'target_id': target, 'reason': reason, 'details': details});

  static Future<Set<String>> blockedIds() async {
    if (myId == null) return {};
    final rows = await sb.from('user_blocks').select('blocked_id').eq('blocker_id', myId!);
    return {for (final r in rows) r['blocked_id'] as String};
  }

  static Future<void> block(String id, bool on) async {
    if (on) {
      await sb.from('user_blocks').upsert({'blocker_id': myId!, 'blocked_id': id});
    } else {
      await sb.from('user_blocks').delete().eq('blocker_id', myId!).eq('blocked_id', id);
    }
  }

  // ---------- messagerie
  static Future<String> startConversation(String other, {String? listing, String? request}) async =>
      (await sb.rpc('start_conversation', params: {'p_other': other, 'p_listing': listing, 'p_request': request})) as String;

  static Future<List<Map<String, dynamic>>> conversations() async {
    final rows = await sb
        .from('conversations')
        .select('id,user_a,user_b,listing_id,request_id,last_message_at,listings(title,listing_media(storage_path,kind,position)),wanted_requests(title)')
        .order('last_message_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>?> lastMessage(String conv) async =>
      await sb.from('messages').select('body,image_path,sender_id,read_at,created_at').eq('conversation_id', conv).order('created_at', ascending: false).limit(1).maybeSingle();

  static Future<int> unreadIn(String conv) async {
    final rows = await sb.from('messages').select('id').eq('conversation_id', conv).neq('sender_id', myId!).isFilter('read_at', null);
    return rows.length;
  }

  static Future<List<Map<String, dynamic>>> messages(String conv) async =>
      List<Map<String, dynamic>>.from(await sb.from('messages').select().eq('conversation_id', conv).order('created_at').limit(300));

  static Future<void> sendMessage(String conv, {String? body, String? imagePath}) async =>
      sb.from('messages').insert({'conversation_id': conv, 'sender_id': myId!, 'body': body, 'image_path': imagePath});

  static Future<String> uploadChatImage(String conv, Uint8List bytes, String ext) async {
    final path = '$conv/${myId!}/${_uuid.v4()}.${ext.toLowerCase()}';
    await sb.storage.from('chat-images').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: 'image/${ext.toLowerCase() == 'jpg' ? 'jpeg' : ext.toLowerCase()}'));
    return path;
  }

  static Future<String> chatImageUrl(String path) => sb.storage.from('chat-images').createSignedUrl(path, 3600);
  static Future<void> markRead(String conv) async => sb.rpc('mark_conversation_read', params: {'p_conv': conv});

  // ---------- notifications
  static Future<List<Map<String, dynamic>>> notifications() async =>
      List<Map<String, dynamic>>.from(await sb.from('notifications').select().order('created_at', ascending: false).limit(60));
  static Future<void> markNotif(String id) async => sb.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  static Future<void> markAllNotifs() async =>
      sb.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', myId!).isFilter('read_at', null);

  // ---------- demandes
  static Future<List<Map<String, dynamic>>> wanted({bool mine = false, String? country}) async {
    var q = sb.from('wanted_requests').select('*, categories(name_fr,name_en), brands(name), profiles!wanted_requests_requester_id_fkey(display_name,avatar_url)');
    if (mine) {
      q = q.eq('requester_id', myId!);
    } else {
      q = q.eq('status', 'open');
      if (country != null) q = q.eq('country_code', country);
    }
    return List<Map<String, dynamic>>.from(await q.order('created_at', ascending: false).limit(60));
  }

  static Future<Map<String, dynamic>?> wantedOne(String id) async =>
      await sb.from('wanted_requests').select('*, categories(name_fr,name_en), brands(name), profiles!wanted_requests_requester_id_fkey(id,display_name,avatar_url)').eq('id', id).maybeSingle();

  static Future<void> createWanted(Map<String, dynamic> d) async => sb.from('wanted_requests').insert({...d, 'requester_id': myId!});
  static Future<void> setWantedStatus(String id, String s) async => sb.from('wanted_requests').update({'status': s}).eq('id', id);

  static Future<List<Map<String, dynamic>>> offersFor(String requestId) async => List<Map<String, dynamic>>.from(await sb
      .from('wanted_offers')
      .select('*, profiles!wanted_offers_seller_id_fkey(id,display_name,avatar_url), listings(id,title)')
      .eq('request_id', requestId)
      .order('created_at', ascending: false));

  static Future<List<Map<String, dynamic>>> myOffers() async => List<Map<String, dynamic>>.from(await sb
      .from('wanted_offers')
      .select('*, wanted_requests(id,title)')
      .eq('seller_id', myId!)
      .order('created_at', ascending: false));

  static Future<void> sendOffer(Map<String, dynamic> d) async => sb.from('wanted_offers').insert({...d, 'seller_id': myId!});
  static Future<void> setOfferStatus(String id, String s) async => sb.from('wanted_offers').update({'status': s}).eq('id', id);

  // ---------- négociations
  static Future<List<Map<String, dynamic>>> negotiations() async => List<Map<String, dynamic>>.from(await sb
      .from('negotiations')
      .select('*, listings!negotiations_listing_id_fkey(id,title,price,currency_code,listing_media(storage_path,kind,position))')
      .order('updated_at', ascending: false));

  static Future<List<Map<String, dynamic>>> negotiationEvents(String id) async =>
      List<Map<String, dynamic>>.from(await sb.from('negotiation_events').select().eq('negotiation_id', id).order('created_at'));

  static Future<void> createNegotiation(Map<String, dynamic> d) async => sb.from('negotiations').insert({...d, 'buyer_id': myId!});
  static Future<void> negotiationRespond(String id, String action, {num? price, String? note}) async =>
      sb.rpc('negotiation_respond', params: {'p_id': id, 'p_action': action, 'p_price': price, 'p_note': note});
  static Future<void> negotiationConfirm(String id) async => sb.rpc('negotiation_confirm', params: {'p_id': id});

  // ---------- boutiques
  static Future<List<Shop>> shops({int limit = 24}) async =>
      (await sb.from('shops').select().eq('is_active', true).order('created_at', ascending: false).limit(limit)).map<Shop>(Shop.fromJson).toList();
  static Future<Shop?> shop(String idOrSlug) async {
    final r = await (isUuidLike(idOrSlug) ? sb.from('shops').select().eq('id', idOrSlug) : sb.from('shops').select().eq('slug', idOrSlug)).maybeSingle();
    return r == null ? null : Shop.fromJson(r);
  }

  static bool isUuidLike(String v) => RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false).hasMatch(v);

  static Future<List<Shop>> myShops() async {
    final rows = await sb.from('shop_members').select('shops(*)').eq('user_id', myId!);
    return rows.map<Shop>((r) => Shop.fromJson(r['shops'] as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> shopStats(String id) async => Map<String, dynamic>.from(await sb.rpc('shop_stats', params: {'p_shop': id}) as Map);
  static Future<void> createShop(Map<String, dynamic> d) async => sb.from('shops').insert({...d, 'owner_id': myId!});
  static Future<void> updateShop(String id, Map<String, dynamic> d) async => sb.from('shops').update(d).eq('id', id);
  static Future<String> uploadShopAsset(String shopId, Uint8List bytes, String ext) async {
    final path = '$shopId/${_uuid.v4()}.${ext.toLowerCase()}';
    await sb.storage.from('shop-assets').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: 'image/${ext.toLowerCase() == 'jpg' ? 'jpeg' : ext.toLowerCase()}'));
    return path;
  }

  static Future<void> requestVerification([String? shopId]) async => sb.rpc('request_verification', params: {'p_shop': shopId});
  static Future<List<Map<String, dynamic>>> plans(String kind) async =>
      List<Map<String, dynamic>>.from(await sb.from('plans').select().eq('kind', kind).eq('enabled', true));
  static Future<void> requestSubscription(String shopId, String plan) async => sb.from('subscriptions').insert({'shop_id': shopId, 'plan_code': plan});
  static Future<void> requestPromotion(String listingId, String plan) async =>
      sb.from('promotions').insert({'listing_id': listingId, 'plan_code': plan, 'requested_by': myId!});

  // ---------- panier, commandes
  static Future<List<Map<String, dynamic>>> cart() async => List<Map<String, dynamic>>.from(
      await sb.from('cart_items').select('quantity, listings!inner($listingSelect)').eq('user_id', myId!).order('added_at'));
  static Future<void> cartSet(String listing, int qty) async => sb.rpc('cart_set', params: {'p_listing': listing, 'p_qty': qty});

  static Future<List<Map<String, dynamic>>> shippingRules() async =>
      List<Map<String, dynamic>>.from(await sb.from('shipping_rules').select().eq('enabled', true));

  static Future<List<String>> placeOrder(String method, Map<String, dynamic>? address, String? payment, String? note) async {
    final r = await sb.rpc('place_order', params: {'p_delivery_method': method, 'p_address': address, 'p_payment_method': payment, 'p_note': note});
    return (r as List).map((e) => e.toString()).toList();
  }

  static Future<List<Map<String, dynamic>>> orders({required bool sales}) async => List<Map<String, dynamic>>.from(await sb
      .from('orders')
      .select('*, order_items(*), shipments(*), payments(status,provider,is_sandbox)')
      .eq(sales ? 'seller_id' : 'buyer_id', myId!)
      .order('created_at', ascending: false));

  static Future<Map<String, dynamic>?> order(String id) async => await sb
      .from('orders')
      .select('*, order_items(*), shipments(*), payments(status,provider,is_sandbox), reviews(id)')
      .eq('id', id)
      .maybeSingle();

  static Future<void> cancelOrder(String id, String? reason) async => sb.rpc('cancel_order', params: {'p_order': id, 'p_reason': reason});
  static Future<void> advanceOrder(String id, String status, {String? tracking, String? carrier}) async =>
      sb.rpc('advance_order', params: {'p_order': id, 'p_status': status, 'p_tracking': tracking, 'p_carrier': carrier});
  static Future<void> openDispute(String id, String reason) async => sb.rpc('open_dispute', params: {'p_order': id, 'p_reason': reason});

  // ---------- conformité
  static Future<Map<String, dynamic>?> deletionRequest() async => myId == null
      ? null
      : await sb.from('data_deletion_requests').select().eq('user_id', myId!).inFilter('status', ['pending', 'processing']).maybeSingle();
  static Future<void> requestDeletion(String? reason) async => sb.from('data_deletion_requests').insert({'user_id': myId!, 'reason': reason});

  // ---------- rôles / admin
  static Future<List<String>> myRoles() async {
    if (myId == null) return [];
    final rows = await sb.from('user_roles').select('role').eq('user_id', myId!);
    return rows.map<String>((r) => r['role'] as String).toList();
  }

  static Future<Map<String, dynamic>> adminStats() async => Map<String, dynamic>.from(await sb.rpc('admin_stats') as Map);

  /// Accès générique de lecture pour les écrans d'administration.
  static Future<List<Map<String, dynamic>>> table(String name, {String select = '*', String? order, bool asc = false, int limit = 100, Map<String, Object>? eq}) async {
    var q = sb.from(name).select(select);
    eq?.forEach((k, v) => q = q.eq(k, v));
    final r = order == null ? await q.limit(limit) : await q.order(order, ascending: asc).limit(limit);
    return List<Map<String, dynamic>>.from(r);
  }

  static Future<void> update(String table, String idCol, Object id, Map<String, dynamic> d) async => sb.from(table).update(d).eq(idCol, id);
  static Future<void> insert(String table, Map<String, dynamic> d) async => sb.from(table).insert(d);
  static Future<void> remove(String table, String idCol, Object id) async => sb.from(table).delete().eq(idCol, id);
}
