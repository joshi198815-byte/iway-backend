import nodemailer from 'nodemailer';

export type PasswordRecoveryMailPayload = {
  to: string;
  code: string;
};

function smtpConfigured() {
  return Boolean(
    process.env.SMTP_HOST &&
      process.env.SMTP_PORT &&
      process.env.SMTP_USER &&
      process.env.SMTP_PASS &&
      process.env.SMTP_FROM,
  );
}

export async function sendPasswordRecoveryEmail(payload: PasswordRecoveryMailPayload) {
  if (!smtpConfigured()) {
    throw new Error('smtp_not_configured');
  }

  const port = Number(process.env.SMTP_PORT ?? 587);
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  await transporter.sendMail({
    from: process.env.SMTP_FROM,
    to: payload.to,
    subject: 'Recuperación de contraseña iWay',
    text: `Tu código de recuperación iWay es ${payload.code}. Vence en 10 minutos.`,
    html: `
      <div style="font-family:Arial,sans-serif;line-height:1.5;color:#111">
        <h2>Recuperación de contraseña</h2>
        <p>Tu código de recuperación de iWay es:</p>
        <p style="font-size:28px;font-weight:700;letter-spacing:4px;">${payload.code}</p>
        <p>Este código vence en 10 minutos.</p>
      </div>
    `,
  });
}
