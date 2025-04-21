import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  User? user;
  bool _isLoading = false;
  bool _isPasswordValidated = false;
  String? _photoURL;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user!.displayName ?? '';
      _photoURL = user!.photoURL;
    }
    _newPasswordController.addListener(() {
      setState(() {}); // Atualiza tela quando digita nova senha
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final file = File(pickedFile.path);
        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${user!.uid}.jpg');
        await storageRef.putFile(file);
        final downloadURL = await storageRef.getDownloadURL();

        await user!.updatePhotoURL(downloadURL);
        await user!.reload();
        user = FirebaseAuth.instance.currentUser;

        setState(() {
          _photoURL = downloadURL;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar foto: $e')),
        );
      }
    }
  }

  bool _hasUppercase(String text) => text.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String text) => text.contains(RegExp(r'[a-z]'));
  bool _hasNumber(String text) => text.contains(RegExp(r'\d'));
  bool _hasSpecialCharacter(String text) => text.contains(RegExp(r'[^A-Za-z0-9]'));
  bool _hasMinLength(String text) => text.length >= 8;

  bool _validatePassword(String password) {
    return _hasUppercase(password) &&
           _hasLowercase(password) &&
           _hasNumber(password) &&
           _hasSpecialCharacter(password) &&
           _hasMinLength(password);
  }

  Future<void> _validateCurrentPassword() async {
    if (user == null) return;
    final currentPassword = _currentPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      setState(() {
        _isPasswordValidated = false;
      });
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );
      await user!.reauthenticateWithCredential(credential);
      setState(() {
        _isPasswordValidated = true;
      });
    } on FirebaseAuthException {
      setState(() {
        _isPasswordValidated = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      if (_nameController.text.isNotEmpty && _nameController.text != user!.displayName) {
        await user!.updateDisplayName(_nameController.text);
      }

      if (_isPasswordValidated && _newPasswordController.text.isNotEmpty) {
        if (_newPasswordController.text != _confirmPasswordController.text) {
          throw Exception('A nova senha e a confirmação não coincidem.');
        }
        if (!_validatePassword(_newPasswordController.text)) {
          throw Exception('Senha fraca. Verifique os requisitos.');
        }
        await user!.updatePassword(_newPasswordController.text);
      }

      await user!.reload();
      user = FirebaseAuth.instance.currentUser;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações salvas com sucesso!')),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildPasswordRequirement(String text, bool satisfied) {
    return Row(
      children: [
        Icon(
          satisfied ? Icons.check_circle : Icons.cancel,
          color: satisfied ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Nenhum usuário logado')),
      );
    }

    final newPassword = _newPasswordController.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF90CAF9),
                backgroundImage: _photoURL != null ? NetworkImage(_photoURL!) : null,
                child: _photoURL == null
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
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
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                labelText: 'Senha Atual',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _validateCurrentPassword,
                ),
              ),
            ),
            if (_isPasswordValidated) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock),
                  labelText: 'Nova Senha',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPasswordRequirement('Mínimo 8 caracteres', _hasMinLength(newPassword)),
                  _buildPasswordRequirement('1 letra maiúscula', _hasUppercase(newPassword)),
                  _buildPasswordRequirement('1 letra minúscula', _hasLowercase(newPassword)),
                  _buildPasswordRequirement('1 número', _hasNumber(newPassword)),
                  _buildPasswordRequirement('1 caractere especial', _hasSpecialCharacter(newPassword)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock),
                  labelText: 'Confirmar Nova Senha',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Alterações'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64B5F6),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 6,
                shadowColor: Colors.black45,
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
