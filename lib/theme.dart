import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CommutasColors {
  CommutasColors._();

  // Primary Palette
  static const Color primaryNavy = Color(0xFF1A1B33);
  static const Color emeraldGreen = Color(0xFF2E7D32);
  static const Color deepGreen = Color(0xFF1B5E20);
  static const Color sageGreen = Color(0xFF81C784);
  static const Color lightGreenBg = Color(0xFFF1F8E9);
  static const Color offWhite = Color(0xFFFDFDFD);
  static const Color backgroundGray = Color(0xFFF5F7FA);
  
  // Status Colors
  static const Color success = Color(0xFF388E3C);
  static const Color danger = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA000);
  
  // Neutral Colors
  static const Color inkText = Color(0xFF212121);
  static const Color slateMuted = Color(0xFF757575);
  static const Color lineBorder = Color(0xFFE0E0E0);
  
  // Wallet Gradient
  static const List<Color> walletGradient = [
    Color(0xFFE8F5E9),
    Color(0xFFC8E6C9),
  ];

  // Cobalt Colors
  static const Color accentCobalt = Color(0xFF3B4CCB);
  static const Color cobaltLight = Color(0xFF5C6BDB);
  static const Color cobaltTint = Color(0xFFEEF0FC);

  // Aliases for backward compatibility
  static const Color background = backgroundGray;
  static const Color surface = Colors.white;
  static const Color white = Colors.white;
  static const Color sageTint = lightGreenBg;
  static const Color navyInk = primaryNavy;
}

class CommutasTextStyles {
  CommutasTextStyles._();

  static TextStyle heading1 = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: CommutasColors.primaryNavy,
  );

  static TextStyle heading2 = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: CommutasColors.primaryNavy,
  );

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: CommutasColors.inkText,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: CommutasColors.inkText,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: CommutasColors.slateMuted,
  );

  static TextStyle labelBold = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: CommutasColors.primaryNavy,
    letterSpacing: 0.2,
  );
  
  static TextStyle labelCaption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: CommutasColors.emeraldGreen,
  );

  // Aliases for backward compatibility
  static TextStyle sectionEyebrow = labelBold;
  static TextStyle cardTitle = heading2;
  static TextStyle fieldLabel = bodySmall;
  static TextStyle fieldValue = bodyMedium;
  static TextStyle buttonLabel = labelBold.copyWith(color: Colors.white);
}

class CommutasShapes {
  CommutasShapes._();

  static const double borderRadius = 0.0;
  
  static BorderRadius cardRadius = BorderRadius.circular(borderRadius);
  
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: cardRadius,
    border: Border.all(color: CommutasColors.lineBorder, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Aliases for backward compatibility
  static OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: const BorderSide(color: CommutasColors.lineBorder),
  );
  static OutlineInputBorder inputFocusBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: const BorderSide(color: CommutasColors.emeraldGreen, width: 2),
  );
  static OutlineInputBorder inputErrorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: const BorderSide(color: CommutasColors.danger),
  );
}

class CommutasThemes {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: CommutasColors.backgroundGray,
    primaryColor: CommutasColors.emeraldGreen,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CommutasColors.emeraldGreen,
      primary: CommutasColors.emeraldGreen,
      secondary: CommutasColors.primaryNavy,
      surface: Colors.white,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: CommutasColors.primaryNavy),
      titleTextStyle: TextStyle(
        color: CommutasColors.primaryNavy,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
