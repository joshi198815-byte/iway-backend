# Appsmith blueprint: Login + Dashboard

## Goal
Create the base admin web shell in Appsmith:
- login page
- JWT storage
- API base storage
- role-aware navigation
- dashboard with quick access to core admin modules

This is the foundation for:
- Travelers Review
- Collaborators
- Transfers Review
- Anti-Fraud
- Ledger
- Pricing
- Disputes
- Shipments

---

## Appsmith app structure

Recommended pages:
- `Login`
- `Dashboard`
- `TravelersReview`
- `AdminCollaborators`
- `TransfersReview`
- `AntiFraud`
- `Ledger`
- `Pricing`
- `Disputes`
- `Shipments`
- `ShipmentDetail`

---

## Global app state
Store these values after login:
- `jwt`
- `me`
- `apiBase`
- `isLoggedIn`

Recommended default `apiBase`:
```javascript
https://api.iway.one/api
```

Optional fallback candidate if `/api` routing fails in browser:
```javascript
https://api.iway.one
```

---

## Page 1: Login

### Widgets
- `Text_Title`
  - value: `iWay Admin`
- `Input_Email`
- `Input_Password`
  - input type: password
- `Input_ApiBase`
  - default text:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}
```
- `Button_Login`
  - onClick:
```javascript
{{login.run()}}
```
- `Text_LoginError`
  - value:
```javascript
{{login.data?.message || ''}}
```

---

## Query: `login`
Method: `POST`
URL:
```javascript
{{Input_ApiBase.text.trim()}}/auth/login
```
Body:
```json
{
  "email": "{{Input_Email.text.trim().toLowerCase()}}",
  "password": "{{Input_Password.text}}"
}
```
Headers:
```json
{
  "Content-Type": "application/json"
}
```

### On success
```javascript
{{
storeValue('jwt', login.data.accessToken);
storeValue('me', login.data.user);
storeValue('apiBase', Input_ApiBase.text.trim());
storeValue('isLoggedIn', true);
navigateTo('Dashboard');
}}
```

### On error
```javascript
{{showAlert('Login inválido o backend no disponible', 'error')}}
```

---

## Optional fallback login flow
If you want `/api` fallback behavior similar to Flutter, use a JSObject.

### JSObject: `AuthActions`
```javascript
export default {
  async loginWithFallback() {
    const primary = (Input_ApiBase.text || 'https://api.iway.one/api').trim();
    const fallback = primary.endsWith('/api') ? primary.replace(/\/api$/, '') : primary;

    try {
      const result = await loginPrimary.run({ apiBaseOverride: primary });
      await storeValue('jwt', result.accessToken);
      await storeValue('me', result.user);
      await storeValue('apiBase', primary);
      await storeValue('isLoggedIn', true);
      navigateTo('Dashboard');
      return result;
    } catch (error) {
      if (primary === fallback) throw error;
      const result = await loginFallback.run({ apiBaseOverride: fallback });
      await storeValue('jwt', result.accessToken);
      await storeValue('me', result.user);
      await storeValue('apiBase', fallback);
      await storeValue('isLoggedIn', true);
      navigateTo('Dashboard');
      return result;
    }
  }
}
```

Use two queries if needed:
- `loginPrimary`
- `loginFallback`

---

## Session guard for protected pages
On page load for all admin pages except Login:
```javascript
{{
!appsmith.store.jwt ? navigateTo('Login') : ''
}}
```

For admin-only pages like `AdminCollaborators`:
```javascript
{{
appsmith.store.me?.role !== 'admin' ? navigateTo('Dashboard') : ''
}}
```

---

## Page 2: Dashboard

## Widgets

### Header
- `Text_Welcome`
  - value:
```javascript
{{`Hola ${appsmith.store.me?.fullName || ''}`}}
```
- `Text_Role`
  - value:
```javascript
{{`Rol: ${appsmith.store.me?.role || '-'}`}}
```
- `Button_Logout`
  - onClick:
```javascript
{{
storeValue('jwt', '');
storeValue('me', null);
storeValue('isLoggedIn', false);
navigateTo('Login');
}}
```

---

## Dashboard cards
Use button cards or containers.

### Card 1: Travelers Review
- visible: `true`
- action:
```javascript
{{navigateTo('TravelersReview')}}
```

### Card 2: Collaborators
- visible:
```javascript
{{appsmith.store.me?.role === 'admin'}}
```
- action:
```javascript
{{navigateTo('AdminCollaborators')}}
```

### Card 3: Transfers Review
- visible:
```javascript
{{['admin', 'support'].includes(appsmith.store.me?.role)}}
```
- action:
```javascript
{{navigateTo('TransfersReview')}}
```

### Card 4: Anti-Fraud
- visible:
```javascript
{{['admin', 'support'].includes(appsmith.store.me?.role)}}
```
- action:
```javascript
{{navigateTo('AntiFraud')}}
```

### Card 5: Ledger
- visible:
```javascript
{{['admin', 'support'].includes(appsmith.store.me?.role)}}
```
- action:
```javascript
{{navigateTo('Ledger')}}
```

### Card 6: Pricing
- visible:
```javascript
{{['admin', 'support'].includes(appsmith.store.me?.role)}}
```
- action:
```javascript
{{navigateTo('Pricing')}}
```

### Card 7: Disputes
- visible:
```javascript
{{['admin', 'support'].includes(appsmith.store.me?.role)}}
```
- action:
```javascript
{{navigateTo('Disputes')}}
```

### Card 8: Shipments
- visible:
```javascript
{{['admin', 'support'].includes(appsmith.store.me?.role)}}
```
- action:
```javascript
{{navigateTo('Shipments')}}
```

---

## Query: `getMe`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/auth/me
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

On success:
```javascript
{{storeValue('me', getMe.data.user)}}
```

On error:
```javascript
{{
storeValue('jwt', '');
storeValue('me', null);
storeValue('isLoggedIn', false);
navigateTo('Login');
}}
```

Run on Dashboard page load: yes

---

## Suggested left menu
If you prefer a reusable menu component, show these entries:
- Dashboard
- Travelers Review
- Transfers Review
- Anti-Fraud
- Ledger
- Pricing
- Disputes
- Shipments
- Collaborators (admin only)
- Logout

---

## Operational recommendations
- Use `appsmith.store.apiBase` everywhere instead of hardcoding base URL in each page.
- Keep all API queries with the same auth header pattern.
- Build `Login` first, then `Dashboard`, then `TravelersReview`, then `AdminCollaborators`.
- If login works but page queries fail with 404 under `/api`, set `apiBase` to `https://api.iway.one` temporarily and verify proxy routing.

---

## Definition of done
This shell is done when:
- login succeeds against production backend
- JWT is stored
- `/auth/me` works
- role is visible in dashboard
- dashboard navigation works
- admin-only Collaborators menu is hidden for non-admin users
- logout clears session state
