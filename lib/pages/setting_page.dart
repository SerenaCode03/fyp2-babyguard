import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';
import 'package:fyp2_babyguard/components/header_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // HeaderBar should always attach directly to top, left, and right.
    return Column(
      children: [
        // Full-width top header (no padding, flush with screen)
        const HeaderBar(title: 'Settings'),

        // Main scrollable content area (with inner padding)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: backgroundWhite,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_outline,
                            size: 50,
                            color: Colors.black26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Serena',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: black,
                        ),
                      ),
                      // const SizedBox(height: 6),
                      // Align(
                      //   alignment: Alignment.centerRight,
                      //   child: Padding(
                      //     padding: const EdgeInsets.only(right: 18.0, top: 8),
                      //     child: SizedBox(
                      //       width: 36,
                      //       height: 8,
                      //       child: Row(
                      //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //         children: List.generate(
                      //           3,
                      //           (i) => Container(
                      //             width: 6,
                      //             height: 6,
                      //             decoration: BoxDecoration(
                      //               color: Colors.grey.shade300,
                      //               borderRadius: BorderRadius.circular(6),
                      //             ),
                      //           ),
                      //         ),
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Settings actions
                _SettingsCard(
                  leading: const Icon(Icons.vpn_key_rounded, size: 30),
                  title: 'Change password',
                  titleStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  onTap: () {
                    // TODO: navigate to change password screen
                  },
                ),

                const SizedBox(height: 16),

                _SettingsCard(
                  leading: const Icon(Icons.logout_rounded, size: 30, color: Colors.deepOrange),
                  title: 'Log out',
                  titleStyle: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  onTap: () {
                    // TODO: handle logout
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.leading,
    required this.title,
    this.onTap,
    this.titleStyle,
    super.key,
  });

  final Widget leading;
  final String title;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: leading),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: titleStyle ??
                    const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: black,
                    ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}
