import { PrismaClient, UserRole, UserStatus } from '@prisma/client';
import { hashPassword } from '../src/common/utils/password.util';

const prisma = new PrismaClient();

function required(name: string) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

async function main() {
  const email = required('INITIAL_ADMIN_EMAIL').toLowerCase();
  const password = required('INITIAL_ADMIN_PASSWORD');
  const fullName = process.env.INITIAL_ADMIN_FULL_NAME?.trim() || 'iWay Production Admin';
  const phone = required('INITIAL_ADMIN_PHONE');
  const countryCode = process.env.INITIAL_ADMIN_COUNTRY_CODE?.trim() || 'GT';

  const passwordHash = await hashPassword(password);

  const user = await prisma.user.upsert({
    where: { email },
    update: {
      fullName,
      phone,
      passwordHash,
      role: UserRole.admin,
      status: UserStatus.active,
      countryCode,
      detectedCountryCode: countryCode,
    },
    create: {
      fullName,
      email,
      phone,
      passwordHash,
      role: UserRole.admin,
      status: UserStatus.active,
      countryCode,
      detectedCountryCode: countryCode,
    },
    select: {
      id: true,
      fullName: true,
      email: true,
      phone: true,
      role: true,
      status: true,
      createdAt: true,
    },
  });

  console.log('production admin ready');
  console.log(JSON.stringify(user, null, 2));
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
