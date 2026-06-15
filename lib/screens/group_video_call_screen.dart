import 'package:flutter/material.dart';

class GroupVideoCallScreen extends StatefulWidget {
  final String groupName;

  const GroupVideoCallScreen({
    super.key,
    required this.groupName,
  });

  @override
  State<GroupVideoCallScreen> createState() =>
      _GroupVideoCallScreenState();
}

class _GroupVideoCallScreenState
    extends State<GroupVideoCallScreen> {
  bool micOn = true;
  bool cameraOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              color: Colors.black87,
              child: const Center(
                child: Icon(
                  Icons.groups,
                  color: Colors.white54,
                  size: 100,
                ),
              ),
            ),

            Positioned(
              top: 20,
              left: 20,
              child: Text(
                widget.groupName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding:
                    const EdgeInsets.only(bottom: 30),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      heroTag: "mic",
                      backgroundColor:
                          micOn ? Colors.green : Colors.orange,
                      onPressed: () {
                        setState(() {
                          micOn = !micOn;
                        });
                      },
                      child: Icon(
                        micOn
                            ? Icons.mic
                            : Icons.mic_off,
                      ),
                    ),

                    FloatingActionButton(
                      heroTag: "endCall",
                      backgroundColor: Colors.red,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Icon(Icons.call_end),
                    ),

                    FloatingActionButton(
                      heroTag: "camera",
                      backgroundColor:
                          cameraOn ? Colors.green : Colors.orange,
                      onPressed: () {
                        setState(() {
                          cameraOn = !cameraOn;
                        });
                      },
                      child: Icon(
                        cameraOn
                            ? Icons.videocam
                            : Icons.videocam_off,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}