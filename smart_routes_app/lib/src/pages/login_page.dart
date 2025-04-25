import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final nameController = TextEditingController();
  File? _profileImage;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;
  bool isLogin = true;

  final RegExp passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~_])[A-Za-z\d!@#\$&*~_]{8,}$'
  );

  Future<void> authenticate() async {
    setState(() => isLoading = true);

    try {
      if (!isLogin) {
        await _saveUserData();
        if (passwordController.text != confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('As senhas não conferem.'))
          );
          setState(() => isLoading = false);
          return;
        }
        if (!passwordRegex.hasMatch(passwordController.text)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Senha não atende aos requisitos de segurança.'))
          );
          setState(() => isLoading = false);
          return;
        }
      }

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Erro ao autenticar.';
      if (e.code == 'user-not-found') {
        errorMsg = 'Usuário não encontrado.';
      } else if (e.code == 'wrong-password') {
        errorMsg = 'Senha incorreta.';
      } else if (e.code == 'email-already-in-use') {
        errorMsg = 'E-mail já cadastrado.';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'E-mail inválido.';
      } else if (e.code == 'weak-password') {
        errorMsg = 'Senha fraca.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      setState(() => isLoading = false);
    }
  }
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', nameController.text.trim());

    if (_profileImage != null) {
      await prefs.setString('profile_image_path', _profileImage!.path);
    }
  }

  Widget passwordChecklist() {
    final password = passwordController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        checklistItem('Mínimo 8 caracteres', password.length >= 8),
        checklistItem('Pelo menos 1 número', RegExp(r'\d').hasMatch(password)),
        checklistItem('Pelo menos 1 letra minúscula', RegExp(r'[a-z]').hasMatch(password)),
        checklistItem('Pelo menos 1 letra maiúscula', RegExp(r'[A-Z]').hasMatch(password)),
        checklistItem('Pelo menos 1 caractere especial', RegExp(r'[!@#\$&*~_]').hasMatch(password)),
      ],
    );
  }

  Widget checklistItem(String text, bool valid) {
    return Row(
      children: [
        Icon(valid ? Icons.check_circle : Icons.cancel,
            size: 18, color: valid ? Colors.green : Colors.red),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/nextstop_logo.png',
                width: 200,
                height: 200,
                scale: 0.8,
              ),
              if (!isLogin) ...[
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                    backgroundColor: Colors.grey[200],
                    child: _profileImage == null ? const Icon(Icons.camera_alt, size: 32, color: Colors.grey) : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                ),
              ),              
              const SizedBox(height: 24),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: authenticate,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: const Color(0xFF5DB2FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(isLogin ? 'Entrar' : 'Cadastrar'),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(
                  isLogin ? 'Não tem conta? Cadastre-se' : 'Já tem conta? Fazer login',
                  style: const TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
