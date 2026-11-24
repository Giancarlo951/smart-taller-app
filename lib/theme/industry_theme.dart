import 'package:flutter/material.dart';

/// Tokens del sistema visual de la app, tomado de los bocetos (BOCETOS.docx):
/// fondo claro, tarjetas blancas redondeadas con sombra suave, íconos en
/// mosaicos y azul como color principal.
abstract final class Ind {
  // — Roles de color —
  static const bg = Color(0xFFF5F7FB); // fondo de las pantallas
  static const card = Color(0xFFFFFFFF); // tarjetas, barras, hojas y diálogos
  static const surface = Color(0xFFF1F4F9); // mosaicos y rellenos suaves
  static const text = Color(0xFF101828);
  static const accent = Color(0xFF1D4ED8);

  // — Rampa de azul —
  static const a100 = Color(0xFFEFF5FF);
  static const a200 = Color(0xFFDBE7FE);
  static const a300 = Color(0xFFBFD3FE);
  static const a400 = Color(0xFF93B4FD);
  static const a500 = Color(0xFF3B76F6);
  static const a600 = Color(0xFF2563EB);
  static const a700 = Color(0xFF1D4ED8);
  static const a800 = Color(0xFF1E40AF);
  static const a900 = Color(0xFF172E73);

  // — Neutros —
  static const n100 = Color(0xFFF2F4F7);
  static const n200 = Color(0xFFE4E7EC);
  static const n300 = Color(0xFFD0D5DD);
  static const n400 = Color(0xFF98A2B3);
  static const n500 = Color(0xFF667085);
  static const n600 = Color(0xFF475467);
  static const n700 = Color(0xFF344054);
  static const n800 = Color(0xFF1D2939);
  static const n900 = Color(0xFF101828);

  // — Estados —
  static const exito = Color(0xFF067647);
  static const exitoFondo = Color(0xFFECFDF3);
  static const peligro = Color(0xFFD92D20);
  static const peligroFondo = Color(0xFFFEF3F2);

  /// Texto mezclado con transparencia.
  static Color textAt(double opacity) => text.withValues(alpha: opacity);

  static const divider = n200;
  static const muted = n500;

  // — Espaciado —
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s6 = 24.0, s8 = 32.0;

  // — Pantallas anchas (PC, tablet horizontal) —
  /// Desde este ancho la navegación pasa a una barra lateral.
  static const anchoEscritorio = 840.0;

  /// Ancho máximo del contenido de una página; el resto queda como margen.
  static const anchoContenido = 960.0;

  /// Margen lateral para centrar el contenido en un espacio de [ancho].
  static double margenLateral(double ancho, {double minimo = 16}) {
    final sobrante = (ancho - anchoContenido) / 2;
    return sobrante > minimo ? sobrante : minimo;
  }

  // — Radios —
  static const radiusSm = 8.0; // etiquetas pequeñas, barras
  static const radiusMd = 12.0; // botones, campos, mosaicos de ícono
  static const radiusLg = 16.0; // tarjetas
  static const radiusXl = 24.0; // hojas inferiores, banner

  // — Sombras suaves —
  static const shadowSm = [BoxShadow(color: Color(0x0F101828), offset: Offset(0, 1), blurRadius: 3)];
  static const shadowMd = [BoxShadow(color: Color(0x14101828), offset: Offset(0, 6), blurRadius: 18, spreadRadius: -4)];
  static const shadowLg = [BoxShadow(color: Color(0x1F101828), offset: Offset(0, 16), blurRadius: 36, spreadRadius: -8)];

  // — Tipografía (Barlow, licencia OFL) —
  static const fontBody = 'Barlow';
  static const fontHeading = 'Barlow';

  /// Título en Barlow 600.
  static TextStyle heading(double size, {double height = 1.2, Color color = text}) => TextStyle(
        fontFamily: fontHeading,
        fontWeight: FontWeight.w600,
        fontSize: size,
        height: height,
        letterSpacing: -0.01 * size,
        color: color,
      );

  /// Texto en Barlow 400.
  static TextStyle body(double size, {Color color = text, double height = 1.5}) => TextStyle(
        fontFamily: fontBody,
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: height,
        color: color,
      );

  /// Texto pequeño sobre un título ("Hola,", fecha, código de la orden).
  static TextStyle kicker({double size = 12.5, Color color = muted}) => TextStyle(
        fontFamily: fontBody,
        fontWeight: FontWeight.w500,
        fontSize: size,
        height: 1.3,
        color: color,
      );

  /// Meta de tarjeta: 12 px en gris.
  static final meta = body(12, color: muted, height: 1.4);
}

