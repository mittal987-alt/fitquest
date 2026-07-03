enum GearSlot { footwear, communication, optics }

class GearModel {
  final String id;
  final String name;
  final String description;
  final GearSlot slot;
  final Map<String, double> modifiers; // e.g., {"xp_mult": 1.05, "step_mult": 1.1}
  final int price;
  final String icon;

  GearModel({
    required this.id,
    required this.name,
    required this.description,
    required this.slot,
    required this.modifiers,
    required this.price,
    required this.icon,
  });

  factory GearModel.fromMap(Map<String, dynamic> map) {
    return GearModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      slot: GearSlot.values.firstWhere(
        (e) => e.toString() == 'GearSlot.${map['slot']}',
        orElse: () => GearSlot.footwear,
      ),
      modifiers: Map<String, double>.from(map['modifiers'] ?? {}),
      price: map['price'] ?? 0,
      icon: map['icon'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'slot': slot.toString().split('.').last,
      'modifiers': modifiers,
      'price': price,
      'icon': icon,
    };
  }
}

// Predefined Gear List (Static for now)
final List<GearModel> allGear = [
  GearModel(
    id: 'boots_01',
    name: 'Standard Issue Boots',
    description: '+5% XP Gain from all sources.',
    slot: GearSlot.footwear,
    modifiers: {'xp_mult': 1.05},
    price: 500,
    icon: 'boot_icon',
  ),
  GearModel(
    id: 'recon_sneakers',
    name: 'Recon Sneakers',
    description: '+10% Step efficiency during morning hours.',
    slot: GearSlot.footwear,
    modifiers: {'step_mult': 1.10},
    price: 1200,
    icon: 'shoe_icon',
  ),
  GearModel(
    id: 'thermal_goggles',
    name: 'Thermal Goggles',
    description: 'Increases Bounty detection radius by 50%.',
    slot: GearSlot.optics,
    modifiers: {'bounty_radius': 1.5},
    price: 2000,
    icon: 'goggles_icon',
  ),
  GearModel(
    id: 'comm_link',
    name: 'Field Comm Link',
    description: '+10% XP when participating in Global Events.',
    slot: GearSlot.communication,
    modifiers: {'event_xp_mult': 1.1},
    price: 1500,
    icon: 'radio_icon',
  ),
];
