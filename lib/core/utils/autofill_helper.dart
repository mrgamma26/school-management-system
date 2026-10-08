import 'package:flutter/material.dart';

/// Autofill hint string constants for native form autofill support
class AutofillHintStrings {
  /// Email address
  static const String email = 'email';

  /// Password
  static const String password = 'password';

  /// First name
  static const String givenName = 'givenName';

  /// Last name
  static const String familyName = 'familyName';

  /// Full name
  static const String fullName = 'name';

  /// Phone number
  static const String phone = 'telephoneNumber';

  /// Street address
  static const String streetAddress = 'streetAddressLine1';

  /// City/Town
  static const String city = 'addressCity';

  /// State/Province
  static const String state = 'addressState';

  /// Postal code/ZIP
  static const String postalCode = 'postalCode';

  /// Country
  static const String country = 'countryName';

  /// URL/Website
  static const String url = 'url';

  /// Date of birth
  static const String dateOfBirth = 'birthdate';

  /// One-time code (for OTP)
  static const String oneTimeCode = 'oneTimeCode';

  /// Username
  static const String username = 'username';

  /// Disable autofill
  static const String none = '';
}

/// TextField with autofill support
class AutofillTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String autofillHint;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final InputDecoration? decoration;
  final TextCapitalization textCapitalization;

  const AutofillTextField({
    this.controller,
    this.label,
    this.hint,
    this.autofillHint = '',
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.decoration,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  @override
  State<AutofillTextField> createState() => _AutofillTextFieldState();
}

class _AutofillTextFieldState extends State<AutofillTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofillHints: widget.autofillHint.isNotEmpty
          ? [widget.autofillHint]
          : null,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      obscureText: widget.obscureText,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onEditingComplete: () {
        if (widget.textInputAction == TextInputAction.next) {
          FocusScope.of(context).nextFocus();
        } else if (widget.textInputAction == TextInputAction.done) {
          FocusScope.of(context).unfocus();
        }
      },
      decoration:
          widget.decoration ??
          InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            border: const OutlineInputBorder(),
          ),
    );
  }
}

/// Helper mixin to provide autofill helpers to forms
mixin AutofillFormMixin {
  /// Wrap form with AutofillGroup for coordinated autofill
  Widget buildWithAutofillGroup(Widget child) {
    return AutofillGroup(child: child);
  }
}
