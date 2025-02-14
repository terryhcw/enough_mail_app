import 'package:collection/collection.dart' show IterableExtension;
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_app/services/i18n_service.dart';
import 'package:enough_mail_app/services/mail_service.dart';
import 'package:enough_mail_app/services/navigation_service.dart';
import 'package:enough_mail_app/services/settings_service.dart';
import 'package:enough_mail_app/util/localized_dialog_helper.dart';
import 'package:enough_mail_app/widgets/button_text.dart';
import 'package:enough_mail_app/widgets/text_with_links.dart';
import 'package:enough_platform_widgets/enough_platform_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../locator.dart';
import '../routes.dart';
import 'base.dart';

class SettingsDefaultSenderScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _SettingsDefaultSenderScreenState();
  }
}

class _SettingsDefaultSenderScreenState
    extends State<SettingsDefaultSenderScreen> {
  late String _firstAccount;
  MailAddress? _selectedSender;
  late List<MailAddress?> _senders;

  @override
  void initState() {
    final senders = locator<MailService>()
        .getSenders()
        .map((sender) => sender.address)
        .toList();

    _firstAccount = locator<I18nService>()
        .localizations
        .defaultSenderSettingsFirstAccount(senders.first.email);
    _senders = [null, ...senders];
    _selectedSender = locator<SettingsService>().settings.defaultSender;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    final aliasInfo = localizations.defaultSenderSettingsAliasInfo;
    final accountSettings =
        localizations.defaultSenderSettingsAliasAccountSettings;
    final asIndex = aliasInfo.indexOf('[AS]');
    final aliasInfoParts = [
      TextLink(aliasInfo.substring(0, asIndex)),
      TextLink.callback(
        accountSettings,
        () => locator<NavigationService>().push(Routes.settingsAccounts),
      ),
      TextLink(aliasInfo.substring(asIndex + '[AS]'.length)),
    ];

    return Base.buildAppChrome(
      context,
      title: localizations.defaultSenderSettingsTitle,
      content: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.defaultSenderSettingsLabel,
                    style: theme.textTheme.caption),
                FittedBox(
                  child: PlatformDropdownButton<MailAddress>(
                    value: _selectedSender,
                    onChanged: (value) async {
                      setState(() {
                        _selectedSender = value;
                      });
                      locator<SettingsService>().settings.defaultSender = value;
                      await locator<SettingsService>().save();
                    },
                    selectedItemBuilder: (context) => _senders
                        .map(
                          (sender) => Text(sender?.toString() ?? _firstAccount),
                        )
                        .toList(),
                    items: _senders
                        .map(
                          (sender) => DropdownMenuItem(
                            value: sender,
                            child: Text(sender?.toString() ?? _firstAccount),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: TextWithNamedLinks(
                    parts: aliasInfoParts,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
