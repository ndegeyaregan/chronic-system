import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanlam_chronic/widgets/common/app_button.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  group('AppButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(buildTestApp(
        AppButton(label: 'Login', onPressed: () {}),
      ));
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when isLoading is true',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        AppButton(label: 'Login', onPressed: () {}, isLoading: true),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Login'), findsNothing);
    });

    testWidgets('is tappable when onPressed is provided', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(buildTestApp(
        AppButton(label: 'Submit', onPressed: () => tapCount++),
      ));
      await tester.tap(find.byType(AppButton));
      expect(tapCount, 1);
    });

    testWidgets('renders outlined variant', (tester) async {
      await tester.pumpWidget(buildTestApp(
        AppButton(
          label: 'Cancel',
          onPressed: () {},
          variant: AppButtonVariant.outlined,
        ),
      ));
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('renders ghost variant', (tester) async {
      await tester.pumpWidget(buildTestApp(
        AppButton(
          label: 'Skip',
          onPressed: () {},
          variant: AppButtonVariant.ghost,
        ),
      ));
      expect(find.text('Skip'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });
}
