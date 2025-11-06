import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';

class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? trailing;
  final Widget? leading;

  const HeaderBar({
    Key? key,
    required this.title,
    this.trailing,
    this.leading,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(70); // content height only

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top; // status bar height

    return Container(
      // occupy status bar + header height, so it starts at absolute top
      height: top + preferredSize.height,
      padding: EdgeInsets.only(top: top, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          leading ?? const SizedBox(width: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: black,
            ),
          ),
          trailing ?? const SizedBox(width: 40),
        ],
      ),
    );
  }
}
