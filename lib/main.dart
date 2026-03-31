import 'dart:io' show File, Platform;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'providers/app_provider.dart';

import 'dashboard/dashboard_screen.dart';
import 'sales/billing_screen.dart';
import 'inventory/inventory_screen.dart';
import 'customers/customers_screen.dart';
import 'staff/staff_screen.dart';
import 'expenses/expenses_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';
import 'theme/app_colors.dart';
import 'utils/responsive_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for web and desktop
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final provider = AppProvider();
  await provider.init();

  runApp(
    ChangeNotifierProvider.value(value: provider, child: const SalonPOSApp()),
  );
}

class SalonPOSApp extends StatelessWidget {
  const SalonPOSApp({super.key});

  double _fontScale(String value) {
    switch (value) {
      case 'Compact Dense':
        return 0.92;
      case 'Large Readable':
        return 1.12;
      default:
        return 1.0;
    }
  }

  Locale _localeFromSetting(String value) {
    switch (value) {
      case 'Spanish':
        return const Locale('es', 'ES');
      case 'Urdu (Coming Soon)':
      case 'Urdu (PK)':
        return const Locale('ur', 'PK');
      default:
        return const Locale('en', 'US');
    }
  }

  ThemeData _themeFromSetting(String value) {
    Color scaffold;
    Color card;
    Color text;
    Color primary;
    Color secondary;
    Brightness brightness;
    switch (value) {
      case 'Midnight Black':
        scaffold = const Color(0xFF000000);
        card = const Color(0xFF101010);
        text = const Color(0xFFEDEDED);
        primary = const Color(0xFFFF9E2C);
        secondary = const Color(0xFF6EE7B7);
        brightness = Brightness.dark;
        break;
      case 'Soft Light':
      case 'Clean Light Mode':
        scaffold = const Color(0xFFF4F5F7);
        card = const Color(0xFFFFFFFF);
        text = const Color(0xFF1F2937);
        primary = const Color(0xFF2563EB);
        secondary = const Color(0xFF0EA5E9);
        brightness = Brightness.light;
        break;
      case 'Warm Sepia':
        scaffold = const Color(0xFFF1E8D8);
        card = const Color(0xFFFFFAF0);
        text = const Color(0xFF4A3B2A);
        primary = const Color(0xFFB7791F);
        secondary = const Color(0xFF7C5E3C);
        brightness = Brightness.light;
        break;
      case 'Ocean Blue':
        scaffold = const Color(0xFF0D1B2A);
        card = const Color(0xFF1B263B);
        text = const Color(0xFFE0E7FF);
        primary = const Color(0xFF38BDF8);
        secondary = const Color(0xFF22D3EE);
        brightness = Brightness.dark;
        break;
      case 'Deep Ocean Dark (Default)':
      default:
        scaffold = AppColors.forest;
        card = AppColors.oliveDark;
        text = AppColors.sand;
        primary = AppColors.sage;
        secondary = AppColors.sand;
        brightness = Brightness.dark;
    }

    final base = ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      primaryColor: primary,
      cardColor: card,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: secondary,
        surface: card,
      ).copyWith(
        onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
      dividerTheme: DividerThemeData(
        color: (brightness == Brightness.dark
                ? Colors.white
                : Colors.black)
            .withValues(alpha: 0.16),
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          backgroundColor: primary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: text),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppProvider>().settings;
    final systemTheme = settings['systemTheme'] ?? 'Deep Ocean Dark (Default)';
    final fontScaling = settings['fontScaling'] ?? 'Normal Space';
    final language = settings['language'] ?? 'English (US)';
    final theme = _themeFromSetting(systemTheme);
    final fontScale = _fontScale(fontScaling);
    final locale = _localeFromSetting(language);

    return MaterialApp(
      title: 'Styles POS',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('es', 'ES'),
        Locale('ur', 'PK'),
      ],
      home: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(fontScale),
            ),
            child: const MainLayout(),
          );
        },
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _shellScaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _navEntrance;
  late final List<Widget> _tabPages;
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  static const List<String> _pageTitles = [
    'Dashboard',
    'Sales',
    'Customers',
    'Staff',
    'Inventory',
    'Expenses',
    'Reports',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _tabPages = [
      DashboardScreen(
        onNewSale: () => setState(() => _selectedIndex = 1),
        onAddCustomer: () => setState(() => _selectedIndex = 2),
        onAddExpense: () => setState(() => _selectedIndex = 5),
      ),
      const BillingScreen(),
      const CustomersScreen(),
      const StaffScreen(),
      const InventoryScreen(),
      const ExpensesScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];
    _navEntrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    )..forward();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _navEntrance.dispose();
    super.dispose();
  }

  String _formattedDateTime() {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    final ss = _now.second.toString().padLeft(2, '0');
    final date =
        '${_now.day.toString().padLeft(2, '0')} ${months[_now.month - 1]} ${_now.year}';
    return '$date  $hh:$mm:$ss';
  }

  Animation<double> _navItemEntrance(int index) {
    const count = 8;
    final start = (index / count) * 0.45;
    final end = (start + 0.55).clamp(0.01, 1.0);
    return CurvedAnimation(
      parent: _navEntrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  void _selectNav(int index, {bool closeDrawer = false}) {
    setState(() => _selectedIndex = index);
    if (closeDrawer) {
      _shellScaffoldKey.currentState?.closeDrawer();
    }
  }

  Widget _sidebarInterior({
    required bool isCollapsed,
    required Color sidebarPrimary,
    required String businessTitle,
    required String businessTagline,
    required String? businessLogoPath,
    required String adminName,
    required String adminRole,
    required String? adminAvatarPath,
    double brandTopPadding = 28,
    bool closeDrawerOnTap = false,
  }) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: 0.35,
              duration: const Duration(milliseconds: 400),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      sidebarPrimary.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: isCollapsed
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCollapsed ? 12 : 20,
                brandTopPadding,
                isCollapsed ? 12 : 20,
                20,
              ),
              child: _SidebarBrand(
                isCollapsed: isCollapsed,
                isDark: true,
                primary: sidebarPrimary,
                businessTitle: businessTitle,
                businessTagline: businessTagline,
                businessLogoPath: businessLogoPath,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _NavItem(
                    entrance: _navItemEntrance(0),
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    isSelected: _selectedIndex == 0,
                    isCollapsed: isCollapsed,
                    isDark: true,
                    onTap: () => _selectNav(0, closeDrawer: closeDrawerOnTap),
                  ),
                  _NavItem(
                    entrance: _navItemEntrance(1),
                    icon: Icons.point_of_sale_rounded,
                    title: 'Sales',
                    isSelected: _selectedIndex == 1,
                    isCollapsed: isCollapsed,
                    isDark: true,
                    onTap: () => _selectNav(1, closeDrawer: closeDrawerOnTap),
                  ),
                  _NavItem(
                    entrance: _navItemEntrance(2),
                    icon: Icons.people_rounded,
                    title: 'Customers',
                    isSelected: _selectedIndex == 2,
                    isCollapsed: isCollapsed,
                    isDark: true,
                    onTap: () => _selectNav(2, closeDrawer: closeDrawerOnTap),
                  ),
                  _NavItem(
                    entrance: _navItemEntrance(3),
                    icon: Icons.groups_rounded,
                    title: 'Staff',
                    isSelected: _selectedIndex == 3,
                    isCollapsed: isCollapsed,
                    isDark: true,
                    onTap: () => _selectNav(3, closeDrawer: closeDrawerOnTap),
                  ),
                  _NavItem(
                    entrance: _navItemEntrance(4),
                    icon: Icons.inventory_2_rounded,
                    title: 'Inventory',
                    isSelected: _selectedIndex == 4,
                    isCollapsed: isCollapsed,
                    isDark: true,
                    onTap: () => _selectNav(4, closeDrawer: closeDrawerOnTap),
                  ),
                  _NavItem(
                    entrance: _navItemEntrance(5),
                    icon: Icons.payments_rounded,
                    title: 'Expenses',
                    isSelected: _selectedIndex == 5,
                    isCollapsed: isCollapsed,
                    isDark: true,
                    onTap: () => _selectNav(5, closeDrawer: closeDrawerOnTap),
                  ),
                  _NavItem(
                    entrance: _navItemEntrance(6),
                    icon: Icons.bar_chart_rounded,
                    title: 'Reports',
                    isSelected: _selectedIndex == 6,
                    isCollapsed: isCollapsed,
                    isDark: true,
                    onTap: () => _selectNav(6, closeDrawer: closeDrawerOnTap),
                  ),
                  _NavItem(
                    entrance: _navItemEntrance(7),
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    isSelected: _selectedIndex == 7,
                    isCollapsed: isCollapsed,
                    isDark: true,
                    onTap: () => _selectNav(7, closeDrawer: closeDrawerOnTap),
                  ),
                ],
              ),
            ),
            _SidebarFooter(
              isCollapsed: isCollapsed,
              isDark: true,
              primary: sidebarPrimary,
              adminName: adminName,
              adminRole: adminRole,
              adminAvatarPath: adminAvatarPath,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDrawer = AppBreakpoints.isMobileWidth(screenWidth);
    final isCollapsed =
        !useDrawer && screenWidth < AppBreakpoints.tablet;
    final sidebarPrimary = AppColors.sage;
    final businessTitle = context.select<AppProvider, String>((p) {
      final n = p.settings['salonName']?.trim();
      return (n == null || n.isEmpty) ? 'Styles POS' : n;
    });
    final businessTagline = context.select<AppProvider, String>((p) {
      final t = p.settings['businessTagline']?.trim();
      return (t == null || t.isEmpty) ? 'Salon & beauty' : t;
    });
    final businessLogoPath = context.select<AppProvider, String?>(
      (p) => p.settings['businessLogoPath'],
    );
    final adminName = context.select<AppProvider, String>((p) {
      final n = p.settings['adminDisplayName']?.trim();
      return (n == null || n.isEmpty) ? 'Admin User' : n;
    });
    final adminRole = context.select<AppProvider, String>((p) {
      final r = p.settings['adminRole']?.trim();
      return (r == null || r.isEmpty) ? 'Manager' : r;
    });
    final adminAvatarPath = context.select<AppProvider, String?>(
      (p) => p.settings['adminAvatarPath']?.trim().isNotEmpty == true
          ? p.settings['adminAvatarPath']
          : p.settings['businessLogoPath'],
    );

    final mainContent = IndexedStack(
      index: _selectedIndex,
      children: _tabPages,
    );

    const sidebarGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.forest,
        Color(0xFF1D1D1D),
        AppColors.oliveDark,
      ],
    );

    final sidebarTheme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: sidebarPrimary,
          ),
    );

    final Widget railSidebar = Theme(
      data: sidebarTheme,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: isCollapsed ? 84 : 264,
        decoration: BoxDecoration(
          gradient: sidebarGradient,
          border: Border(
            right: BorderSide(
              color: AppColors.sage.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 28,
              offset: Offset(10, 0),
              spreadRadius: -4,
            ),
          ],
        ),
        child: _sidebarInterior(
          isCollapsed: isCollapsed,
          sidebarPrimary: sidebarPrimary,
          businessTitle: businessTitle,
          businessTagline: businessTagline,
          businessLogoPath: businessLogoPath,
          adminName: adminName,
          adminRole: adminRole,
          adminAvatarPath: adminAvatarPath,
        ),
      ),
    );

    final Widget drawerSidebar = Theme(
      data: sidebarTheme,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: sidebarGradient),
        child: _sidebarInterior(
          isCollapsed: false,
          sidebarPrimary: sidebarPrimary,
          businessTitle: businessTitle,
          businessTagline: businessTagline,
          businessLogoPath: businessLogoPath,
          adminName: adminName,
          adminRole: adminRole,
          adminAvatarPath: adminAvatarPath,
          brandTopPadding: 16,
          closeDrawerOnTap: true,
        ),
      ),
    );

    if (useDrawer) {
      final drawerWidth = (screenWidth * 0.88).clamp(280.0, 320.0);
      return Scaffold(
        key: _shellScaffoldKey,
        appBar: AppBar(
          backgroundColor: AppColors.forest,
          foregroundColor: AppColors.sand,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _pageTitles[_selectedIndex],
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  _formattedDateTime(),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
          ],
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => _shellScaffoldKey.currentState?.openDrawer(),
          ),
        ),
        drawer: Drawer(
          width: drawerWidth,
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(16)),
            child: drawerSidebar,
          ),
        ),
        body: mainContent,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          railSidebar,
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    border: const Border(
                      bottom: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _pageTitles[_selectedIndex],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formattedDateTime(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: mainContent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatefulWidget {
  const _SidebarBrand({
    required this.isCollapsed,
    required this.isDark,
    required this.primary,
    required this.businessTitle,
    required this.businessTagline,
    required this.businessLogoPath,
  });

  final bool isCollapsed;
  final bool isDark;
  final Color primary;
  final String businessTitle;
  final String businessTagline;
  final String? businessLogoPath;

  @override
  State<_SidebarBrand> createState() => _SidebarBrandState();
}

class _SidebarBrandState extends State<_SidebarBrand>
    with SingleTickerProviderStateMixin {
  late AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.isDark
        ? const Color(0x55AEB784)
        : AppColors.stoneOlive;

    return Row(
      mainAxisAlignment: widget.isCollapsed
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _glow,
          builder: (context, child) {
            final pulse = 0.85 + _glow.value * 0.15;
            return Transform.scale(
              scale: pulse,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.primary.withValues(alpha: widget.isDark ? 0.35 : 0.2),
                  widget.primary.withValues(alpha: widget.isDark ? 0.12 : 0.08),
                ],
              ),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: widget.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _BrandLogo(
              primary: widget.primary,
              logoPath: widget.businessLogoPath,
              size: widget.isCollapsed ? 30 : 40,
            ),
          ),
        ),
        if (!widget.isCollapsed) ...[
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.businessTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: widget.isDark ? AppColors.ivory : AppColors.oliveDark,
                  ),
                ),
                Text(
                  widget.businessTagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: widget.isDark
                        ? AppColors.sand
                        : AppColors.moss,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({
    required this.primary,
    required this.logoPath,
    required this.size,
  });

  final Color primary;
  final String? logoPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = logoPath?.trim();
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.content_cut_rounded,
                color: primary,
                size: size,
              ),
            ),
          );
        }
      } catch (_) {}
    }
    return Icon(Icons.content_cut_rounded, color: primary, size: size);
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.isCollapsed,
    required this.isDark,
    required this.primary,
    required this.adminName,
    required this.adminRole,
    required this.adminAvatarPath,
  });

  final bool isCollapsed;
  final bool isDark;
  final Color primary;
  final String adminName;
  final String adminRole;
  final String? adminAvatarPath;

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? AppColors.oliveDark.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.72);
    final border = isDark
        ? const Color(0x66AEB784)
        : const Color(0xFFD3CAA7);

    Widget inner = isCollapsed
        ? IconButton(
            tooltip: 'Sign out',
            style: IconButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.sand
                  : AppColors.moss,
            ),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {},
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        primary.withValues(alpha: 0.5),
                        primary.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        isDark ? const Color(0xFF52562A) : AppColors.ivory,
                    child: _AdminAvatarContent(
                      primary: primary,
                      avatarPath: adminAvatarPath,
                      nameFallback: adminName,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? AppColors.ivory : AppColors.oliveDark,
                        ),
                      ),
                      Text(
                        adminRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.sand
                              : AppColors.moss,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  style: IconButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.sand
                        : AppColors.moss,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 22),
                  onPressed: () {},
                ),
              ],
            ),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 8, 10, isCollapsed ? 16 : 18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 4 : 12,
          vertical: isCollapsed ? 4 : 10,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: inner,
      ),
    );
  }
}

