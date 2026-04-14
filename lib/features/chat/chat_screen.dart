import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/chat/models/message_model.dart';
import 'package:iway_app/features/chat/services/chat_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_skeleton.dart';

class ChatScreen extends StatefulWidget {
  final String shipmentId;

  const ChatScreen({super.key, required this.shipmentId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final chatService = ChatService();
  final controller = TextEditingController();
  final realtime = RealtimeService.instance;

  List<MessageModel> messages = [];
  bool loading = true;
  bool sending = false;
  StreamSubscription<dynamic>? chatSubscription;

  @override
  void initState() {
    super.initState();
    loadMessages();
    bindRealtime();
  }

  Future<void> bindRealtime() async {
    await realtime.joinChat(widget.shipmentId);
    chatSubscription = realtime.chatMessages.listen((data) {
      if (data is! Map || data['shipmentId']?.toString() != widget.shipmentId) {
        return;
      }

      final rawMessage = data['message'];
      if (rawMessage is! Map) {
        loadMessages();
        return;
      }

      final message = MessageModel.fromBackendJson(
        rawMessage.map((key, value) => MapEntry(key.toString(), value)),
        shipmentId: widget.shipmentId,
      );

      if (!mounted) return;
      setState(() {
        final exists = messages.any((item) => item.id == message.id);
        if (!exists) {
          messages = [...messages, message]..sort((a, b) => a.fecha.compareTo(b.fecha));
        }
        loading = false;
      });
    });
  }

  Future<void> loadMessages() async {
    try {
      final data = await chatService.getMessages(widget.shipmentId);

      if (!mounted) return;

      setState(() {
        messages = data;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el chat.')),
      );
    }
  }

  Future<void> send() async {
    final text = controller.text.trim();

    if (text.isEmpty || sending) return;

    setState(() => sending = true);

    try {
      await chatService.sendMessage(widget.shipmentId, text);
      controller.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el mensaje.')),
      );
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  void dispose() {
    chatSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SessionService.currentUserId;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              Color(0xFF111216),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: Row(
                  children: [
                    AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Chat del envío',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Comunicación protegida dentro de iWay.',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: loading
                    ? ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        children: const [
                          Align(alignment: Alignment.centerLeft, child: AppSkeletonBlock(height: 74, width: 220, margin: EdgeInsets.only(bottom: 12))),
                          Align(alignment: Alignment.centerRight, child: AppSkeletonBlock(height: 82, width: 180, margin: EdgeInsets.only(bottom: 12))),
                          Align(alignment: Alignment.centerLeft, child: AppSkeletonBlock(height: 68, width: 250, margin: EdgeInsets.only(bottom: 12))),
                        ],
                      )
                    : messages.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.forum_outlined,
                            title: 'Todavía no hay mensajes',
                            subtitle: 'Cuando alguna de las partes escriba, la conversación aparecerá aquí en tiempo real.',
                          )
                        : ListView.builder(
                            reverse: false,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final m = messages[index];
                              final isMine = m.senderId == currentUserId;

                              return Align(
                                alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                                  constraints: const BoxConstraints(maxWidth: 290),
                                  decoration: BoxDecoration(
                                    color: isMine ? Colors.white : AppTheme.surface,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: Radius.circular(isMine ? 18 : 6),
                                      bottomRight: Radius.circular(isMine ? 6 : 18),
                                    ),
                                    border: Border.all(
                                      color: isMine ? Colors.white : AppTheme.border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.mensaje,
                                        style: TextStyle(
                                          color: isMine ? Colors.black : Colors.white,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        formatTime(m.fecha),
                                        style: TextStyle(
                                          color: isMine ? Colors.black54 : AppTheme.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLines: 4,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => send(),
                            decoration: const InputDecoration(
                              hintText: 'Escribe un mensaje...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: sending ? null : send,
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: sending ? AppTheme.surfaceSoft : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.send_rounded, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

