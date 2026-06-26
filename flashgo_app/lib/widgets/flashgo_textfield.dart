// lib/widgets/flashgo_textfield.dart
import 'package:flutter/material.dart';

class FlashGoTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? prefix;

  const FlashGoTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.obscure      = false,
    this.keyboardType = TextInputType.text,
    this.prefix,
  });

  @override
  State<FlashGoTextField> createState() => _FlashGoTextFieldState();
}

class _FlashGoTextFieldState extends State<FlashGoTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color:      Colors.white70,
            fontSize:   13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:    widget.controller,
          obscureText:   widget.obscure ? _obscure : false,
          keyboardType:  widget.keyboardType,
          validator:     widget.validator,
          // ── Fix bug suppression ──────────────────────────
          enableInteractiveSelection: true,
          toolbarOptions: const ToolbarOptions(
            copy:        true,
            cut:         true,
            paste:       true,
            selectAll:   true,
          ),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText:      widget.hint,
            hintStyle:     const TextStyle(color: Colors.white38),
            prefixIcon:    widget.prefix,
            filled:        true,
            fillColor:     const Color(0xFF1E2D3D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(
                color: Color(0xFF22D3EE), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(
                color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(
                color: Colors.red, width: 1.5),
            ),
            suffixIcon: widget.obscure
                ? IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white38,
                    ),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}