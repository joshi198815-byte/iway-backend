# Appsmith page blueprint: Admin Collaborators

## Goal
Allow a master admin to:
- list collaborators
- create collaborator users
- assign role (`admin` or `support`)
- reset collaborator password
- block / reactivate collaborator accounts

This page is backed by admin-only backend endpoints.

---

## Backend endpoints

### List collaborators
`GET /users/admin/collaborators`

### Create collaborator
`POST /users/admin/collaborators`

Body:
```json
{
  "fullName": "María Operaciones",
  "email": "maria@iway.one",
  "phone": "+50255551111",
  "role": "support",
  "password": "TempPass123!"
}
```

`password` is optional. If omitted, backend generates a temporary password.

### Update collaborator
`PATCH /users/admin/collaborators/:userId`

Body:
```json
{
  "role": "admin",
  "status": "active",
  "fullName": "María Operaciones"
}
```

### Reset password
`POST /users/admin/collaborators/:userId/reset-password`

Body:
```json
{
  "password": "NuevaTemp123!"
}
```

`password` is optional. If omitted, backend generates a temporary password.

---

## Page name
`AdminCollaborators`

---

## Widgets

### Top section
- `Text_Title` → `Collaborators`
- `Button_Refresh` → `{{getCollaborators.run()}}`

### Left side: table
- `Table_Collaborators`
  - data:
```javascript
{{getCollaborators.data?.collaborators || []}}
```

Visible columns:
- fullName
- email
- phone
- role
- status
- createdAt
- updatedAt

### Right side: create/edit form
- `Input_FullName`
- `Input_Email`
- `Input_Phone`
- `Select_Role`
  - options:
```javascript
{{[
  { label: 'Support', value: 'support' },
  { label: 'Admin', value: 'admin' }
]}}
```
- `Input_Password`
  - helper text: `Déjalo vacío para generar clave temporal`
- `Button_CreateCollaborator`
  - onClick: `{{createCollaborator.run()}}`

### Selected collaborator controls
- `Text_SelectedUser`
- `Select_SelectedRole`
- `Select_SelectedStatus`
- `Button_SaveCollaborator`
- `Input_ResetPassword`
- `Button_ResetPassword`

---

## Queries

### getCollaborators
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/users/admin/collaborators
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

### createCollaborator
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/users/admin/collaborators
```
Body:
```json
{
  "fullName": "{{Input_FullName.text}}",
  "email": "{{Input_Email.text}}",
  "phone": "{{Input_Phone.text}}",
  "role": "{{Select_Role.selectedOptionValue}}",
  "password": "{{Input_Password.text}}"
}
```
On success:
```javascript
{{
showAlert('Colaborador creado', 'success');
storeValue('lastTemporaryPassword', createCollaborator.data?.temporaryPassword || '');
getCollaborators.run();
}}
```

Show the generated password in a text/modal widget:
```javascript
{{appsmith.store.lastTemporaryPassword || ''}}
```

---

### updateCollaborator
Method: `PATCH`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/users/admin/collaborators/{{Table_Collaborators.selectedRow.id}}
```
Body:
```json
{
  "role": "{{Select_SelectedRole.selectedOptionValue}}",
  "status": "{{Select_SelectedStatus.selectedOptionValue}}",
  "fullName": "{{Table_Collaborators.selectedRow.fullName}}"
}
```
On success:
```javascript
{{
showAlert('Colaborador actualizado', 'success');
getCollaborators.run();
}}
```

---

### resetCollaboratorPassword
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/users/admin/collaborators/{{Table_Collaborators.selectedRow.id}}/reset-password
```
Body:
```json
{
  "password": "{{Input_ResetPassword.text}}"
}
```
On success:
```javascript
{{
showAlert('Contraseña reiniciada', 'success');
storeValue('lastTemporaryPassword', resetCollaboratorPassword.data?.temporaryPassword || '');
}}
```

---

## Notes
- This page should be visible only for logged-in `admin` users.
- `support` should not manage other collaborators.
- When the backend returns `temporaryPassword`, display it immediately and instruct the operator to copy it once.
- Later, if you want, we can add `mustChangePassword` flow on first login.

## Definition of done
- admin can create support/admin collaborators
- admin can change role
- admin can block/reactivate collaborator
- admin can reset password
- temporary password is shown once after create/reset
