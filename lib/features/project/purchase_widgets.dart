import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../data/purchase.dart';

/// Opens a photo full screen with pinch-to-zoom.
void openPhoto(
  BuildContext context, {
  required String url,
  required String path,
  required String title,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: 300.ms,
      reverseTransitionDuration: 250.ms,
      pageBuilder: (_, _, _) => _PhotoViewer(url: url, path: path, title: title),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer(
      {required this.url, required this.path, required this.title});

  final String url;
  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Hero(
            tag: 'photo-$path',
            child: CachedNetworkImage(
              imageUrl: url,
              cacheKey: path,
              fit: BoxFit.contain,
              placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined,
                  color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

class PurchaseTile extends StatelessWidget {
  const PurchaseTile({super.key, required this.purchase, required this.urls});

  final Purchase purchase;
  final Map<String, String> urls;

  @override
  Widget build(BuildContext context) {
    final p = purchase;
    final thumbPath = p.itemPhotoPath ?? p.receiptPath;
    final thumbUrl = thumbPath == null ? null : urls[thumbPath];
    final receiptUrl = p.receiptPath == null ? null : urls[p.receiptPath];
    final subtitle = [
      if ((p.shopName ?? '').isNotEmpty) p.shopName!,
      arDate(p.purchasedAt),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF0F4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: thumbUrl == null
                ? null
                : () => openPhoto(context,
                    url: thumbUrl, path: thumbPath!, title: p.itemName),
            child: HeroMode(
              // Only photos with a real path take part in the Hero flight.
              enabled: thumbPath != null,
              child: Hero(
              tag: 'photo-${thumbPath ?? p.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: thumbUrl == null
                      ? Container(
                          color: const Color(0xFFFEF3C7),
                          child: const Icon(Icons.inventory_2_outlined,
                              color: Color(0xFF92400E)),
                        )
                      : CachedNetworkImage(
                          imageUrl: thumbUrl,
                          cacheKey: thumbPath,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: const Color(0xFFEEF0F4),
                          )
                              .animate(onPlay: (c) => c.repeat())
                              .shimmer(duration: 1200.ms),
                          errorWidget: (_, _, _) => Container(
                            color: const Color(0xFFEEF0F4),
                            child: const Icon(Icons.broken_image_outlined,
                                color: AppColors.muted),
                          ),
                        ),
                ),
              ),
            ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${qty(p.quantity)} × ${money(p.unitPrice)}',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF667085))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(p.total),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (receiptUrl != null)
                Material(
                  color: const Color(0xFFF9FAFB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE0E4EA)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => openPhoto(context,
                        url: receiptUrl,
                        path: p.receiptPath!,
                        title: 'فاتورة: ${p.itemName}'),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 14, color: Color(0xFF344054)),
                          SizedBox(width: 4),
                          Text('الفاتورة',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF344054))),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Red background revealed when swiping an item to delete it.
Widget deleteBackground() => Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE4E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child:
          const Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318)),
    );
