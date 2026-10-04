enum ModifierSelectionType {
  single,
  multiple,
}

class ModifierOption {
  final String id;
  final String name;
  final int priceAdjustment;
  final Map<String, double>? rawMaterialOverrides;
  final Map<String, double> rawMaterialAdditions;

  const ModifierOption({
    required this.id,
    required this.name,
    this.priceAdjustment = 0,
    this.rawMaterialOverrides,
    this.rawMaterialAdditions = const {},
  });

  ModifierOption copyWith({
    String? id,
    String? name,
    int? priceAdjustment,
    Map<String, double>? rawMaterialOverrides,
    Map<String, double>? rawMaterialAdditions,
  }) {
    return ModifierOption(
      id: id ?? this.id,
      name: name ?? this.name,
      priceAdjustment: priceAdjustment ?? this.priceAdjustment,
      rawMaterialOverrides: rawMaterialOverrides ?? this.rawMaterialOverrides,
      rawMaterialAdditions: rawMaterialAdditions ?? this.rawMaterialAdditions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModifierOption && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ModifierGroup {
  final String id;
  final String name;
  final ModifierSelectionType selectionType;
  final bool isRequired;
  final int minSelection;
  final int maxSelection;
  final List<ModifierOption> options;
  final String? defaultOptionId;
  final bool isEnabled;

  const ModifierGroup({
    required this.id,
    required this.name,
    this.selectionType = ModifierSelectionType.single,
    this.isRequired = false,
    this.minSelection = 0,
    this.maxSelection = 1,
    required this.options,
    this.defaultOptionId,
    this.isEnabled = true,
  });

  ModifierOption? get defaultOption {
    if (defaultOptionId != null) {
      try {
        return options.firstWhere((o) => o.id == defaultOptionId);
      } catch (_) {}
    }
    return isRequired && options.isNotEmpty ? options.first : null;
  }

  ModifierGroup copyWith({
    String? id,
    String? name,
    ModifierSelectionType? selectionType,
    bool? isRequired,
    int? minSelection,
    int? maxSelection,
    List<ModifierOption>? options,
    String? defaultOptionId,
    bool? isEnabled,
  }) {
    return ModifierGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      selectionType: selectionType ?? this.selectionType,
      isRequired: isRequired ?? this.isRequired,
      minSelection: minSelection ?? this.minSelection,
      maxSelection: maxSelection ?? this.maxSelection,
      options: options ?? this.options,
      defaultOptionId: defaultOptionId ?? this.defaultOptionId,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
