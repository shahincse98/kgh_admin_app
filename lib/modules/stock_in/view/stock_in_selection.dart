import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/stock_in_controller.dart';

/// Asks how stock-in lists should be deleted. Returns true to also take the
/// active entries' pieces out of the main stock, false to delete only the
/// records (e.g. old lists whose stock was already counted again by hand),
/// or null when cancelled. Without [anyActive] there is no stock to adjust,
/// so only a plain delete is offered.
Future<bool?> askDeleteStockInLists({
  required String title,
  required String summary,
  required bool anyActive,
  required String inactiveNote,
}) {
  final deleteStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    foregroundColor: Colors.white,
  );
  return Get.dialog<bool>(
    AlertDialog(
      title: Text(title),
      content: Text(
        '$summary\n\n'
        '${anyActive ? 'স্টক থেকেও বাদ দিলে এই পরিমাণ মেইন স্টক থেকে কমে যাবে। শুধু রেকর্ড মুছলে মেইন স্টক যেমন আছে তেমনই থাকবে।'.tr : inactiveNote}',
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('বাতিল'.tr)),
        if (anyActive) ...[
          OutlinedButton(
            onPressed: () => Get.back(result: false),
            child: Text('শুধু রেকর্ড মুছুন'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: deleteStyle,
            child: Text('স্টক থেকেও বাদ দিন'.tr),
          ),
        ] else
          ElevatedButton(
            onPressed: () => Get.back(result: false),
            style: deleteStyle,
            child: Text('হ্যাঁ, ডিলিট'.tr),
          ),
      ],
    ),
  );
}

/// Marking several stock-in lists on a list page and deleting them together.
/// Only lists the current search and filters still show are acted on, so
/// what is deleted is exactly what is seen marked.
mixin StockInListSelection<T extends StatefulWidget> on State<T> {
  StockInController get controller;

  bool selecting = false;
  bool _deleting = false;
  final Set<String> _selected = {};

  bool isSelected(StockInGroup g) => _selected.contains(g.key);

  List<StockInGroup> get selectedGroups =>
      controller.filteredGroups.where(isSelected).toList();

  void startSelecting([StockInGroup? first]) => setState(() {
    selecting = true;
    if (first != null) _selected.add(first.key);
  });

  void stopSelecting() => setState(() {
    selecting = false;
    _selected.clear();
  });

  void toggleSelected(StockInGroup g) => setState(() {
    if (!_selected.remove(g.key)) _selected.add(g.key);
  });

  void _toggleSelectAll(List<StockInGroup> visible, bool allSelected) =>
      setState(() {
        final keys = visible.map((g) => g.key);
        allSelected ? _selected.removeAll(keys) : _selected.addAll(keys);
      });

  /// Tap opens a list normally; while marking, it marks the list instead.
  /// A long press starts marking from that list.
  void onListTap(StockInGroup g, VoidCallback open) =>
      selecting ? toggleSelected(g) : open();

  void onListLongPress(StockInGroup g) =>
      selecting ? toggleSelected(g) : startSelecting(g);

  /// Shape of a list card: a marked list gets a coloured border.
  ShapeBorder selectionShape(StockInGroup g, ColorScheme scheme) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected(g)
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      );

  /// What sits at a card's right edge: a checkbox while marking, otherwise
  /// the usual arrow.
  Widget selectionTrailing(StockInGroup g) => selecting
      ? Checkbox(value: isSelected(g), onChanged: (_) => toggleSelected(g))
      : const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Icon(Icons.chevron_right_rounded, color: Colors.grey),
        );

  /// AppBar button that starts marking lists.
  Widget startSelectingButton() => IconButton(
    icon: const Icon(Icons.checklist_rounded),
    tooltip: 'লিস্ট সিলেক্ট করুন'.tr,
    onPressed: startSelecting,
  );

  PreferredSizeWidget selectionAppBar() => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close_rounded),
      tooltip: 'বাতিল'.tr,
      onPressed: _deleting ? null : stopSelecting,
    ),
    title: Obx(
      () => Text(
        '${selectedGroups.length} ${'টি লিস্ট সিলেক্টেড'.tr}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    actions: [
      Obx(() {
        final visible = controller.filteredGroups;
        final all = visible.isNotEmpty && visible.every(isSelected);
        return IconButton(
          icon: Icon(all ? Icons.deselect_rounded : Icons.select_all_rounded),
          tooltip: all ? 'সব বাদ দিন'.tr : 'সব সিলেক্ট'.tr,
          onPressed: _deleting || visible.isEmpty
              ? null
              : () => _toggleSelectAll(visible, all),
        );
      }),
      Obx(
        () => IconButton(
          icon: const Icon(Icons.delete_rounded),
          color: Colors.red.shade400,
          tooltip: 'সিলেক্ট করা লিস্ট ডিলিট'.tr,
          onPressed: _deleting || selectedGroups.isEmpty
              ? null
              : _confirmDeleteSelected,
        ),
      ),
    ],
    bottom: _deleting
        ? const PreferredSize(
            preferredSize: Size.fromHeight(3),
            child: LinearProgressIndicator(minHeight: 3),
          )
        : null,
  );

  Future<void> _confirmDeleteSelected() async {
    final groups = selectedGroups;
    // Whole lists, even entries the search or product filter hides.
    final targets = controller.entriesOfGroups(
      groups.map((g) => g.key).toSet(),
    );
    final qty = targets.fold(0, (s, e) => s + e.quantity);
    final adjustStock = await askDeleteStockInLists(
      title: 'সিলেক্ট করা লিস্ট ডিলিট করবেন?'.tr,
      summary:
          '${groups.length} ${'টি লিস্ট'.tr} • ${targets.length} '
          '${'টি প্রডাক্ট'.tr} | $qty pcs — '
          '${'লিস্টগুলো স্থায়ীভাবে মুছে যাবে'.tr}।',
      anyActive: targets.any((e) => e.active),
      inactiveNote: 'লিস্টগুলো ইনএকটিভ, তাই মেইন স্টক বদলাবে না।'.tr,
    );
    if (adjustStock == null) return;

    setState(() => _deleting = true);
    try {
      await controller.deleteEntries(targets, adjustStock: adjustStock);
      if (mounted) stopSelecting();
      Get.snackbar(
        '${groups.length} ${'টি লিস্ট ডিলিট হয়েছে'.tr}',
        adjustStock ? 'স্টক এডজাস্ট হয়েছে'.tr : 'মেইন স্টক বদলায়নি'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
      );
    } catch (_) {
      Get.snackbar(
        'ত্রুটি'.tr,
        'লিস্ট ডিলিট করা যায়নি'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    if (mounted) setState(() => _deleting = false);
  }
}
