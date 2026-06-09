import 'package:flutter/material.dart';

class CoinCard extends StatelessWidget {
  final int coins;

  const CoinCard({
    super.key,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff2c3e50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.currency_rupee,
              size: 16,
              color: Colors.black,
            ),
          ),

          const SizedBox(width: 6),

          Text(
            "$coins",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}