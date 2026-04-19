import 'package:flutter/material.dart';

import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/services/saved_recipient_service.dart';
import 'package:iway_app/services/session_service.dart';

class RecipientManagementScreen extends StatefulWidget {
  const RecipientManagementScreen({super.key});

  @override
  State<RecipientManagementScreen> createState() => _RecipientManagementScreenState();
}

class _RecipientManagementScreenState extends State<RecipientManagementScreen> {
  final _service = SavedRecipientService();
  List<SavedRecipient> _recipients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _recipients = [];
        _loading = false;
      });
      return;
    }

    final recipients = await _service.getAll(userId);
    if (!mounted) return;
    setState(() {
      _recipients = recipients;
      _loading = false;
    });
  }

  Future<void> _saveRecipient([SavedRecipient? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final stateController = TextEditingController(text: existing?.region ?? '');
    final cityController = TextEditingController(text: existing?.city ?? '');
    final addressController = TextEditingController(text: existing?.address ?? '');

    final recipient = await showModalBottomSheet<SavedRecipient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Nuevo destinatario' : 'Editar destinatario',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 12),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono USA')),
                const SizedBox(height: 12),
                TextField(controller: stateController, decoration: const InputDecoration(labelText: 'Estado')),
                const SizedBox(height: 12),
                TextField(controller: cityController, decoration: const InputDecoration(labelText: 'Ciudad')),
                const SizedBox(height: 12),
                TextField(controller: addressController, maxLines: 2, decoration: const InputDecoration(labelText: 'Dirección')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        SavedRecipient(
                          name: nameController.text.trim(),
                          phone: phoneController.text.trim(),
                          address: addressController.text.trim(),
                          country: 'Estados Unidos',
                          region: stateController.text.trim(),
                          city: cityController.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Guardar destinatario'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (recipient == null) return;
    if (recipient.name.isEmpty || recipient.phone.isEmpty || recipient.region.isEmpty || recipient.city.isEmpty || recipient.address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los datos del destinatario.')),
      );
      return;
    }

    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;
    await _service.save(userId, recipient);
    await _load();
  }

  Future<void> _deleteRecipient(SavedRecipient recipient) async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;
    await _service.remove(userId, recipient);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Destinatarios en USA')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveRecipient,
        label: const Text('Crear'),
        icon: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _recipients.isEmpty
              ? const Center(child: Text('Todavía no has guardado destinatarios.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  itemCount: _recipients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final recipient = _recipients[index];
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  recipient.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _saveRecipient(recipient),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _deleteRecipient(recipient),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          Text('${recipient.city}, ${recipient.region}', style: const TextStyle(color: AppTheme.muted)),
                          const SizedBox(height: 4),
                          Text(recipient.phone, style: const TextStyle(color: AppTheme.muted)),
                          const SizedBox(height: 4),
                          Text(recipient.address, style: const TextStyle(color: AppTheme.muted)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
