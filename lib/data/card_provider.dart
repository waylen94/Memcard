import 'package:flutter/widgets.dart';

import 'card_store.dart';

class CardProvider extends InheritedNotifier<CardStore> {
  const CardProvider({super.key, required CardStore store, required super.child}) : super(notifier: store);

  static CardStore of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<CardProvider>();
    assert(provider != null, 'CardProvider not found in context');
    return provider!.notifier!;
  }
}
