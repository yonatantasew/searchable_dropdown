library searchable_dropdown;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

class SearchableRequestDropdown<T> extends StatefulWidget {
  final String? hintText;
  final bool enabled;
  final List<String>? items;
  final String? Function(String?)? validator;
  final void Function(String?) onChanged;
  final InputDecoration? decoration;
  final Future<List<String>> Function(String) suggestionsCallback;

  const SearchableRequestDropdown({
    Key? key,
    this.hintText,
    this.enabled = true,
    this.items,
    this.validator,
    required this.onChanged,
    this.decoration,
    required this.suggestionsCallback,
  }) : super(key: key);

  @override
  _SearchableRequestDropdownState<T> createState() =>
      _SearchableRequestDropdownState<T>();
}

class _SearchableRequestDropdownState<T>
    extends State<SearchableRequestDropdown<T>> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  List<String> _suggestions = [];
  bool _isLoading = false;
  OverlayEntry? _suggestionsOverlayEntry;
  OverlayEntry? _loadingOverlayEntry;
  Timer? _debounce; // Timer for the debouncer
  final Duration _debounceDuration =
      Duration(milliseconds: 300); // Debounce interval

  @override
  void initState() {
    super.initState();

    // Trigger suggestions when the TextField is focused
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.enabled) {
        _fetchSuggestions('');
      } else {
        setState(() {
          _removeSuggestionsOverlay();
        });
      }
    });
  }

  void _fetchSuggestions(String input) {
    // Cancel any existing timer to prevent duplicate calls
    _debounce?.cancel();

    // Start a new debounce timer
    _debounce = Timer(_debounceDuration, () async {
      setState(() {
        _isLoading = true;
        _showLoadingOverlay();
      });

      final suggestions = await widget.suggestionsCallback(input);

      if (!mounted) return; // Prevent setting state on unmounted widget

      setState(() {
        _isLoading = false;
        _removeLoadingOverlay();
        _suggestions = suggestions;

        if (_suggestions.isNotEmpty) {
          _showSuggestionsOverlay();
        } else {
          _removeSuggestionsOverlay();
        }
      });
    });
  }

  void _showSuggestionsOverlay() {
    _removeSuggestionsOverlay();

    if (_suggestionsOverlayEntry != null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size inputFieldSize = renderBox.size;
    final Offset inputFieldOffset = renderBox.localToGlobal(Offset.zero);

    // Screen height and available space
    final double screenHeight = MediaQuery.of(context).size.height;
    final double availableSpaceBelow =
        screenHeight - inputFieldOffset.dy - inputFieldSize.height;
    final double availableSpaceAbove = inputFieldOffset.dy;

    // Dynamic dropdown height: Clamp to available space
    final double maxHeight =
        _suggestions.length * 48.0; // Approx. 48.0 per suggestion
    final double dropdownHeightBelow =
        maxHeight.clamp(0.0, availableSpaceBelow);
    final double dropdownHeightAbove =
        maxHeight.clamp(0.0, availableSpaceAbove - 10); // 10 for spacing

    // Determine position: Above if not enough space below
    final bool showAbove = availableSpaceBelow < maxHeight &&
        availableSpaceAbove > availableSpaceBelow;
    final Offset dropdownOffset = showAbove
        ? Offset(0, -dropdownHeightAbove - 10) // Position above with spacing
        : Offset(0, inputFieldSize.height + 10); // Position below with spacing

    final double dropdownHeight =
        showAbove ? dropdownHeightAbove : dropdownHeightBelow;

    _suggestionsOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: _layerLink.leader!.offset.dx,
        top: _layerLink.leader!.offset.dy + dropdownOffset.dy,
        width: inputFieldSize.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, dropdownOffset.dy),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              constraints: BoxConstraints(maxHeight: dropdownHeight),
              padding: EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9), color: Colors.white),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return InkWell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(_decodeData(suggestion),
                          style: const TextStyle(fontSize: 16)),
                    ),
                    onTap: () {
                      _controller.text = _decodeData(suggestion);
                      widget.onChanged(suggestion);
                      setState(() {
                        _suggestions = [];
                        _removeSuggestionsOverlay();
                      });
                      _focusNode.unfocus(); // Close the dropdown
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_suggestionsOverlayEntry!);
  }

  void _showLoadingOverlay() {
    if (_loadingOverlayEntry != null) return;
    OverlayState? overlayState = Overlay.of(context);

    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Offset offset = renderBox.localToGlobal(Offset.zero);

    // Positioning the loading overlay with padding below the dropdown
    double topPosition =
        offset.dy + renderBox.size.height + 15; // Add padding of 15
    _loadingOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: topPosition, // Position below with padding
        width: renderBox.size.width,
        child: Material(),
      ),
    );

    overlayState.insert(_loadingOverlayEntry!);
  }

  void _removeSuggestionsOverlay() {
    if (_suggestionsOverlayEntry != null) {
      _suggestionsOverlayEntry!.remove();
      _suggestionsOverlayEntry = null;
    }
  }

  void _removeLoadingOverlay() {
    if (_loadingOverlayEntry != null) {
      _loadingOverlayEntry!.remove();
      _loadingOverlayEntry = null;
    }
  }

  void _toggleFocus() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    } else {
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: (widget.decoration ??
                InputDecoration(
                  hintText: widget.hintText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ))
            .copyWith(
          suffixIcon: IconButton(
            icon: _isLoading
                ? SizedBox(
                    height: 20, // Adjust height as needed
                    width: 20, // Adjust width as needed
                    child: CircularProgressIndicator(
                        strokeWidth: 2), // Smaller size for suffix
                  )
                : Icon(
                    _focusNode.hasFocus
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
            onPressed: () {
              _toggleFocus(); // Toggle focus on press
            },
          ),
        ),
        onChanged: _fetchSuggestions,
        validator: widget.validator,
      ),
    );
  }
  String _decodeData(String data) {
    try {
      return utf8.decode(data.codeUnits);
    } catch (FormatException) {
      return data; // Return original data if decoding fails
    }
  }
  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _removeSuggestionsOverlay();
    _removeLoadingOverlay();
    _debounce?.cancel();
    super.dispose();
  }

}
