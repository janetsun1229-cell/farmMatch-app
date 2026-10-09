/// Fifteen farm items in Add Order. Asset ids match the HTML prototype.
enum ItemType {
  scissors('scissors', 'Scissors'),
  bucket('bucket', 'Bucket'),
  brush('brush', 'Brush'),
  carrot('carrot', 'Carrot'),
  gloves('gloves', 'Gloves'),
  corn('corn', 'Corn'),
  wool('wool', 'Wool'),
  milk('milk', 'Milk'),
  hay('hay', 'Hay'),
  pitchfork('fork', 'Pitchfork'),
  pumpkin('pumpkin', 'Pumpkin'),
  apple('apple', 'Apple'),
  mower('mower', 'Mower'),
  boots('boots', 'Boots'),
  wateringCan('can', 'Watering Can');

  const ItemType(this.id, this.label);

  final String id;
  final String label;

  static const List<ItemType> addOrder = ItemType.values;

  static ItemType byId(String id) {
    for (final type in ItemType.values) {
      if (type.id == id) return type;
    }
    throw ArgumentError('Unknown item id: $id');
  }

  String get assetPath => 'assets/images/items/$id.png';
}
