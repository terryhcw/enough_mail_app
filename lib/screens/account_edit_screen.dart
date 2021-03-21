import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_app/locator.dart';
import 'package:enough_mail_app/models/account.dart';
import 'package:enough_mail_app/routes.dart';
import 'package:enough_mail_app/screens/base.dart';
import 'package:enough_mail_app/services/alert_service.dart';
import 'package:enough_mail_app/services/mail_service.dart';
import 'package:enough_mail_app/services/navigation_service.dart';
import 'package:enough_mail_app/util/validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AccountEditScreen extends StatefulWidget {
  final Account account;
  const AccountEditScreen({Key key, @required this.account}) : super(key: key);

  @override
  _AccountEditScreenState createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  TextEditingController accountNameController;
  TextEditingController userNameController;

  void _update() {
    setState(() {});
  }

  @override
  void initState() {
    widget.account.addListener(_update);
    accountNameController = TextEditingController(text: widget.account.name);
    userNameController = TextEditingController(text: widget.account.userName);
    super.initState();
  }

  @override
  void dispose() {
    widget.account.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Base.buildAppChrome(
      context,
      title: localizations.editAccountTitle(widget.account.name),
      subtitle: widget.account.email,
      content: buildEditContent(localizations, context),
    );
  }

  Widget buildEditContent(
      AppLocalizations localizations, BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: accountNameController,
              decoration: InputDecoration(
                labelText: localizations.addAccountNameOfAccountLabel,
                hintText: localizations.addAccountNameOfAccountHint,
              ),
              onChanged: (value) async {
                widget.account.name = value;
                await locator<MailService>().saveAccounts();
              },
            ),
            TextField(
              controller: userNameController,
              decoration: InputDecoration(
                labelText: localizations.addAccountNameOfUserLabel,
                hintText: localizations.addAccountNameOfUserHint,
              ),
              onChanged: (value) async {
                widget.account.userName = value;
                await locator<MailService>().saveAccounts();
              },
            ),
            if (locator<MailService>().hasUnifiedAccount) ...{
              CheckboxListTile(
                value: !widget.account.excludeFromUnified,
                onChanged: (value) async {
                  widget.account.excludeFromUnified = !value;
                  setState(() {});
                  await locator<MailService>()
                      .excludeAccountFromUnified(widget.account, !value);
                },
                title: Text(localizations.editAccountIncludeInUnifedLabel),
              ),
            },
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Text(
                  localizations.editAccountAliasLabel(widget.account.email)),
            ),
            if (widget.account.hasNoAlias) ...{
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(localizations.editAccountNoAliasesInfo,
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ),
            },
            for (final alias in widget.account.aliases) ...{
              Dismissible(
                key: ValueKey(alias),
                child: ListTile(
                  title: Text(alias.toString()),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AliasEditDialog(
                        isNewAlias: false,
                        alias: alias,
                        account: widget.account,
                      ),
                    );
                  },
                ),
                background:
                    Container(color: Colors.red, child: Icon(Icons.delete)),
                onDismissed: (direction) async {
                  await widget.account.removeAlias(alias);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          localizations.editAccountAliasRemoved(alias.email))));
                },
              ),
            },
            ListTile(
              leading: Icon(Icons.add),
              title: Text(localizations.editAccountAddAliasAction),
              onTap: () {
                var email = widget.account.email;
                email = email.substring(email.lastIndexOf('@'));
                final alias = MailAddress(widget.account.userName, email);
                showDialog(
                  context: context,
                  builder: (context) => AliasEditDialog(
                      isNewAlias: true, alias: alias, account: widget.account),
                );
              },
            ),
            // section to test plus alias support
            CheckboxListTile(
              value: widget.account.supportsPlusAliases,
              onChanged: null,
              title: Text(localizations.editAccountPlusAliasesSupported),
            ),
            //if (!widget.account.supportsPlusAliases) ...{
            ElevatedButton(
              child: Text(localizations.editAccountCheckPlusAliasAction),
              onPressed: () async {
                var result = await showDialog<bool>(
                  context: context,
                  builder: (context) =>
                      PlusAliasTestingDialog(account: widget.account),
                );
                if (result != null) {
                  widget.account.supportsPlusAliases = result;
                  locator<MailService>()
                      .markAccountAsTestedForPlusAlias(widget.account);
                  await locator<MailService>()
                      .saveAccount(widget.account.account);
                }
              },
            ),
            Divider(),
            ElevatedButton.icon(
                onPressed: () => locator<NavigationService>().push(
                    Routes.accountServerDetails,
                    arguments: widget.account),
                icon: Icon(Icons.edit),
                label: Text(localizations.editAccountServerSettingsAction)),
            Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton.icon(
                style: TextButton.styleFrom(backgroundColor: Colors.red),
                icon: Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
                label: Text(
                  localizations.editAccountDeleteAccountAction,
                  style: Theme.of(context)
                      .textTheme
                      .button
                      .copyWith(color: Colors.white),
                ),
                onPressed: () async {
                  final result = await locator<AlertService>()
                      .askForConfirmation(context,
                          title: localizations
                              .editAccountDeleteAccountConfirmationTitle,
                          query: localizations
                              .editAccountDeleteAccountConfirmationQuery(
                                  accountNameController.text),
                          action: localizations.actionDelete,
                          isDangerousAction: true);
                  if (result == true) {
                    final mailService = locator<MailService>();
                    await mailService.removeAccount(widget.account);
                    if (mailService.accounts.isEmpty) {
                      locator<NavigationService>()
                          .push(Routes.welcome, clear: true);
                    } else {
                      locator<NavigationService>().pop();
                    }
                  }
                },
              ),
            ),
            //}
          ],
        ),
      ),
    );
  }
}

