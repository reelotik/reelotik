import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart'; // Import Added

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  bool isLoading = false;
  bool isOtpSent = false;
  String verificationId = "";

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Updated Firestore Logic
  Future<void> saveUserToFirestore(UserCredential user) async {
    final doc = await FirebaseFirestore.instance.collection("users").doc(user.user!.uid).get();

    if (!doc.exists) {
      await FirebaseFirestore.instance.collection("users").doc(user.user!.uid).set({
        "uid": user.user!.uid,
        "phone": user.user!.phoneNumber,
        "firstName": "",
        "lastName": "",
        "fullName": "",
        "photoUrl": "",
        "isOnline": true,
        "lastSeen": FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection("users").doc(user.user!.uid).update({
        "isOnline": true,
        "lastSeen": FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendOtp() async {
    if (phoneController.text.trim().length < 10) {
      showError("Enter valid 10-digit phone number");
      return;
    }
    setState(() => isLoading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: "+91${phoneController.text.trim()}",
      verificationCompleted: (PhoneAuthCredential credential) async {
        UserCredential user = await FirebaseAuth.instance.signInWithCredential(credential);
        await saveUserToFirestore(user);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
      },
      verificationFailed: (FirebaseAuthException e) {
        showError(e.message ?? "Verification Failed");
        setState(() => isLoading = false);
      },
      codeSent: (String vid, int? token) {
        setState(() {
          verificationId = vid;
          isOtpSent = true;
          isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String vid) => verificationId = vid,
    );
  }

  Future<void> verifyOtp() async {
    if (otpController.text.trim().isEmpty) {
      showError("Enter OTP");
      return;
    }
    try {
      setState(() => isLoading = true);
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpController.text.trim(),
      );

      UserCredential user = await FirebaseAuth.instance.signInWithCredential(credential);
      await saveUserToFirestore(user);

      final doc = await FirebaseFirestore.instance.collection("users").doc(user.user!.uid).get();

      if (!mounted) return;
      if ((doc.data()?["firstName"] ?? "").isEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      showError("Invalid OTP");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reelotik Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android, size: 100, color: Colors.green),
            const SizedBox(height: 30),
            if (!isOtpSent)
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Phone Number (+91)", border: OutlineInputBorder(), prefixText: "+91 "),
              )
            else
              TextFormField(
                controller: otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Enter 6-Digit OTP", border: OutlineInputBorder()),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : (isOtpSent ? verifyOtp : sendOtp),
                child: isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text(isOtpSent ? "Verify OTP" : "Send OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}