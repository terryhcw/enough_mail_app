import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_app/models/compose_data.dart';
import 'package:enough_mail_app/models/shared_data.dart';
import 'package:enough_mail_app/services/theme_service.dart';
import 'package:flutter/services.dart';

import '../locator.dart';
import '../routes.dart';
import 'background_service.dart';
import 'mail_service.dart';
import 'navigation_service.dart';

class AppService {
  static const _platform = const MethodChannel('app.channel.shared.data');
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;
  bool get isInBackground => (appLifecycleState != AppLifecycleState.resumed);
  Future Function(List<SharedData> sharedData)? onSharedData;

  void didChangeAppLifecycleState(AppLifecycleState state) async {
    print('AppLifecycleState = $state');
    appLifecycleState = state;
    switch (state) {
      case AppLifecycleState.resumed:
        locator<ThemeService>().checkForChangedTheme();
        final futures = [checkForShare(), locator<MailService>().resume()];
        await Future.wait(futures);
        break;
      case AppLifecycleState.inactive:
        // TODO: Check if AppLifecycleState.inactive needs to be handled
        break;
      case AppLifecycleState.paused:
        await locator<BackgroundService>().saveStateOnPause();
        break;
      case AppLifecycleState.detached:
        // TODO: Check if AppLifecycleState.detached needs to be handled
        break;
    }
  }

  Future checkForShare() async {
    if (Platform.isAndroid) {
      final shared = await _platform.invokeMethod("getSharedData");
      //print('checkForShare: received data: $shared');
      if (shared != null) {
        composeWithSharedData(shared);
      }
    }
  }

  Future<List<SharedData>> _collectSharedData(
      Map<dynamic, dynamic> shared) async {
    final sharedData = <SharedData>[];
    final String? mimeTypeText = shared['mimeType'];
    final mediaType = (mimeTypeText == null || mimeTypeText.contains('*'))
        ? null
        : MediaType.fromText(mimeTypeText);
    final int? length = shared['length'];
    final String? text = shared['text'];
    print('share text: "$text"');
    if (length != null && length > 0) {
      for (var i = 0; i < length; i++) {
        final String? filename = shared['name.$i'];
        final Uint8List? data = shared['data.$i'];
        final String? typeName = shared['type.$i'];
        final localMediaType = (typeName != 'null')
            ? MediaType.fromText(typeName!)
            : mediaType ?? MediaType.guessFromFileName(filename!);
        sharedData.add(SharedBinary(data, filename, localMediaType));
        print(
            'share: loaded ${localMediaType.text}  "$filename" with ${data?.length} bytes');
      }
    } else if (text != null) {
      if (text.startsWith('mailto:')) {
        final mailto = Uri.parse(text);
        sharedData.add(SharedMailto(mailto));
      } else {
        sharedData.add(SharedText(text, mediaType, subject: shared['subject']));
      }
    }
    return sharedData;
  }

  Future composeWithSharedData(Map<dynamic, dynamic> shared) async {
    final sharedData = await _collectSharedData(shared);
    if (sharedData.isEmpty) {
      return;
    }
    final callback = onSharedData;
    if (callback != null) {
      return callback(sharedData);
    } else {
      MessageBuilder builder;
      final firstData = sharedData.first;
      if (firstData is SharedMailto) {
        builder = MessageBuilder.prepareMailtoBasedMessage(firstData.mailto,
            locator<MailService>().currentAccount!.fromAddress);
      } else {
        builder = MessageBuilder();
        for (final data in sharedData) {
          data.addToMessageBuilder(builder);
        }
      }
      final composeData = ComposeData(null, builder, ComposeAction.newMessage);
      return locator<NavigationService>()
          .push(Routes.mailCompose, arguments: composeData, fade: true);
    }
  }
}