class PlusAliasTestingDialog extends StatefulWidget {
  final Account account;
  PlusAliasTestingDialog({Key key, this.account}) : super(key: key);

  @override
  _PlusAliasTestingDialogState createState() => _PlusAliasTestingDialogState();
}

class _PlusAliasTestingDialogState extends State<PlusAliasTestingDialog> {
  bool isContinueAvailable = true;
  int step = 0;
  static const int _maxStep = 1;
  String generatedAliasAdddress;
  MimeMessage testMessage;

  @override
  void initState() {
    generatedAliasAdddress =
        locator<MailService>().generateRandomPlusAlias(widget.account);
    super.initState();
  }

  bool filter(MailEvent event) {
    if (event is MailLoadEvent) {
      final msg = event.message;
      if (msg.to?.length == 1 && msg.to.first.email == generatedAliasAdddress) {
        // this is the test message, plus aliases are supported
        widget.account.supportsPlusAliases = true;
        setState(() {
          isContinueAvailable = true;
          step++;
        });
        deleteMessage(msg);
        return true;
      } else if ((msg.getHeaderValue('auto-submitted') != null) &&
          (msg.isTextPlainMessage()) &&
          (msg.decodeContentText()?.contains(generatedAliasAdddress) ??
              false)) {
        // this is an automatic reply telling that the address is not available

        setState(() {
          isContinueAvailable = true;
          step++;
        });
        deleteMessage(msg);
        return true;
      }
    }
    return false;
  }

  Future<void> deleteMessage(MimeMessage msg) async {
    var mailClient = await locator<MailService>().getClientFor(widget.account);
    await mailClient.flagMessage(msg, isDeleted: true);
  }

