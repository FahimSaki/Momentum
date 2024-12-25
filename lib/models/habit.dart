import 'package:isar/isar.dart';

// run cmd to genereate file : dart run build_runner build
part 'habit.g.dart';

@Collection()
class Habit {
  // habit id
  Id id = Isar.autoIncrement;

  // habit name

  late String name;

  // completed days
  List<DateTime> completedDays = [
    // DateTinme(year, month, day),
    // DateTime(2024, 12, 25),
    // DateTime(2024, 12, 26),
  ];
}
