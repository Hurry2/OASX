import 'package:get/get.dart';
import 'package:oasx/modules/click_statistics/click_statistics_controller.dart';

class ClickStatisticsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ClickStatisticsController>(() => ClickStatisticsController());
  }
}
