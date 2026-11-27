import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/ksu_buildings.dart';

/// Result of the picker: either a campus building or a free-text place.
class BuildingChoice {
  const BuildingChoice.building(KsuBuilding this.building) : custom = null;
  const BuildingChoice.custom(String this.custom) : building = null;

  final KsuBuilding? building;
  final String? custom;

  String get label => building?.name ?? custom ?? '';
}

/// Bottom sheet with a searchable list of campus buildings.
///
/// Every row shows the building number first (bold) and the building title
/// underneath in smaller text. Typing a number ("27"), part of a name or a
/// category filters the list. When [allowCustom] is set, a text that matches
/// no building can be used as a free-text place (e.g. "Bus stop outside").
Future<BuildingChoice?> showBuildingPicker(
  BuildContext context, {
  String? selected,
  String title = 'Choose a building',
  bool allowCustom = true,
}) {
  return showModalBottomSheet<BuildingChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _BuildingSheet(
      selected: selected,
      title: title,
      allowCustom: allowCustom,
    ),
  );
}

class _BuildingSheet extends StatefulWidget {
  const _BuildingSheet({
    required this.selected,
    required this.title,
    required this.allowCustom,
  });

  final String? selected;
  final String title;
  final bool allowCustom;

  @override
  State<_BuildingSheet> createState() => _BuildingSheetState();
}

class _BuildingSheetState extends State<_BuildingSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = [...searchKsuBuildings(_query)]
      ..sort((a, b) {
        final byNumber = a.number.compareTo(b.number);
        return byNumber != 0 ? byNumber : a.name.compareTo(b.name);
      });
    final typed = _query.trim();
    final offerCustom =
        widget.allowCustom &&
        typed.length >= 2 &&
        !results.any((b) => b.name.toLowerCase() == typed.toLowerCase());

    // The sheet takes 85% of the screen and shrinks above the keyboard.
    final height = MediaQuery.sizeOf(context).height * 0.85;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _search,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by number or name',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty && !offerCustom
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No building matches "$typed".',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: results.length + (offerCustom ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (offerCustom && i == 0) {
                          return _CustomRow(
                            text: typed,
                            onTap: () => Navigator.of(
                              context,
                            ).pop(BuildingChoice.custom(typed)),
                          );
                        }
                        final b = results[i - (offerCustom ? 1 : 0)];
                        return BuildingRow(
                          building: b,
                          selected: b.name == widget.selected,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(BuildingChoice.building(b)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the picker: number (bold) over title (small).
class BuildingRow extends StatelessWidget {
  const BuildingRow({
    super.key,
    required this.building,
    required this.onTap,
    this.selected = false,
  });

  final KsuBuilding building;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cat = building.categoryEnum;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Building ${building.number}, ${building.name}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: selected ? AppColors.primarySurfaceOf(context) : null,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(cat.icon, size: 20, color: cat.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      building.numberLabel,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      building.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.primaryOf(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomRow extends StatelessWidget {
  const _CustomRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentSurfaceOf(context),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.edit_location_alt_outlined,
                size: 20,
                color: AppColors.accentOf(context),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use "$text"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  Text(
                    'Another place, not in the list',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textSecondaryOf(context),
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

/// Form field that looks like a text field and opens [showBuildingPicker].
class BuildingField extends FormField<String> {
  BuildingField({
    super.key,
    required String label,
    required String value,
    required ValueChanged<BuildingChoice> onChanged,
    String hint = 'Select a building',
    bool allowCustom = true,
    super.validator,
    super.autovalidateMode,
    super.enabled,
  }) : super(
         initialValue: value,
         builder: (state) {
           final context = state.context;
           final current = value.trim();
           final b = findKsuBuildingByName(current);
           final hasError = state.hasError;
           // Matches the themed text fields: light-blue fill, no outline
           // unless there is an error to show.
           final border = hasError
               ? AppColors.errorFgOf(context)
               : Colors.transparent;

           Future<void> open() async {
             final choice = await showBuildingPicker(
               context,
               selected: current,
               title: label,
               allowCustom: allowCustom,
             );
             if (choice == null) return;
             state.didChange(choice.label);
             onChanged(choice);
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Padding(
                 padding: const EdgeInsets.only(bottom: 6),
                 child: Text(
                   label,
                   style: AppTextStyles.captionMedium.copyWith(
                     color: AppColors.textSecondaryOf(context),
                   ),
                 ),
               ),
               Semantics(
                 button: true,
                 label: '$label, ${current.isEmpty ? hint : current}',
                 child: InkWell(
                   borderRadius: BorderRadius.circular(16),
                   onTap: state.widget.enabled ? open : null,
                   child: Container(
                     constraints: const BoxConstraints(minHeight: 56),
                     padding: const EdgeInsets.symmetric(
                       horizontal: 16,
                       vertical: 8,
                     ),
                     decoration: BoxDecoration(
                       color: AppColors.primarySurfaceOf(context),
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: border),
                     ),
                     child: Row(
                       children: [
                         Icon(
                           b?.categoryEnum.icon ?? Icons.apartment_rounded,
                           size: 20,
                           color:
                               b?.categoryEnum.color ??
                               AppColors.textTertiaryOf(context),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: current.isEmpty
                               ? Text(
                                   hint,
                                   style: AppTextStyles.body.copyWith(
                                     color: AppColors.textTertiaryOf(context),
                                   ),
                                 )
                               : Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     if (b != null)
                                       Text(
                                         b.numberLabel,
                                         style: AppTextStyles.bodyMedium
                                             .copyWith(
                                               fontWeight: FontWeight.w600,
                                               color: AppColors.textPrimaryOf(
                                                 context,
                                               ),
                                             ),
                                       ),
                                     Text(
                                       current,
                                       maxLines: 2,
                                       overflow: TextOverflow.ellipsis,
                                       style: b != null
                                           ? AppTextStyles.micro.copyWith(
                                               color: AppColors.textSecondaryOf(
                                                 context,
                                               ),
                                             )
                                           : AppTextStyles.body.copyWith(
                                               color: AppColors.textPrimaryOf(
                                                 context,
                                               ),
                                             ),
                                     ),
                                   ],
                                 ),
                         ),
                         Icon(
                           Icons.unfold_more_rounded,
                           size: 20,
                           color: AppColors.textTertiaryOf(context),
                         ),
                       ],
                     ),
                   ),
                 ),
               ),
               if (hasError)
                 Padding(
                   padding: const EdgeInsets.only(top: 6, left: 4),
                   child: Text(
                     state.errorText ?? '',
                     style: AppTextStyles.caption.copyWith(
                       color: AppColors.errorFgOf(context),
                     ),
                   ),
                 ),
             ],
           );
         },
       );
}
