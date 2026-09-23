import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/user_provider.dart';
import '../providers/language_provider.dart';
import '../services/core_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';

/// Bilah atas (web: Navbar): outlet aktif / mode pembeli, toggle bahasa
/// EN/ID, avatar inisial dengan menu (nama, email, role, logout).
/// Email TIDAK lagi ditulis lebar-lebar di bilah (dulu meluap di HP kecil)
/// -- dipindahkan ke menu avatar.
class AppBarCustom extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;

  const AppBarCustom({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.leading,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  State<AppBarCustom> createState() => _AppBarCustomState();
}

class _AppBarCustomState extends State<AppBarCustom> {
  String _outletCode = '';
  String _role = '';
  String _displayName = '';
  bool _buyerMode = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    final role = await Storage.get(AppConstants.userRoleKey) ?? '';
    final shopMode = await Storage.get(AppConstants.shopModeKey) ?? '';
    final nip = await Storage.get(AppConstants.userNIPKey) ?? '';
    if (!mounted) return;
    setState(() {
      _outletCode = outcode;
      _role = role;
      _buyerMode = shopMode == AppConstants.shopModeBuyer;
      _displayName = nip;
    });
  }

  Future<void> _logout() async {
    try {
      await CoreApi().logout();
    } catch (_) {
      // sesi lokal tetap dibersihkan supaya user tidak "terkunci"
    }
    await Storage.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    final isAdmin = _role == AppConstants.roleAdmin;
    final buyerView = !isAdmin &&
        (_buyerMode || _role == AppConstants.roleBuyer);

    Widget? contextChip;
    if (buyerView) {
      contextChip = Consumer<LanguageProvider>(
        builder: (context, lang, _) => _Pill(
          label: lang.get('Buyer mode', 'Mode Pembeli'),
          background: AppColors.tealLight,
          foreground: AppColors.tealDark,
        ),
      );
    } else if (_outletCode.isNotEmpty) {
      contextChip = _Pill(
        icon: Icons.storefront_rounded,
        label: _outletCode,
        outlined: true,
        onTap: isAdmin ? null : () => Navigator.pushNamed(context, '/outlet'),
      );
    }

    return AppBar(
      leading: widget.leading,
      title: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      bottom: widget.bottom,
      actions: [
        // chip outlet/mode hanya kalau ada ruang (>= 600dp); di HP tetap
        // bisa dilihat lewat menu avatar
        if (contextChip != null && !compact)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: contextChip,
          ),
        ...?widget.actions,
        Consumer<LanguageProvider>(
          builder: (context, langProvider, child) {
            return _Pill(
              icon: Icons.translate_rounded,
              label: langProvider.isEnglish ? 'EN' : 'ID',
              outlined: true,
              foreground: AppColors.blue,
              borderColor: AppColors.blue.withValues(alpha: 0.5),
              onTap: () => langProvider.toggleLanguage(),
            );
          },
        ),
        const SizedBox(width: 6),
        Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final email = userProvider.user?.email ?? 'Guest';
            final name = _displayName.isNotEmpty ? _displayName : email;
            final initial =
                name.isNotEmpty ? name[0].toUpperCase() : '?';
            return PopupMenuButton<String>(
              tooltip: email,
              offset: const Offset(0, 46),
              onSelected: (value) {
                if (value == 'logout') _logout();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        if (_role.isNotEmpty || _outletCode.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (_role.isNotEmpty)
                                  _Pill(
                                    label: _role,
                                    background: isAdmin
                                        ? AppColors.warningLight
                                        : AppColors.chipBg,
                                    foreground: isAdmin
                                        ? AppColors.warningDark
                                        : AppColors.ink,
                                  ),
                                if (buyerView)
                                  const _Pill(
                                    label: 'Mode Pembeli',
                                    background: AppColors.tealLight,
                                    foreground: AppColors.tealDark,
                                  )
                                else if (_outletCode.isNotEmpty)
                                  _Pill(
                                    icon: Icons.storefront_rounded,
                                    label: _outletCode,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          size: 20, color: AppColors.error),
                      SizedBox(width: 12),
                      Text('Logout',
                          style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.blue,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Chip kecil bergaya web (MuiChip size small).
class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool outlined;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final VoidCallback? onTap;

  const _Pill({
    required this.label,
    this.icon,
    this.outlined = false,
    this.background,
    this.foreground,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppColors.ink;
    final bg = outlined ? Colors.transparent : (background ?? AppColors.chipBg);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200, minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: outlined
                ? Border.all(color: borderColor ?? AppColors.border)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
