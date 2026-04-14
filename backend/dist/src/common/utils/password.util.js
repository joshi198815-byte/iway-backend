"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.hashPassword = hashPassword;
exports.verifyPassword = verifyPassword;
const crypto_1 = require("crypto");
const util_1 = require("util");
const scrypt = (0, util_1.promisify)(crypto_1.scrypt);
async function hashPassword(password) {
    const salt = (0, crypto_1.randomBytes)(16).toString('hex');
    const derivedKey = (await scrypt(password, salt, 64));
    return `${salt}:${derivedKey.toString('hex')}`;
}
async function verifyPassword(password, storedHash) {
    const [salt, key] = storedHash.split(':');
    if (!salt || !key) {
        return false;
    }
    const derivedKey = (await scrypt(password, salt, 64));
    const storedKeyBuffer = Buffer.from(key, 'hex');
    if (storedKeyBuffer.length !== derivedKey.length) {
        return false;
    }
    return (0, crypto_1.timingSafeEqual)(storedKeyBuffer, derivedKey);
}
//# sourceMappingURL=password.util.js.map