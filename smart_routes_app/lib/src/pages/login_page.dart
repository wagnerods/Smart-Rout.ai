import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool isLogin = true; // <-- adicionando alternância entre login/cadastro

  Future<void> authenticate() async {
    setState(() => isLoading = true);

    try {
      if (isLogin) {
        // Faz login
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        // Faz cadastro
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
        errorMsg = 'Senha fraca. Use pelo menos 6 caracteres.';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      setState(() => isLoading = false);
    }
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
              const Icon(Icons.map, size: 100, color: Colors.blue),
              const SizedBox(height: 32),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
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
                child: Text(isLogin
                    ? 'Não tem conta? Cadastre-se'
                    : 'Já tem conta? Fazer login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
