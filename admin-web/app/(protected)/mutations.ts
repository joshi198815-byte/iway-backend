'use server';

import { revalidatePath } from 'next/cache';
import {
  reviewTransfer,
  reviewTraveler,
  runTravelerKyc,
  updateShipmentStatus,
  updateTravelerPayoutHold,
} from '@/lib/api';
import { requireSession } from '@/lib/auth';

async function getToken() {
  const session = await requireSession();
  return session.token as string;
}

function queryValue(formData: FormData, key: string) {
  return String(formData.get(key) || '').trim();
}

export async function reviewTravelerAction(formData: FormData) {
  const token = await getToken();
  const userId = queryValue(formData, 'userId');
  const action = queryValue(formData, 'action');
  const reason = queryValue(formData, 'reason');
  const path = queryValue(formData, 'path') || '/travelers-review';

  if (userId && action) {
    await reviewTraveler(token, userId, action, reason || undefined);
    revalidatePath(path);
  }
}

export async function payoutHoldAction(formData: FormData) {
  const token = await getToken();
  const userId = queryValue(formData, 'userId');
  const reason = queryValue(formData, 'reason');
  const path = queryValue(formData, 'path') || '/travelers-review';
  const enabled = queryValue(formData, 'enabled') === 'true';

  if (userId) {
    await updateTravelerPayoutHold(token, userId, enabled, reason || undefined);
    revalidatePath(path);
  }
}

export async function runKycAction(formData: FormData) {
  const token = await getToken();
  const userId = queryValue(formData, 'userId');
  const path = queryValue(formData, 'path') || '/travelers-review';

  if (userId) {
    await runTravelerKyc(token, userId);
    revalidatePath(path);
  }
}

export async function reviewTransferAction(formData: FormData) {
  const token = await getToken();
  const transferId = queryValue(formData, 'transferId');
  const action = queryValue(formData, 'action');
  const reason = queryValue(formData, 'reason');
  const path = queryValue(formData, 'path') || '/transfers-review';

  if (transferId && action) {
    await reviewTransfer(token, transferId, action, reason || undefined);
    revalidatePath(path);
  }
}

export async function updateShipmentStatusAction(formData: FormData) {
  const token = await getToken();
  const shipmentId = queryValue(formData, 'shipmentId');
  const status = queryValue(formData, 'status');
  const path = queryValue(formData, 'path') || '/shipments';

  if (shipmentId && status) {
    await updateShipmentStatus(token, shipmentId, status);
    revalidatePath('/shipments');
    revalidatePath(path);
  }
}
