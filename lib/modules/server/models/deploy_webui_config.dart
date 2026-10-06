import 'dart:io';

import 'package:yaml/yaml.dart';

/// WebUI listener settings read from the OAS deploy YAML file.
///
/// OAS keeps its port in `config/deploy.yaml` under `Deploy.Webui.WebuiPort`
/// (see OAS `deploy/config.py`). The port is user-configurable, so the GUI must
/// follow that value instead of assuming a fixed one.
class DeployWebuiConfig {
  /// Creates a WebUI listener snapshot.
  const DeployWebuiConfig({required this.host, required this.port});

  /// Host OAS binds to; usually `0.0.0.0`.
  final String host;

  /// Port OAS listens on.
  final int port;

  /// Host OAS binds to when the deploy file omits it.
  static const String defaultHost = '0.0.0.0';

  /// Port OAS falls back to when the deploy file omits it.
  ///
  /// Mirrors `deploy/config.py:WebuiPort` so an unreadable deploy file still
  /// resolves to the same address OAS itself would use.
  static const int defaultPort = 22267;

  /// Settings used when the deploy file cannot be read.
  static const DeployWebuiConfig fallback = DeployWebuiConfig(
    host: defaultHost,
    port: defaultPort,
  );

  /// Base URL the GUI should dial for this deployment.
  ///
  /// A wildcard [host] (`0.0.0.0`, `::`) is a bind address rather than a
  /// dialable one, so loopback is substituted; a concrete host is honoured,
  /// because OAS then binds that interface only and loopback would not answer.
  String get baseUrl {
    final trimmed = host.trim();
    if (trimmed.isEmpty || _wildcardHosts.contains(trimmed)) {
      return 'http://127.0.0.1:$port';
    }
    return 'http://${_dialableHost(trimmed)}:$port';
  }

  /// Hosts that mean "every interface" rather than a reachable address.
  static const Set<String> _wildcardHosts = {'0.0.0.0', '::', '*', '::0'};

  /// Wraps a bare IPv6 literal in brackets so it can be used in a URL.
  static String _dialableHost(String host) {
    final isIpv6 = host.contains(':');
    if (!isIpv6 || host.startsWith('[')) {
      return host;
    }
    return '[$host]';
  }

  /// Reads the WebUI settings from `<rootPath>/config/deploy.yaml`.
  ///
  /// Never throws: a missing or malformed file yields [fallback], so callers do
  /// not have to guard the result.
  factory DeployWebuiConfig.read(String rootPath) {
    final normalized = rootPath.trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    try {
      final file = File('$normalized\\config\\deploy.yaml');
      if (!file.existsSync()) {
        return fallback;
      }
      final webui = _webuiSection(loadYaml(file.readAsStringSync()));
      return DeployWebuiConfig(
        host: _stringValue(webui['WebuiHost'], defaultHost),
        port: _intValue(webui['WebuiPort'], defaultPort),
      );
    } catch (_) {
      return fallback;
    }
  }

  static YamlMap _webuiSection(dynamic yaml) {
    if (yaml is! YamlMap) {
      return YamlMap.wrap({});
    }
    final deploy = yaml['Deploy'];
    if (deploy is! YamlMap) {
      return YamlMap.wrap({});
    }
    final webui = deploy['Webui'];
    if (webui is! YamlMap) {
      return YamlMap.wrap({});
    }
    return webui;
  }

  static String _stringValue(dynamic value, String fallback) {
    if (value == null) {
      return fallback;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }
    return text;
  }

  static int _intValue(dynamic value, int fallback) {
    if (value is int) {
      return value > 0 ? value : fallback;
    }
    final parsed = int.tryParse((value ?? '').toString().trim());
    return parsed != null && parsed > 0 ? parsed : fallback;
  }
}
