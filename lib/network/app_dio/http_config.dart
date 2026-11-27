import 'package:collection/collection.dart';
import 'package:dio/dio.dart';

// dio 配置项
class DioHttpConfig {
  const DioHttpConfig({
    this.baseUrl,
    this.proxy,
    this.cookiesPath,
    this.interceptors,
    this.domainFronting,
    this.sniBypassMode = 'standard',
    this.localProxy,
    this.sniGeneration = 0,
    this.connectTimeout = Duration.millisecondsPerMinute,
    this.sendTimeout = Duration.millisecondsPerMinute,
    this.receiveTimeout = Duration.millisecondsPerMinute,
    this.maxConnectionsPerHost,
    this.contentType = Headers.formUrlEncodedContentType,
  });

  final String? baseUrl;
  final String? proxy;
  final String? cookiesPath;
  final List<Interceptor>? interceptors;
  final int connectTimeout;
  final int sendTimeout;
  final int receiveTimeout;
  final bool? domainFronting;
  final String sniBypassMode;
  final String? localProxy;
  final int sniGeneration;
  final int? maxConnectionsPerHost;
  final String? contentType;

  DioHttpConfig copyWith({
    String? baseUrl,
    String? proxy,
    String? cookiesPath,
    List<Interceptor>? interceptors,
    int? connectTimeout,
    int? sendTimeout,
    int? receiveTimeout,
    bool? domainFronting,
    String? sniBypassMode,
    String? localProxy,
    int? sniGeneration,
    int? maxConnectionsPerHost,
    String? contentType,
  }) {
    return DioHttpConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      proxy: proxy ?? this.proxy,
      cookiesPath: cookiesPath ?? this.cookiesPath,
      interceptors: interceptors ?? this.interceptors,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      domainFronting: domainFronting ?? this.domainFronting,
      sniBypassMode: sniBypassMode ?? this.sniBypassMode,
      localProxy: localProxy ?? this.localProxy,
      sniGeneration: sniGeneration ?? this.sniGeneration,
      maxConnectionsPerHost:
          maxConnectionsPerHost ?? this.maxConnectionsPerHost,
      contentType: contentType ?? this.contentType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DioHttpConfig &&
        other.baseUrl == baseUrl &&
        other.proxy == proxy &&
        other.cookiesPath == cookiesPath &&
        const ListEquality<Interceptor>().equals(
          other.interceptors,
          interceptors,
        ) &&
        other.connectTimeout == connectTimeout &&
        other.sendTimeout == sendTimeout &&
        other.receiveTimeout == receiveTimeout &&
        other.domainFronting == domainFronting &&
        other.sniBypassMode == sniBypassMode &&
        other.localProxy == localProxy &&
        other.sniGeneration == sniGeneration &&
        other.maxConnectionsPerHost == maxConnectionsPerHost &&
        other.contentType == contentType;
  }

  @override
  int get hashCode => Object.hash(
        baseUrl,
        proxy,
        cookiesPath,
        interceptors == null ? null : Object.hashAll(interceptors!),
        connectTimeout,
        sendTimeout,
        receiveTimeout,
        domainFronting,
        sniBypassMode,
        localProxy,
        sniGeneration,
        maxConnectionsPerHost,
        contentType,
      );

  @override
  String toString() {
    return 'DioHttpConfig{baseUrl: $baseUrl, proxy: $proxy, cookiesPath: $cookiesPath, interceptors: $interceptors, connectTimeout: $connectTimeout, sendTimeout: $sendTimeout, receiveTimeout: $receiveTimeout, domainFronting: $domainFronting, sniBypassMode: $sniBypassMode, localProxy: $localProxy, sniGeneration: $sniGeneration, maxConnectionsPerHost: $maxConnectionsPerHost, contentType: $contentType}';
  }
}
