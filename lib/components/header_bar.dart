import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/utilities/color.dart';

class HeaderBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 70, // adjustable height
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: white,
        // borderRadius: BorderRadius.only(
        //   bottomLeft: Radius.circular(16),
        //   bottomRight: Radius.circular(16),
        // ),
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
          leading ?? const SizedBox(width: 40), // placeholder if no back button
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: black,
            ),
          ),
          trailing ?? const SizedBox(width: 40), // keep symmetry
        ],
      ),
    );
  }
}
