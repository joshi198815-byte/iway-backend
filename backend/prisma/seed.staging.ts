import { PrismaClient, UserRole, UserStatus } from '@prisma/client';
import { hashPassword } from '../src/common/utils/password.util';

const prisma = new PrismaClient();

async function main() {
  const adminPasswordHash = await hashPassword(process.env.STAGING_ADMIN_PASSWORD ?? 'change-me-now');
  const supportPasswordHash = await hashPassword(process.env.STAGING_SUPPORT_PASSWORD ?? 'change-me-now');

  await prisma.pricingSettings.upsert({
    where: { id: 'default' },
    update: {
      commissionPerLb: 1.5,
      groundCommissionPercent: 0.04,
    },
    create: {
      id: 'default',
      commissionPerLb: 1.5,
      groundCommissionPercent: 0.04,
    },
  });

  await prisma.user.upsert({
    where: { email: 'admin-staging@iway.local' },
    update: {
      fullName: 'iWay Admin Staging',
      passwordHash: adminPasswordHash,
      role: UserRole.admin,
      status: UserStatus.active,
      phone: '+50255550001',
    },
    create: {
      fullName: 'iWay Admin Staging',
      email: 'admin-staging@iway.local',
      phone: '+50255550001',
      passwordHash: adminPasswordHash,
      role: UserRole.admin,
      status: UserStatus.active,
      countryCode: 'GT',
      detectedCountryCode: 'GT',
    },
  });

  await prisma.user.upsert({
    where: { email: 'support-staging@iway.local' },
    update: {
      fullName: 'iWay Support Staging',
      passwordHash: supportPasswordHash,
      role: UserRole.support,
      status: UserStatus.active,
      phone: '+50255550002',
    },
    create: {
      fullName: 'iWay Support Staging',
      email: 'support-staging@iway.local',
      phone: '+50255550002',
      passwordHash: supportPasswordHash,
      role: UserRole.support,
      status: UserStatus.active,
      countryCode: 'GT',
      detectedCountryCode: 'GT',
    },
  });

  console.log('staging seed complete');
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
