# POST_DEPLOY_SMOKE_TESTS.md

Haz estas 5 pruebas rápidas apenas Render marque ambos servicios como `Live`:

1. **Admin Web login**
   - Entra con una cuenta `ADMIN`.
   - Verifica que carguen: Dashboard, Tarifas y Wallet, Pagos viajeros, KYC viajeros y Banners.

2. **Guardar tarifas**
   - En Admin Web, cambia temporalmente:
     - comisión por libra
     - comisión por tierra %
   - Guarda.
   - En la app, abre una oferta de viajero y confirma que la comisión y el neto reflejan el nuevo valor.

3. **Aprobar comprobante de pago**
   - Entra a `Pagos viajeros`.
   - Abre una transferencia pendiente con imagen.
   - Aprueba.
   - Confirma en la app del viajero que llega la notificación y que el wallet se actualiza al refrescar/recibir evento.

4. **KYC de viajero**
   - En `KYC viajeros`, abre un viajero pendiente.
   - Verifica que carguen selfie y documento.
   - Aprueba o rechaza y confirma que el estado cambia en el backend/admin sin error 500/403 inesperado.

5. **Banner feed editor**
   - En `Banners`, cambia un título o `mediaUrl` del feed de Usuario o Viajero.
   - Guarda.
   - Abre la app y confirma que el carrusel correspondiente muestra el cambio.
