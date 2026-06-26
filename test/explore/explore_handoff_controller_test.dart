import 'package:flutter_test/flutter_test.dart';
import 'package:genui_template/explore/explore_handoff_controller.dart';

void main() {
  test('ExploreHandoffController emits a new handoff for repeated queries', () {
    final controller = ExploreHandoffController();
    addTearDown(controller.dispose);

    controller.open('Explore near SFO');
    final first = controller.value;

    controller.open('Explore near SFO');
    final second = controller.value;

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second!.query, first!.query);
    expect(second.id, isNot(first.id));
  });
}
