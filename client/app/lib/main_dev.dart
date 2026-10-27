import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/app.dart';
import 'package:jiabu/features/catalog/catalog_screen.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerJiabuLicenses();
  runApp(const ProviderScope(child: JiabuApp(home: CatalogScreen())));
}