ThemeData industryTheme() {
  final redondo = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ind.radiusMd));
  final overlayText = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.pressed)) return Ind.textAt(0.10);
    if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return Ind.textAt(0.05);
    return null;
  });
  OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Ind.radiusMd),
        borderSide: BorderSide(color: color, width: ancho),
      );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: Ind.accent,
    brightness: Brightness.light,
  ).copyWith(
    primary: Ind.accent,
    onPrimary: Colors.white,
    primaryContainer: Ind.a100,
    onPrimaryContainer: Ind.a800,
    secondary: Ind.a600,
    onSecondary: Colors.white,
    surface: Ind.card,
    onSurface: Ind.text,
    surfaceContainerHighest: Ind.surface,
    outline: Ind.n300,
    outlineVariant: Ind.n200,
    error: Ind.peligro,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Ind.bg,
    canvasColor: Ind.card,
    fontFamily: Ind.fontBody,
    visualDensity: VisualDensity.standard,
  );

  final t = base.textTheme;
  TextStyle h(TextStyle? s, double size) => (s ?? const TextStyle()).merge(Ind.heading(size));

  return base.copyWith(
    textTheme: t.copyWith(
      displayLarge: h(t.displayLarge, 44),
      displayMedium: h(t.displayMedium, 38),
      displaySmall: h(t.displaySmall, 30),
      headlineLarge: h(t.headlineLarge, 30),
      headlineMedium: h(t.headlineMedium, 24),
      headlineSmall: h(t.headlineSmall, 22),
      titleLarge: h(t.titleLarge, 19),
      titleMedium: h(t.titleMedium, 16),
      titleSmall: h(t.titleSmall, 15),
      bodyLarge: Ind.body(15),
      bodyMedium: Ind.body(14),
      bodySmall: Ind.body(12, color: Ind.muted),
      labelLarge: Ind.heading(14, height: 1.2),
      labelMedium: Ind.body(12),
      labelSmall: Ind.body(11),
    ),
    dividerTheme: const DividerThemeData(color: Ind.divider, thickness: 1, space: 1),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Ind.accent,
      selectionColor: Ind.accent.withValues(alpha: 0.25),
      selectionHandleColor: Ind.accent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Ind.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Ind.text,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Ind.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ind.radiusLg)),
    ),

    // Botón principal: azul sólido, esquinas redondeadas.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(redondo),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
        textStyle: WidgetStatePropertyAll(Ind.heading(15, height: 1.2)),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return Ind.a300;
          if (states.contains(WidgetState.pressed)) return Ind.a900;
          if (states.contains(WidgetState.hovered)) return Ind.a800;
          return Ind.accent;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),

    // Botón de contorno: blanco con borde gris.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(redondo),
        minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
        textStyle: WidgetStatePropertyAll(Ind.heading(14, height: 1.2)),
        backgroundColor: const WidgetStatePropertyAll(Ind.card),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Ind.n400 : Ind.n800),
        side: const WidgetStatePropertyAll(BorderSide(color: Ind.n300)),
        overlayColor: overlayText,
      ),
    ),

    // Botón de texto: azul.
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(redondo),
        minimumSize: const WidgetStatePropertyAll(Size(40, 36)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        textStyle: WidgetStatePropertyAll(Ind.heading(14, height: 1.2)),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Ind.n400 : Ind.accent),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return Ind.accent.withValues(alpha: 0.14);
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
            return Ind.accent.withValues(alpha: 0.08);
          }
          return null;
        }),
      ),
    ),

    // Campos: blancos, redondeados, borde gris y azul al enfocar.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Ind.card,
      isDense: true,
      constraints: const BoxConstraints(minHeight: 46),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: Ind.body(14, color: Ind.n400),
      prefixIconColor: Ind.n500,
      suffixIconColor: Ind.n500,
      border: borde(Ind.n200),
      enabledBorder: borde(Ind.n200),
      focusedBorder: borde(Ind.accent, 1.5),
      errorBorder: borde(Ind.peligro),
      focusedErrorBorder: borde(Ind.peligro, 1.5),
      errorStyle: Ind.body(11.5, color: Ind.peligro, height: 1.3),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Ind.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: Ind.heading(19),
      contentTextStyle: Ind.body(14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Ind.card,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Ind.n300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Ind.radiusXl))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Ind.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ind.radiusMd)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Ind.a900,
      contentTextStyle: Ind.body(13.5, color: Colors.white),
      actionTextColor: Ind.a300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ind.radiusMd)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Ind.accent,
      linearTrackColor: Ind.a200,
      linearMinHeight: 4,
    ),
  );
}