class _AdminAvatarContent extends StatelessWidget {
  const _AdminAvatarContent({
    required this.primary,
    required this.avatarPath,
    required this.nameFallback,
  });

  final Color primary;
  final String? avatarPath;
  final String nameFallback;

  @override
  Widget build(BuildContext context) {
    final path = avatarPath?.trim();
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person_rounded,
                color: primary,
                size: 28,
              ),
            ),
          );
        }
      } catch (_) {}
    }
    final initial = nameFallback.trim().isEmpty ? 'A' : nameFallback.trim()[0];
    return Text(
      initial.toUpperCase(),
      style: TextStyle(
        color: primary,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.entrance,
    required this.icon,
    required this.title,
    required this.isSelected,
    this.isCollapsed = false,
    required this.isDark,
    required this.onTap,
  });

  final Animation<double> entrance;
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool isCollapsed;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final inactive = widget.isDark
        ? AppColors.sand
        : AppColors.moss;

    return AnimatedBuilder(
      animation: widget.entrance,
      builder: (context, child) {
        final t = widget.entrance.value;
        return Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              splashColor: primary.withValues(alpha: 0.12),
              highlightColor: primary.withValues(alpha: 0.06),
              child: AnimatedScale(
                scale: _hover ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: widget.isCollapsed ? null : double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: widget.isCollapsed ? 0 : 14,
                  ),
                  alignment: widget.isCollapsed
                      ? Alignment.center
                      : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: widget.isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primary.withValues(alpha: widget.isDark ? 0.22 : 0.14),
                              primary.withValues(alpha: widget.isDark ? 0.08 : 0.06),
                            ],
                          )
                        : _hover
                            ? LinearGradient(
                                colors: [
                                  (widget.isDark
                                          ? Colors.white
                                          : AppColors.oliveDark)
                                      .withValues(alpha: 0.06),
                                  (widget.isDark
                                          ? Colors.white
                                          : AppColors.oliveDark)
                                      .withValues(alpha: 0.02),
                                ],
                              )
                            : null,
                    color: widget.isSelected || _hover
                        ? null
                        : Colors.transparent,
                    border: Border.all(
                      color: widget.isSelected
                          ? primary.withValues(alpha: 0.45)
                          : _hover
                              ? (widget.isDark
                                      ? Colors.white
                                      : const Color(0xFFD3CAA7))
                                  .withValues(alpha: 0.12)
                              : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: -4,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: widget.isSelected ? 4 : 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(14),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                primary,
                                primary.withValues(alpha: 0.65),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      widget.isCollapsed
                          ? Tooltip(
                              message: widget.title,
                              waitDuration: const Duration(milliseconds: 400),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Icon(
                                  widget.icon,
                                  color: widget.isSelected ? primary : inactive,
                                  size: 24,
                                ),
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                const SizedBox(width: 8),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    color: widget.isSelected
                                        ? primary.withValues(alpha: 0.2)
                                        : _hover
                                            ? (widget.isDark
                                                    ? Colors.white
                                                    : primary)
                                                .withValues(alpha: 0.08)
                                            : Colors.transparent,
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    color: widget.isSelected
                                        ? primary
                                        : inactive,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 220),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: widget.isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      letterSpacing: -0.2,
                                      color: widget.isSelected
                                          ? (widget.isDark
                                              ? Colors.white
                                              : AppColors.oliveDark)
                                          : inactive,
                                    ),
                                    child: Text(widget.title),
                                  ),
                                ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
