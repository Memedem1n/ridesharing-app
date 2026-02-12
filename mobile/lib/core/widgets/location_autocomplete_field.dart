import 'dart:async';
import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final Color iconColor;
  final ValueChanged<LocationSuggestion>? onSelected;
  final ValueChanged<String>? onTextChanged;
  final FormFieldValidator<String>? validator;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.iconColor,
    this.onSelected,
    this.onTextChanged,
    this.validator,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final _service = LocationService();
  final _focusNode = FocusNode();
  Timer? _debounce;
  Timer? _blurClearTimer;
  bool _loading = false;
  String _lastQuery = '';
  List<LocationSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _blurClearTimer?.cancel();
    _focusNode.removeListener(_handleFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocus() {
    _blurClearTimer?.cancel();
    if (_focusNode.hasFocus) return;
    // Delay clear slightly so tapping a suggestion is not swallowed by focus loss.
    _blurClearTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _focusNode.hasFocus) return;
      setState(() => _suggestions = []);
    });
  }

  void _clearSuggestions() {
    if (!mounted) return;
    setState(() {
      _suggestions = [];
      _loading = false;
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _loading = true);
    try {
      final results = await _service.search(query);
      if (!mounted || query != _lastQuery) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    } catch (_) {
      _clearSuggestions();
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    _lastQuery = query;
    if (query.length < 2) {
      _clearSuggestions();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(query);
    });
  }

  void _select(LocationSuggestion suggestion) {
    final city = suggestion.city.trim();
    widget.controller.text = city.isNotEmpty ? city : suggestion.displayName;
    widget.onSelected?.call(suggestion);
    setState(() => _suggestions = []);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          hintLocales: const [Locale('tr', 'TR')],
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            prefixIcon: Icon(widget.icon, color: widget.iconColor, size: 18),
            border: InputBorder.none,
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          validator: widget.validator,
          onChanged: (value) {
            widget.onTextChanged?.call(value);
            _onChanged(value);
          },
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassStroke),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.glassStroke),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                final city = suggestion.city.trim();
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place,
                      color: AppColors.primary, size: 18),
                  title: Text(
                    city.isNotEmpty ? city : suggestion.displayName,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                  ),
                  subtitle: city.isNotEmpty
                      ? Text(
                          suggestion.displayName,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        )
                      : null,
                  onTap: () => _select(suggestion),
                );
              },
            ),
          ),
        if (!_loading &&
            _focusNode.hasFocus &&
            _lastQuery.length >= 2 &&
            _suggestions.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassStroke),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.textSecondary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sonuc bulunamadi. Daha net sehir/ilce adi deneyin.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
