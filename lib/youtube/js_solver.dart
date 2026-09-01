import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_explode_dart/js_challenge.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'catalog.dart';

/// Runs youtube_explode's n-sig / signature solver in the Android WebView.
/// That is the same kind of player JS YouTube already ships — not a custom bypass.
class WebViewEjsSolver extends BaseEJSSolver {
  WebViewEjsSolver(this.controller);

  final WebViewController controller;

  @override
  Future<String> executeJavaScript(String jsCode) async {
    final result = await controller.runJavaScriptReturningResult(jsCode);
    return _asJsonString(result);
  }
}

String _asJsonString(Object? result) {
  if (result == null) {
    throw Exception('WebView returned no JS result');
  }
  if (result is Map || result is List) {
    return json.encode(result);
  }
  var text = result.toString();
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    try {
      final decoded = json.decode(text);
      if (decoded is String) {
        return decoded;
      }
    } catch (_) {}
  }
  return text;
}

class CatalogBoot extends StatefulWidget {
  const CatalogBoot({super.key, required this.builder});

  final Widget Function(BuildContext context, YoutubeCatalog catalog) builder;

  @override
  State<CatalogBoot> createState() => _CatalogBootState();
}

class _CatalogBootState extends State<CatalogBoot> {
  late final WebViewController _controller;
  YoutubeCatalog? _catalog;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_start());
  }

  Future<void> _start() async {
    await WidgetsBinding.instance.endOfFrame;
    WebViewEjsSolver? solver;
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      final loaded = Completer<void>();
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!loaded.isCompleted) {
              loaded.complete();
            }
          },
        ),
      );
      await _controller.loadHtmlString(
        '<!DOCTYPE html><html><body></body></html>',
      );
      await loaded.future.timeout(const Duration(seconds: 8));
      final modules = await EJSBuilder.getJSModules();
      await _controller.runJavaScript(modules);
      solver = WebViewEjsSolver(_controller);
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _catalog = YoutubeCatalog(
        explode: YoutubeExplode(jsSolver: solver),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned(
            width: 1,
            height: 1,
            child: Opacity(
              opacity: 0,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          if (catalog != null)
            widget.builder(context, catalog)
          else
            const ColoredBox(
              color: Color(0xFF0F0F0F),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
