import 'package:flutter/material.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscure = true;
  bool isLoading = false;

  // Demographic categories
  final List<String> categories = [
    "Senior", "Student", "PWD", "Youth", "Farmer",
    "Fisherman", "Tricycle Driver", "Small Business Owner",
    "4Ps", "Tattoo", "Barangay Official", "Parent"
  ];

  final List<String> selectedCategories = [];

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = MediaQuery.of(context).size.width * 0.7;
    return Scaffold(
      backgroundColor: const Color(0xFF00A651),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Semantics(
              label: 'LINKod logo',
              child: Image.asset(
                'assets/images/linkod_logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          "Create an account",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // FULL NAME
                      const Text("Full Name *"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PHONE NUMBER
                      const Text("Phone Number *"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PASSWORD
                      const Text("Password *"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordController,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        "Select your demographic categories:",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((cat) {
                          final bool isSelected = selectedCategories.contains(cat);
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFF00A651),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                            backgroundColor: Colors.grey[200],
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  selectedCategories.add(cat);
                                } else {
                                  selectedCategories.remove(cat);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 30),

                      // SIGN UP BUTTON
                      Center(
                        child: SizedBox(
                          width: buttonWidth,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _signup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A651),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Sign up',
                                    style: TextStyle(fontSize: 18, color: Colors.white),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _signup() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => isLoading = false);
    
  }
}