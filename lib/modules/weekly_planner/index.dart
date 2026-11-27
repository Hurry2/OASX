import 'package:get/get.dart';
import 'package:oasx/modules/weekly_planner/weekly_planner_controller.dart';

export 'weekly_planner_controller.dart';
export 'weekly_planner_view.dart';

class WeeklyPlannerBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<WeeklyPlannerController>()) {
      Get.put<WeeklyPlannerController>(WeeklyPlannerController(), permanent: true);
    }
  }
}
