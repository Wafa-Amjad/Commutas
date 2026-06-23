import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CommutasColors {
  CommutasColors._();

  static const Color navyInk = Color(0xFF1A1B33);
  static const Color navyDark = Color(0xFF0E0F1F);
  static const Color sageTint = Color(0xFFE7E9DE);
  static const Color accentCobalt = Color(0xFF3B4CCB);
  static const Color accentDark = Color(0xFF2935A0);
  static const Color inkText = Color(0xFF1A1B22);
  static const Color slateMuted = Color(0xFF6B6F66);
  static const Color lineBorder = Color(0xFFB9BDAF);
  static const Color surface = Color(0xFFEDEFE3);
  static const Color danger = Color(0xFFB3261E);
  static const Color success = Color(0xFF3D6B3D);
  static const Color white = Colors.white;
}

class CommutasTextStyles {
  CommutasTextStyles._();

  static TextStyle appTitle = GoogleFonts.jetBrainsMono(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: CommutasColors.white,
  );

  static TextStyle contextStripLabel = GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: CommutasColors.white,
  );

  static TextStyle contextStripMeta = GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.5,
    color: CommutasColors.white,
  );

  static TextStyle sectionEyebrow = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    color: CommutasColors.slateMuted,
  );

  static TextStyle cardTitle = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: CommutasColors.inkText,
  );

  static TextStyle fieldLabel = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: CommutasColors.slateMuted,
  );

  static TextStyle fieldValue = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: CommutasColors.inkText,
  );

  static TextStyle buttonLabel = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: CommutasColors.white,
  );

  static TextStyle otpDigit = GoogleFonts.jetBrainsMono(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: CommutasColors.inkText,
  );

  static TextStyle identityBar = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: CommutasColors.slateMuted,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: CommutasColors.slateMuted,
  );
  
  static TextStyle bodySmallDanger = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: CommutasColors.danger,
  );
}

class CommutasShapes {
  CommutasShapes._();

  static const OutlinedBorder rectBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.zero,
    side: BorderSide(
      color: CommutasColors.lineBorder,
      width: 1.5,
    ),
  );

  static const OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(
      color: CommutasColors.lineBorder,
      width: 1.5,
    ),
  );

  static const OutlineInputBorder inputFocusBorder = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(
      color: CommutasColors.accentCobalt,
      width: 2.0,
    ),
  );

  static const OutlineInputBorder inputErrorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(
      color: CommutasColors.danger,
      width: 1.5,
    ),
  );
}
