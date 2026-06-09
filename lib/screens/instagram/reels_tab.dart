import 'package:flutter/material.dart';

class ReelsTab extends StatelessWidget {
  const ReelsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Stack(
          children: [

            // Reel Background
            Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: Image.network(
                "https://picsum.photos/500/900?random=$index",
                fit: BoxFit.cover,
              ),
            ),

            // User Info
            Positioned(
              bottom: 80,
              left: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "@sharmaji",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Welcome to Reelotik 🚀",
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Right Side Buttons
            Positioned(
              right: 10,
              bottom: 100,
              child: Column(
                children: [

                  Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 35,
                  ),
                  SizedBox(height: 5),
                  Text(
                    "12K",
                    style: TextStyle(color: Colors.white),
                  ),

                  SizedBox(height: 20),

                  Icon(
                    Icons.comment,
                    color: Colors.white,
                    size: 35,
                  ),
                  SizedBox(height: 5),
                  Text(
                    "800",
                    style: TextStyle(color: Colors.white),
                  ),

                  SizedBox(height: 20),

                  Icon(
                    Icons.share,
                    color: Colors.white,
                    size: 35,
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Share",
                    style: TextStyle(color: Colors.white),
                  ),

                  SizedBox(height: 20),

                  CircleAvatar(
                    radius: 20,
                    child: Icon(Icons.person),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}