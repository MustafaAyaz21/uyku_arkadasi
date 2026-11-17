import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:uyku_arkadasi/main.dart';

void main() {
  testWidgets('Gece takip ayarları ve simülasyon görünür', (WidgetTester tester) async {
    await tester.pumpWidget(const UykuArkadasiApp());

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('İyi Geceler Modu'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Uyuyor'), findsOneWidget);
    expect(find.text('Henüz bir hareket yok.'), findsOneWidget);

    await tester.ensureVisible(find.text('YouTube simülasyonu'));
    await tester.pump();
    await tester.tap(find.text('YouTube simülasyonu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Şu an YouTube'da aktif"), findsWidgets);
    expect(find.text('Uyuyor'), findsNothing);

    await tester.ensureVisible(find.text('Instagram simülasyonu'));
    await tester.pump();
    await tester.tap(find.text('Instagram simülasyonu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Şu an Instagram'da aktif"), findsWidgets);
    expect(find.textContaining("YouTube'a giriş yaptı"), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
