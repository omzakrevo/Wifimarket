import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

const reportReasons = ['fraud', 'stolen', 'prohibited', 'counterfeit', 'spam', 'harassment', 'wrong_category', 'other'];

Future<void> showReportSheet(BuildContext context, WidgetRef ref, String type, String target) async {
  if (!requireLogin(context, ref)) return;
  String reason = 'fraud';
  final details = TextEditingController();
  bool busy = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ctx.t('listing.report'), style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in reportReasons) ChoiceChip(label: Text(ctx.t('report.r.$r')), selected: reason == r, onSelected: (_) => set(() => reason = r)),
            ]),
            const SizedBox(height: 14),
            TextField(controller: details, maxLines: 3, decoration: InputDecoration(labelText: ctx.t('report.details'))),
            const SizedBox(height: 16),
            GradientButton(
              label: ctx.t('report.send'),
              loading: busy,
              onPressed: () async {
                set(() => busy = true);
                try {
                  await Repo.report(type, target, reason, details.text.trim().isEmpty ? null : details.text.trim());
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    toast(context, ctx.t('report.sent'));
                  }
                } catch (e) {
                  set(() => busy = false);
                  if (ctx.mounted) toast(ctx, errMsg(ctx, e), error: true);
                }
              },
            ),
          ]),
        ),
      ),
    ),
  );
  details.dispose();
}
