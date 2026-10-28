import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class SingleInputPage extends StatefulWidget {
  const SingleInputPage({
    Key? key,
    this.title,
    this.previousPageTitle,
    this.onValueChanged,
    this.initValue,
    this.suffixText,
    this.placeholder,
    this.maxLines,
  }) : super(key: key);
  final String? title;
  final String? previousPageTitle;
  final String? initValue;
  final ValueChanged<String>? onValueChanged;
  final String? suffixText;
  final String? placeholder;
  final int? maxLines;

  @override
  State<SingleInputPage> createState() => _SingleInputPageState();
}

class _SingleInputPageState extends State<SingleInputPage> {
  late final TextEditingController textController;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: widget.initValue);
    textController.addListener(_textChanged);
  }

  void _textChanged() => widget.onValueChanged?.call(textController.text);

  @override
  void dispose() {
    textController.removeListener(_textChanged);
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    logger.d('ehTheme.isDarkMode ${ehTheme.isDarkMode}');

    return RetainedDraft(
        controller: textController,
        child: NativeNavigationPage(
          chrome: NativePageChrome(title: widget.title ?? ''),
          child: CupertinoPageScaffold(
            backgroundColor: !ehTheme.isDarkMode
                ? CupertinoColors.secondarySystemBackground
                : null,
            navigationBar: NativeNavigationScope.isEnabled(context)
                ? null
                : CupertinoNavigationBar(
                    middle: Text(widget.title ?? ''),
                    // previousPageTitle: previousPageTitle,
                  ),
            child: CustomScrollView(
              slivers: [
                SliverSafeArea(
                  minimum: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: CupertinoTextField(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 8.0),
                        maxLines: widget.maxLines,
                        // minLines: 1,
                        suffix: widget.suffixText != null
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(widget.suffixText!),
                              )
                            : null,
                        // textInputAction: TextInputAction.done,
                        decoration: BoxDecoration(
                          color: ehTheme.textFieldBackgroundColor,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(8.0)),
                        ),
                        controller: textController,
                        placeholderStyle: const TextStyle(
                          fontWeight: FontWeight.w400,
                          color: CupertinoColors.placeholderText,
                          height: 1.25,
                        ),
                        placeholder: widget.placeholder,
                        clearButtonMode: OverlayVisibilityMode.editing,
                        autofocus: true,
                        style: const TextStyle(height: 1.25),
                        // onEditingComplete: () {
                        //   FocusScope.of(context).requestFocus(FocusNode());
                        // },
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ));
  }
}