  @override
  void dispose() async {
    super.dispose();
    var mailClient = await locator<MailService>().getClientFor(widget.account);
    mailClient.removeEventFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
          localizations.editAccountTestPlusAliasTitle(widget.account.name)),
      content: Stepper(
        onStepCancel: step == 3 ? null : () => Navigator.of(context).pop(),
        onStepContinue: !isContinueAvailable
            ? null
            : () async {
                if (step < _maxStep) {
                  step++;
                } else {
                  Navigator.of(context).pop(widget.account.supportsPlusAliases);
                }
                switch (step) {
                  case 1:
                    setState(() {
                      isContinueAvailable = false;
                    });
                    // send the email and wait for a response:
                    final msg = MessageBuilder.buildSimpleTextMessage(
                        widget.account.fromAddress,
                        [MailAddress(null, generatedAliasAdddress)],
                        'This is an automated message testing support for + aliases. Please ignore.',
                        subject: 'Testing + Alias');
                    testMessage = msg;
                    var mailClient = await locator<MailService>()
                        .getClientFor(widget.account);
                    mailClient.addEventFilter(filter);
                    mailClient.sendMessage(msg, appendToSent: false);
                    break;
                }
              },
        steps: [
          Step(
            title: Text(
                localizations.editAccountTestPlusAliasStepIntroductionTitle),
            content: Text(
              localizations.editAccountTestPlusAliasStepIntroductionText(
                  widget.account.name, generatedAliasAdddress),
              style: TextStyle(fontSize: 12),
            ),
            isActive: (step == 0),
          ),
          Step(
            title: Text(localizations.editAccountTestPlusAliasStepTestingTitle),
            content: Center(child: CircularProgressIndicator()),
            isActive: (step == 1),
          ),
          Step(
            title: Text(localizations.editAccountTestPlusAliasStepResultTitle),
            content: widget.account.supportsPlusAliases
                ? Text(localizations.editAccountTestPlusAliasStepResultSuccess(
                    widget.account.name))
                : Text(
                    localizations.editAccountTestPlusAliasStepResultNoSuccess(
                        widget.account.name)),
            isActive: (step == 3),
            state: StepState.complete,
          ),
        ],
        currentStep: step,
      ),
    );
  }
}

class AliasEditDialog extends StatefulWidget {
  final MailAddress alias;
  final Account account;
  final bool isNewAlias;
  AliasEditDialog(
      {Key key,
      @required this.isNewAlias,
      @required this.alias,
      @required this.account})
      : super(key: key);

  @override
  _AliasEditDialogState createState() => _AliasEditDialogState();
}

class _AliasEditDialogState extends State<AliasEditDialog> {
  TextEditingController nameController;
  TextEditingController emailController;
  bool isEmailValid = false;
  String errorMessage;
  bool isSaving = false;

  @override
  void initState() {
    nameController = TextEditingController(text: widget.alias.personalName);
    emailController = TextEditingController(text: widget.alias.email);
    isEmailValid = !widget.isNewAlias;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isNewAlias
          ? localizations.editAccountAddAliasTitle
          : localizations.editAccountEditAliasTitle),
      content:
          isSaving ? CircularProgressIndicator() : buildContent(localizations),
      actions: [
        TextButton(
          child: Text(localizations.actionCancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(widget.isNewAlias
              ? localizations.editAccountAliasAddAction
              : localizations.editAccountAliasUpdateAction),
          onPressed: isEmailValid
              ? () async {
                  setState(() {
                    isSaving = true;
                  });
                  widget.alias.email = emailController.text;
                  widget.alias.personalName = nameController.text;
                  await widget.account.addAlias(widget.alias);
                  Navigator.of(context).pop();
                }
              : null,
        ),
      ],
    );
  }

  Widget buildContent(AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          decoration: InputDecoration(
              labelText: localizations.editAccountEditAliasNameLabel,
              hintText: localizations.addAccountNameOfUserHint),
        ),
        TextField(
          controller: emailController,
          decoration: InputDecoration(
              labelText: localizations.editAccountEditAliasEmailLabel,
              hintText: localizations.editAccountEditAliasEmailHint),
          onChanged: (value) {
            bool isValid = Validator.validateEmail(value);
            final emailValue = value.toLowerCase();
            if (isValid) {
              final existingAlias = widget.account.aliases.firstWhere(
                  (e) => e.email.toLowerCase() == emailValue,
                  orElse: () => null);
              if (existingAlias != null && existingAlias != widget.alias) {
                setState(() {
                  errorMessage =
                      localizations.editAccountEditAliasDuplicateError(value);
                });
              } else if (errorMessage != null) {
                setState(() {
                  errorMessage = null;
                });
              }
            }
            if (isValid != isEmailValid) {
              setState(() {
                isEmailValid = isValid;
              });
            }
          },
        ),
        if (errorMessage != null) ...{
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
            ),
          ),
        },
      ],
    );
  }
}
