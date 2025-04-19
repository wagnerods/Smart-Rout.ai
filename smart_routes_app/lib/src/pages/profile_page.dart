import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _nameController.text = user!.displayName ?? '';
    }
  }

  Future<void> _saveChanges() async {
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Atualizar nome
      if (_nameController.text.isNotEmpty && _nameController.text != user!.displayName) {
        await user!.updateDisplayName(_nameController.text);
        await user!.reload();
      }

      // Atualizar senha
      if (_newPasswordController.text.isNotEmpty) {
        if (_currentPasswordController.text.isEmpty) {
          throw Exception('Para mudar a senha, insira a senha atual.');
        }

        // Reautenticar o usuário antes de alterar a senha
        final credential = EmailAuthProvider.credential(
          email: user!.email!,
          password: _currentPasswordController.text,
        );

        await user!.reauthenticateWithCredential(credential);
        await user!.updatePassword(_newPasswordController.text);
        await user!.reload();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações salvas com sucesso!')),
      );

      Navigator.pop(context); // Voltar pra Home depois de salvar
    } on FirebaseAuthException catch (e) {
      String message = 'Erro: ${e.message}';
      if (e.code == 'wrong-password') {
        message = 'Senha atual incorreta.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Nenhum usuário logado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.purple,
              child: Icon(
                Icons.person,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person),
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              readOnly: true,
              controller: TextEditingController(text: user!.email ?? ''),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email),
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
                labelText: 'Senha Atual',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock),
                labelText: 'Nova Senha (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Alterações'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
