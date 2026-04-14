"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const password_util_1 = require("../src/common/utils/password.util");
const prisma = new client_1.PrismaClient();
async function main() {
    const adminPasswordHash = await (0, password_util_1.hashPassword)(process.env.STAGING_ADMIN_PASSWORD ?? 'change-me-now');
    const supportPasswordHash = await (0, password_util_1.hashPassword)(process.env.STAGING_SUPPORT_PASSWORD ?? 'change-me-now');
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
            role: client_1.UserRole.admin,
            status: client_1.UserStatus.active,
            phone: '+50255550001',
        },
        create: {
            fullName: 'iWay Admin Staging',
            email: 'admin-staging@iway.local',
            phone: '+50255550001',
            passwordHash: adminPasswordHash,
            role: client_1.UserRole.admin,
            status: client_1.UserStatus.active,
            countryCode: 'GT',
            detectedCountryCode: 'GT',
        },
    });
    await prisma.user.upsert({
        where: { email: 'support-staging@iway.local' },
        update: {
            fullName: 'iWay Support Staging',
            passwordHash: supportPasswordHash,
            role: client_1.UserRole.support,
            status: client_1.UserStatus.active,
            phone: '+50255550002',
        },
        create: {
            fullName: 'iWay Support Staging',
            email: 'support-staging@iway.local',
            phone: '+50255550002',
            passwordHash: supportPasswordHash,
            role: client_1.UserRole.support,
            status: client_1.UserStatus.active,
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
//# sourceMappingURL=seed.staging.js.map