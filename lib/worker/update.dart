import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ollama_app/worker/desktop.dart';

import 'haptic.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:http/http.dart' as http;
import 'package:install_referrer/install_referrer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

const repoUrl = "https://github.com/JHubi1/ollama-app";

bool updateChecked = false;
bool updateLoading = false;
String updateStatus = "ok";
String? updateUrl;
String? latestVersion;
String? currentVersion;
String? updateChangeLog;
Future<bool> updatesSupported(Function setState,
    [bool takeAction = false]) async {
  var tmp = (await PackageInfo.fromPlatform()).version;
  setState(() {
    currentVersion = tmp;
  });
  bool returnValue = true;
  var installerApps = [
    "org.fdroid.fdroid",
    "org.gdroid.gdroid",
    "eu.bubu1.fdroidclassic",
    "in.sunilpaulmathew.izzyondroid",
    "com.looker.droidify",
    "com.machiav3lli.fdroid",
    "nya.kitsunyan.foxydroid"
  ];
  if (!desktopFeature()) {
    if ((await InstallReferrer.referrer !=
            InstallationAppReferrer.androidManually) ||
        (installerApps
            .contains((await InstallReferrer.app).packageName ?? ""))) {
      returnValue = false;
      // if (await InstallReferrer.referrer ==
      //     InstallationAppReferrer.androidDebug) {
      //   returnValue = true;
      // }
    }
    if (!repoUrl.startsWith("https://github.com")) {
      returnValue = false;
    }
  }

  if (!returnValue && takeAction) {
    setState(() {
      updateStatus = "notAvailable";
      updateLoading = false;
    });
  }
  return returnValue;
}

void checkUpdate(Function setState) async {
  try {
    setState(() {
      updateChecked = true;
      updateLoading = true;
    });

    if (!await updatesSupported(setState)) {
      setState(() {
        updateStatus = "notAvailable";
        updateLoading = false;
      });
      return;
    }

    var repo = repoUrl.split("/");

    currentVersion = (await PackageInfo.fromPlatform()).version;
    // currentVersion = "1.0.0";

    String? version;
    try {
      var request = await http
          .get(Uri.parse(
              "https://api.github.com/repos/${repo[3]}/${repo[4]}/releases"))
          .timeout(const Duration(seconds: 5));
      if (request.statusCode == 403) {
        setState(() {
          updateStatus = "rateLimit";
          updateLoading = false;
        });
        return;
      }
      version = jsonDecode(request.body)[0]["tag_name"];
      updateChangeLog = jsonDecode(request.body)[0]["body"];
      updateUrl = jsonDecode(request.body)[0]["html_url"];
    } catch (_) {
      setState(() {
        updateStatus = "error";
        updateLoading = false;
      });
      return;
    }

    latestVersion = version;
    updateStatus = "ok";

    setState(() {
      updateLoading = false;
    });
  } catch (e) {
    setState(() {
      updateStatus = "notAvailable";
      updateLoading = false;
    });
  }
}

void updateDialog(BuildContext context, Function title) {
  showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
            title:
                Text(AppLocalizations.of(context)!.settingsUpdateDialogTitle),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(AppLocalizations.of(context)!
                  .settingsUpdateDialogDescription),
              title(AppLocalizations.of(context)!.settingsUpdateChangeLog),
              Flexible(
                  child: SingleChildScrollView(
                      child: MarkdownBody(
                          data: updateChangeLog ?? "No changelog given.",
                          shrinkWrap: true)))
            ]),
            actions: [
              TextButton(
                  onPressed: () {
                    selectionHaptic();
                    Navigator.of(context).pop();
                  },
                  child: Text(AppLocalizations.of(context)!
                      .settingsUpdateDialogCancel)),
              TextButton(
                  onPressed: () {
                    selectionHaptic();
                    Navigator.of(context).pop();
                    launchUrl(
                        mode: LaunchMode.inAppBrowserView,
                        Uri.parse(updateUrl!));
                  },
                  child: Text(
                      AppLocalizations.of(context)!.settingsUpdateDialogUpdate))
            ]);
      });
}
