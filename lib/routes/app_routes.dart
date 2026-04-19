import 'package:flutter/material.dart';
import '../features/splash/splash_screen.dart';
import '../features/home/home_screen.dart';
import '../features/auth/login/login_screen.dart';
import '../features/auth/register/register_screen.dart';
import '../features/auth/register/traveler_register_screen.dart';
import '../features/auth/verification/contact_verification_screen.dart';
import '../features/disputes/support_center_screen.dart';
import '../features/shipment/create_shipment_screen.dart';
import '../features/shipment/traveler_opportunities_screen.dart';
import '../features/shipment/my_orders_screen.dart';
import '../features/map/map_screen.dart';
import '../features/matching/offers_screen.dart';
import '../features/shipment/tracking_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/payments/debts_screen.dart';
import '../features/rating/rating_screen.dart';
import '../features/rating/my_ratings_screen.dart';
import '../features/profile/profile_screen.dart';

class AppRoutes {
  static const String initial = '/';

  static Widget _invalidArgumentsScreen(String routeName) {
    return Scaffold(
      appBar: AppBar(title: Text(routeName)),
      body: const Center(
        child: Text('Faltan argumentos para abrir esta pantalla.'),
      ),
    );
  }

  static final Map<String, WidgetBuilder> routes = {
    '/': (context) => const SplashScreen(),
    '/home': (context) => const HomeScreen(),
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),
    '/register_traveler': (context) => const TravelerRegisterScreen(),
    '/verify_contact': (context) => const ContactVerificationScreen(),
    '/create_shipment': (context) => const CreateShipmentScreen(),
    '/traveler_opportunities': (context) => const TravelerOpportunitiesScreen(),
    '/my_orders': (context) => const MyOrdersScreen(),
    '/support': (context) => const SupportCenterScreen(),
    '/debts': (context) => const DebtsScreen(),
    '/map': (context) {
      final id = ModalRoute.of(context)?.settings.arguments;
      return MapScreen(shipmentId: id is String && id.isNotEmpty ? id : null);
    },
    '/profile': (context) => const ProfileScreen(),
    '/rating': (context) {
      final id = ModalRoute.of(context)?.settings.arguments;
      if (id is! String || id.isEmpty) {
        return _invalidArgumentsScreen('Calificar');
      }
      return RatingScreen(shipmentId: id);
    },
    '/my_ratings': (context) => const MyRatingsScreen(),
    '/offers': (context) {
      final id = ModalRoute.of(context)?.settings.arguments;
      if (id is! String || id.isEmpty) {
        return _invalidArgumentsScreen('Ofertas');
      }
      return OffersScreen(shipmentId: id);
    },
    '/tracking': (context) {
      final id = ModalRoute.of(context)?.settings.arguments;
      if (id is! String || id.isEmpty) {
        return _invalidArgumentsScreen('Tracking');
      }
      return TrackingScreen(shipmentId: id);
    },
    '/notifications': (context) => const NotificationsScreen(),
    '/chat': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        return ChatScreen(shipmentId: args);
      }
      if (args is Map) {
        final shipmentId = args['shipmentId']?.toString() ?? '';
        final initialDraft = args['initialDraft']?.toString();
        if (shipmentId.isNotEmpty) {
          return ChatScreen(shipmentId: shipmentId, initialDraft: initialDraft);
        }
      }
      return _invalidArgumentsScreen('Chat');
    },
  };
}
