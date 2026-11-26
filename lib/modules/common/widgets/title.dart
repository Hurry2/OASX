import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:oasx/modules/server/index.dart';
import 'package:oasx/translation/i18n_content.dart';

Widget getTitle(BuildContext context, {String? routePath}) {
  final resolvedRoutePath = _resolveRoutePath(context, routePath: routePath);
  return switch (resolvedRoutePath) {
    '/settings' => const SettingTitle(),
    '/server' => const ServerTitle(),
    '/click-statistics' => const ClickStatisticsTitle(),
    _ => const HomeTitleBar(),
  };
}

String _resolveRoutePath(BuildContext context, {String? routePath}) {
  final explicitRoute = routePath?.trim() ?? '';
  if (explicitRoute.isNotEmpty) {
    return explicitRoute;
  }

  final routingCurrent = Get.routing.current;
  if (routingCurrent.isNotEmpty) {
    return routingCurrent;
  }

  final routeName = ModalRoute.of(context)?.settings.name;
  if (routeName != null && routeName.isNotEmpty) {
    return routeName;
  }
  return Get.currentRoute;
}

class HomeTitleBar extends StatelessWidget {
  const HomeTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return _BrandTitle(subtitle: I18n.home.tr);
  }
}

class SettingTitle extends StatelessWidget {
  const SettingTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final backButton = switch (Theme.of(context).platform) {
      TargetPlatform.android => false,
      TargetPlatform.iOS => false,
      _ => true,
    };
    return _BrandTitle(
      subtitle: I18n.setting.tr,
      leading: backButton ? BackButton(onPressed: _backHomeOrPop) : null,
    );
  }

  void _backHomeOrPop() {
    final canPop = Get.key.currentState?.canPop() ?? false;
    if (canPop || Get.previousRoute.isNotEmpty) {
      Get.back();
      return;
    }
    Get.offAllNamed('/home');
  }
}

class ServerTitle extends StatelessWidget {
  const ServerTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final backButton = switch (Theme.of(context).platform) {
      TargetPlatform.android => false,
      TargetPlatform.iOS => false,
      _ => true,
    };
    return _BrandTitle(
      subtitle: 'Server',
      leading: Obx(() {
        if (backButton &&
            !Get.find<ServerController>().isDeployLoading.value) {
          return const Row(
            mainAxisSize: MainAxisSize.min,
            children: [BackButton(), SizedBox(width: 6)],
          );
        }
        return const SizedBox.shrink();
      }),
    );
  }
}

class ClickStatisticsTitle extends StatelessWidget {
  const ClickStatisticsTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final backButton = switch (Theme.of(context).platform) {
      TargetPlatform.android => false,
      TargetPlatform.iOS => false,
      _ => true,
    };
    return _BrandTitle(
      subtitle: '热力图',
      leading: backButton ? BackButton(onPressed: _backHome) : null,
    );
  }

  void _backHome() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    } else {
      Get.offAllNamed('/home');
    }
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.subtitle, this.leading});

  final String subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(context).textTheme.titleSmall;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/images/Icon-app.png',
              height: 22,
              width: 22,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'OASX',
            style: baseStyle?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '·',
              style: baseStyle?.copyWith(
                color: scheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: baseStyle?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
