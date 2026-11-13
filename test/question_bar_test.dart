import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbio/data/models/world_question.dart';
import 'package:orbio/data/repositories/question_store.dart';
import 'package:orbio/presentation/l10n_labels.dart';
import 'package:orbio/presentation/widgets/question_bar.dart';

void main() {
  testWidgets('QuestionBar can collapse into FAB and expand back', (tester) async {
    final store = QuestionStore();
    bool? collapsedState;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuestionBar(
            store: store,
            countries: const [],
            onCollapsedChanged: (c) => collapsedState = c,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially expanded: chevron down is present
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.text('All flags'), findsOneWidget);

    // Tap collapse button
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(collapsedState, isTrue);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Tap FAB to expand back
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    expect(collapsedState, isFalse);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('QuestionHistorySheet lists questions without item badges', (tester) async {
    final sampleQ = WorldQuestion(
      id: 'test-1',
      question: 'Which countries are the largest?',
      summary: 'The top 3 countries by surface area.',
      ordered: true,
      items: const [
        AnswerItem(code: 'RUS', badge: '17M km²'),
        AnswerItem(code: 'CAN', badge: '9.9M km²'),
      ],
      createdAt: DateTime.now(),
    );
    final store = QuestionStore(initialHistory: [sampleQ]);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuestionHistorySheet(
            store: store,
            countries: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The question is listed
    expect(find.text('Which countries are the largest?'), findsOneWidget);
    // The country item badges are NOT shown in the list
    expect(find.text('17M km²'), findsNothing);
    expect(find.text('9.9M km²'), findsNothing);
  });
}
