import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_notification.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const String _readNewsBoxName = '_readNewsBox';
  Box<dynamic>? _readNewsBox;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    try {
      _readNewsBox = await Hive.openBox(_readNewsBoxName);
      setState(() {
        // Cargar estado de leído desde Hive
        for (var notification in _notifications) {
          final isRead =
              _readNewsBox?.get(notification.id, defaultValue: false) ?? false;
          notification.isRead = isRead;
        }
      });
    } catch (e) {
      debugPrint('Error initializing Hive for notifications: $e');
    }
  }

  final List<AppNotification> _notifications = [
    AppNotification(
      id: '1',
      title: '🎉 Nueva temporada de avistamiento',
      description:
          'Comienza la temporada de migración de aves. ¡No te pierdas los cisnes de cuello negro en la Laguna Principal!',
      dateLabel: 'Hoy, 10:30',
      type: 'Evento',
    ),
    AppNotification(
      id: '2',
      title: '🌳 Taller de fotografía de naturaleza',
      description:
          'Inscríbete al taller gratuito este sábado a las 9:00 AM. Cupos limitados.',
      dateLabel: 'Ayer',
      type: 'Evento',
    ),
    AppNotification(
      id: '3',
      title: '⚠️ Sendero temporal cerrado',
      description:
          'El Sendero del Bosque estará cerrado por mantenimiento hasta el viernes 29 de noviembre.',
      dateLabel: '23 Nov',
      type: 'Aviso',
    ),
    AppNotification(
      id: '4',
      title: '🦊 Nueva carta disponible',
      description:
          'Se ha agregado una nueva especie a la colección: Zorro Culpeo. ¡Búscala en el sendero norte!',
      dateLabel: '20 Nov',
      type: 'Novedad',
      isRead: true,
    ),
    AppNotification(
      id: '5',
      title: '☕ Nuevo emprendimiento local',
      description:
          'Conoce el "Café Mirador del Biobío" en la entrada principal. Apoya el comercio local.',
      dateLabel: '18 Nov',
      type: 'Novedad',
      isRead: true,
    ),
    AppNotification(
      id: '6',
      title: '📢 Horarios extendidos en verano',
      description:
          'A partir del 1 de diciembre, el parque estará abierto de 7:00 AM a 8:00 PM.',
      dateLabel: '15 Nov',
      type: 'Aviso',
      isRead: true,
    ),
  ];

  Future<void> _markAsRead(String id) async {
    setState(() {
      final notification = _notifications.firstWhere((n) => n.id == id);
      notification.isRead = true;
    });

    // Persistir en Hive
    try {
      await _readNewsBox?.put(id, true);
    } catch (e) {
      debugPrint('Error saving read status: $e');
    }

    // Navegar a detalle
    if (!mounted) return;
    _showNotificationDetail(id);
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });

    // Persistir todos en Hive
    try {
      for (var notification in _notifications) {
        await _readNewsBox?.put(notification.id, true);
      }
    } catch (e) {
      debugPrint('Error saving all read status: $e');
    }
  }

  void _showNotificationDetail(String id) {
    final notification = _notifications.firstWhere((n) => n.id == id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(
                        notification.type,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getTypeColor(
                          notification.type,
                        ).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      notification.type,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getTypeColor(notification.type),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notification.dateLabel,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                notification.description,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'evento':
        return Colors.blue;
      case 'aviso':
        return Colors.orange;
      case 'novedad':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: const Color(AppConstants.primaryGreen),
        foregroundColor: Colors.white,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: const Text(
                'Marcar todas',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay notificaciones',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tienes $unreadCount notificación${unreadCount > 1 ? 'es' : ''} sin leer',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return ListTile(
                        onTap: () {
                          if (!notification.isRead) {
                            _markAsRead(notification.id);
                          } else {
                            _showNotificationDetail(notification.id);
                          }
                        },
                        tileColor: notification.isRead
                            ? null
                            : Colors.blue.shade50.withValues(alpha: 0.3),
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: notification.isRead
                                ? Colors.transparent
                                : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              notification.description,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getTypeColor(
                                      notification.type,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getTypeColor(
                                        notification.type,
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    notification.type,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getTypeColor(notification.type),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  notification.dateLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
