import 'package:flutter/material.dart';

class GroupAudioCallScreen extends StatefulWidget {
  final String groupName;

  const GroupAudioCallScreen({
    super.key,
    required this.groupName,
  });

  @override
  State<GroupAudioCallScreen> createState() =>
      _GroupAudioCallScreenState();
}

class _GroupAudioCallScreenState
    extends State<GroupAudioCallScreen> {
  bool muted = false;
  bool speaker = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            const CircleAvatar(
              radius: 60,
              child: Icon(
                Icons.group,
                size: 60,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              widget.groupName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Group Audio Call",
              style: TextStyle(
                color: Colors.white54,
              ),
            ),

            const Spacer(),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: "mute",
                  backgroundColor:
                      muted ? Colors.orange : Colors.grey,
                  onPressed: () {
                    setState(() {
                      muted = !muted;
                    });
                  },
                  child: Icon(
                    muted
                        ? Icons.mic_off
                        : Icons.mic,
                  ),
                ),

                FloatingActionButton(
                  heroTag: "end",
                  backgroundColor: Colors.red,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.call_end),
                ),

                FloatingActionButton(
                  heroTag: "speaker",
                  backgroundColor:
                      speaker ? Colors.green : Colors.grey,
                  onPressed: () {
                    setState(() {
                      speaker = !speaker;
                    });
                  },
                  child: const Icon(Icons.volume_up),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}