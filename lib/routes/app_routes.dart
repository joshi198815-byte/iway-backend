import 'package:flutter/material.dart';
import '../features/splash/splash_screen.dart';
import '../features/home/home_screen.dart';
import '../features/auth/login/login_screen.dart';
import '../features/auth/register/register_screen.dart';
import '../features/auth/register/traveler_register_screen.dart';
import '../features/auth/verification/contact_verification_screen.dart';
import '../features/shipment/create_shipment_screen.dart';
import '../features/shipment/traveler_opportunities_screen.dart';
import '../features/matching/offers_screen.dart';
import '../features/shipment/tracking_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/payments/debts_screen.dart';
import '../features/rating/rating_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/admin/admin_shipment_detail_screen.dart';
import '../features/admin/admin_transfers_screen.dart';
import '../features/admin/admin_travelers_review_screen.dart';
import '../features/admin/admin_ledger_screen.dart';
import '../features/admin/admin_antifraud_screen.dart';
import '../features/admin/admin_disputes_screen.dart';
import '../features/map/map_screen.dart';
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
    '/debts': (context) => const DebtsScreen(),
    '/admin': (context) => const AdminScreen(),
    '/admin_transfers': (context) => const AdminTransfersScreen(),
    '/admin_travelers_review': (context) => const AdminTravelersReviewScreen(),
    '/admin_ledger': (context) => const AdminLedgerScreen(),
    '/admin_antifraud': (context) => const AdminAntiFraudScreen(),
    '/admin_disputes': (context) => const AdminDisputesScreen(),
    '/admin_shipment': (context) {
      final id = ModalRoute.of(context)?.settings.arguments;
      if (id is! String || id.isEmpty) {
        return _invalidArgumentsScreen('Detalle shipment admin');
      }
      return AdminShipmentDetailScreen(shipmentId: id);
    },
    '/profile': (context) => const ProfileScreen(),
    '/map': (context) {
      final shipmentId = ModalRoute.of(context)?.settings.arguments;
      return MapScreen(shipmentId: shipmentId is String ? shipmentId : null);
    },
    '/rating': (context) {
      final id = ModalRoute.of(context)?.settings.arguments;
      if (id is! String || id.isEmpty) {
        return _invalidArgumentsScreen('Calificar');
      }
      return RatingScreen(shipmentId: id);
    },
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
      final id = ModalRoute.of(context)?.settings.arguments;
      if (id is! String || id.isEmpty) {
        return _invalidArgumentsScreen('Chat');
      }
      return ChatScreen(shipmentId: id);
    },
  };
}
