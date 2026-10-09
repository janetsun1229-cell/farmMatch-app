class StoreCopy {
  const StoreCopy._();

  static const title = 'Farm Stand';
  static const lead = 'The market is over. Clear the porch, then the barn.';
  static const room = 'More room';
  static const tools = 'Tool kits';
  static const quiet = 'Quiet play';
  static const yourTools = 'Your tools';
  static const owned = 'Owned';
  static const buy = 'Buy';
  static const notNow = 'Not now';

  static const blurbs = {
    'barn_bundle': 'Open the barn. Levels 21–35.',
    'harvest_bundle': 'Bring in the harvest. Levels 36–50.',
    'pack_small': '5 Move, 5 Undo, and 5 Shuffle.',
    'pack_medium': '12 of each tool.',
    'pack_large': '30 of each tool.',
    'remove_ads': 'Hide ads for good.',
  };

  static String blurb(String sku) => blurbs[sku] ?? '';

  static String get allText => [
        title,
        lead,
        room,
        tools,
        quiet,
        yourTools,
        owned,
        buy,
        notNow,
        ...blurbs.values
      ].join('\n');
}
