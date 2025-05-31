#!/usr/bin/env node

/**
 * Daily Horoscope WhatsApp Sender
 * Scrapes Spanish horoscopes and sends via WhatsApp Web
 *
 * @author Camilo Joga
 * @version 1.0.0
 */

const { Client, LocalAuth } = require("whatsapp-web.js");
const puppeteer = require("puppeteer");
const schedule = require("node-schedule");
const fs = require("fs").promises;
const path = require("path");
const qrcode = require("qrcode-terminal");
const healthApp = require("./healthcheck");
const pupeeteerArgs = [
  "--no-sandbox",
  "--disable-setuid-sandbox",
  "--disable-dev-shm-usage",
  "--disable-accelerated-2d-canvas",
  "--no-first-run",
  "--no-zygote",
  "--disable-gpu",
  "--disable-crash-reporter",
  "--disable-crashpad",
  "--disable-background-timer-throttling",
  "--disable-backgrounding-occluded-windows",
  "--disable-renderer-backgrounding",
  "--disable-features=TranslateUI",
  "--disable-ipc-flooding-protection",
  "--single-process",
];

require("dotenv").config();

class HoroscopeWhatsAppBot {
  constructor() {
    this.whatsappClient = null;
    this.isReady = false;
    this.recipientNumber = process.env.RECIPIENT_PHONE;
    this.signs = process.env.HOROSCOPES_SIGNS.split(",");
    this.baseUrl = "https://www.lecturas.com/horoscopo";
    console.log("🌟 Inicializando Horoscope WhatsApp Bot...");
    this.setupWhatsAppClient();
    this.startHealthServer();
  }

  setupWhatsAppClient() {
    console.log("📱 Configurando cliente de WhatsApp...");

    this.whatsappClient = new Client({
      authStrategy: new LocalAuth({
        clientId: "horoscope-bot",
        dataPath: "./.wwebjs_auth",
      }),
      puppeteer: {
        headless: true,
        args: pupeeteerArgs,
      },
    });

    this.whatsappClient.on("qr", (qr) => {
      console.log("\n🔗 CÓDIGO QR GENERADO:");
      console.log("📱 Escanea este código QR con tu WhatsApp:");
      qrcode.generate(qr, { small: true });
      console.log("\n⏳ Esperando escaneo...");
    });

    this.whatsappClient.on("ready", () => {
      console.log("✅ WhatsApp Client está listo!");
      console.log(`📞 Conectado como: ${this.whatsappClient.info.pushname}`);
      this.isReady = true;
      this.scheduleHoroscopes();

      if (process.env.SEND_ON_STARTUP === "true") {
        console.log("🚀 Enviando horóscopo de prueba...");
        setTimeout(() => this.sendTestMessage(), 5000);
      }
    });

    this.whatsappClient.on("authenticated", () => {
      console.log("🔐 Autenticación exitosa!");
    });

    this.whatsappClient.on("auth_failure", (msg) => {
      console.error("❌ Falló la autenticación:", msg);
    });

    this.whatsappClient.on("disconnected", (reason) => {
      console.log("🔌 Cliente desconectado:", reason);
      this.isReady = false;
    });

    this.whatsappClient.initialize();
  }

  startHealthServer() {
    const port = process.env.HEALTH_PORT || 3000;
    this.healthServer = healthApp.listen(port, "0.0.0.0", () => {
      console.log(`🏥 Health check server running on port ${port}`);
    });
  }

  async scrapeHoroscope(sign) {
    console.log(`🔍 Scrapeando horóscopo para ${sign}...`);

    let browser;
    try {
      browser = await puppeteer.launch({
        headless: true,
        args: pupeeteerArgs,
      });

      const page = await browser.newPage();
      await page.setUserAgent(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      );

      const url = `${this.baseUrl}/${sign}`;
      console.log(`📄 Visitando: ${url}`);

      await page.goto(url, {
        waitUntil: "networkidle2",
        timeout: 30000,
      });

      await page.waitForSelector(".horoscopo-hoy .txt p", { timeout: 10000 });

      const dailyHoroscope = await page.evaluate(() => {
        const dailyElement = document.querySelector(".horoscopo-hoy .txt p");
        return dailyElement ? dailyElement.textContent.trim() : null;
      });

      const weeklyHoroscope = await page.evaluate(() => {
        const weeklyElement = document.querySelector(
          ".horoscopo-semanal .txt p"
        );
        return weeklyElement ? weeklyElement.textContent.trim() : null;
      });

      console.log(`✅ Horóscopo extraído para ${sign}`);

      return {
        sign,
        daily: dailyHoroscope,
        weekly: weeklyHoroscope,
      };
    } catch (error) {
      console.error(`❌ Error scrapeando ${sign}:`, error.message);
      return this.getFallbackHoroscope(sign);
    } finally {
      if (browser) {
        await browser.close();
      }
    }
  }

  getFallbackHoroscope(sign) {
    const fallbacks = {
      cancer: {
        daily:
          "🦀 Querida Cáncer: Hoy es un día especial para conectar con tus emociones y cuidar de quienes amas. Tu sensibilidad será tu mayor fortaleza y te guiará hacia decisiones acertadas. ✨",
        weekly:
          "🦀 Esta semana las energías lunares te favorecen especialmente. Es momento de nutrir tus relaciones más cercanas y confiar en tu intuición maternal. 🌙",
      },
      acuario: {
        daily:
          "🏺 Hermoso Acuario: Tu espíritu innovador brillará con fuerza especial hoy. Las amistades y conexiones sociales traerán sorpresas maravillosas. Deja que tu creatividad fluya libremente. ✨",
        weekly:
          "🏺 Semana perfecta para abrazar tu autenticidad completamente. Tu originalidad será reconocida y admirada. Las ideas creativas fluyen y tu visión única inspirará a otros. 💫",
      },
    };

    return {
      sign,
      daily:
        fallbacks[sign]?.daily ||
        "✨ Hoy será un día especial lleno de buenas energías para ti. ✨",
      weekly:
        fallbacks[sign]?.weekly ||
        "✨ Esta semana trae oportunidades maravillosas para tu crecimiento personal. ✨",
    };
  }

  formatHoroscopeMessage(horoscopes) {
    const today = new Date().toLocaleDateString("es-ES", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    });

    const capitalizeFirst = (str) => str.charAt(0).toUpperCase() + str.slice(1);

    let message = `🌟 *Tus Horóscopos del ${capitalizeFirst(today)}* 🌟\n\n`;

    horoscopes.forEach((horoscope) => {
      const signEmoji = horoscope.sign === "cancer" ? "🦀" : "🏺";
      const signName = horoscope.sign === "cancer" ? "Cáncer" : "Acuario";

      message += `${signEmoji} *${signName} - Hoy*\n`;
      message += `${horoscope.daily}\n\n`;
    });

    message += `💕 ¡Que tengas un día maravilloso, miamor! ✨\n\n`;
    message += `_Enviado con amor desde el bot personal de horóscopos de tu novi_ 🤖💖`;

    return message;
  }

  async sendDailyHoroscopes() {
    if (!this.isReady) {
      console.log("⏳ WhatsApp no está listo aún...");
      return;
    }

    console.log("🌟 Iniciando envío de horóscopos diarios...");

    try {
      const horoscopes = [];

      for (const sign of this.signs) {
        const horoscope = await this.scrapeHoroscope(sign);
        horoscopes.push({
          sign: horoscope.sign,
          daily: horoscope.daily,
        });

        await new Promise((resolve) => setTimeout(resolve, 2000));
      }

      const message = this.formatHoroscopeMessage(horoscopes);

      console.log("📱 Enviando mensaje por WhatsApp...");
      await this.whatsappClient.sendMessage(this.recipientNumber, message);

      console.log("✅ ¡Horóscopos diarios enviados exitosamente!");

      if (process.env.LOG_MESSAGES === "true") {
        await this.logMessage(message);
      }
    } catch (error) {
      console.error("❌ Error enviando horóscopos:", error);

      try {
        await this.whatsappClient.sendMessage(
          this.recipientNumber,
          "⚠️ Hubo un problema obteniendo tu horóscopo de hoy. ¡Pero recuerda que eres increíble todos los días! 💕"
        );
      } catch (sendError) {
        console.error("❌ Error enviando mensaje de fallback:", sendError);
      }
    }
  }

  async logMessage(message) {
    try {
      const logDir = "./logs";
      const logFile = path.join(logDir, "horoscope-messages.log");

      try {
        await fs.access(logDir);
      } catch {
        await fs.mkdir(logDir, { recursive: true });
      }

      const timestamp = new Date().toISOString();
      const logEntry = `\n=== ${timestamp} ===\n${message}\n`;

      await fs.appendFile(logFile, logEntry);
    } catch (error) {
      console.error("❌ Error guardando log:", error);
    }
  }

  async sendWeeklyHoroscopes() {
    if (!this.isReady) {
      console.log("⏳ WhatsApp no está listo aún...");
      return;
    }

    console.log("🌟 Iniciando envío de horóscopos semanales...");

    try {
      const horoscopes = [];

      for (const sign of this.signs) {
        const horoscope = await this.scrapeHoroscope(sign);
        horoscopes.push(horoscope);
        await new Promise((resolve) => setTimeout(resolve, 2000));
      }

      const message = this.formatWeeklyHoroscopeMessage(horoscopes);
      console.log("📱 Enviando mensaje semanal por WhatsApp...");
      await this.whatsappClient.sendMessage(this.recipientNumber, message);
      console.log("✅ ¡Horóscopos semanales enviados exitosamente!");

      if (process.env.LOG_MESSAGES === "true") {
        await this.logMessage(message);
      }
    } catch (error) {
      console.error("❌ Error enviando horóscopos semanales:", error);
    }
  }

  formatWeeklyHoroscopeMessage(horoscopes) {
    const today = new Date().toLocaleDateString("es-ES", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    });

    const capitalizeFirst = (str) => str.charAt(0).toUpperCase() + str.slice(1);

    let message = `🌟 *Tus Horóscopos Semanales del ${capitalizeFirst(
      today
    )}* 🌟\n\n`;

    horoscopes.forEach((horoscope) => {
      const signEmoji = horoscope.sign === "cancer" ? "🦀" : "🏺";
      const signName = horoscope.sign === "cancer" ? "Cáncer" : "Acuario";

      message += `${signEmoji} *${signName}*\n`;
      message += `${horoscope.weekly}\n\n`;
    });

    message += `💫 ¡Que tengas una semana maravillosa, mi amor! ✨\n\n`;
    message += `_Enviado con amor desde tu bot personal de horóscopos_ 🤖💖`;

    return message;
  }

  scheduleHoroscopes() {
    const sendTime = process.env.SEND_TIME || "8:00";
    const [hour, minute] = sendTime.split(":").map(Number);

    console.log(`⏰ Programando envío diario a las ${sendTime}`);

    schedule.scheduleJob(`${minute} ${hour} * * *`, () => {
      console.log("⏰ ¡Hora del horóscopo diario!");
      this.sendDailyHoroscopes();
    });

    if (process.env.WEEKLY_ENABLED === "true") {
      schedule.scheduleJob("0 9 * * 0", () => {
        console.log("📅 ¡Hora del horóscopo semanal!");
        this.sendWeeklyHoroscopes();
      });
    }
  }

  async sendTestMessage() {
    if (!this.isReady) {
      console.log("❌ WhatsApp no está conectado");
      return;
    }

    console.log("🧪 Enviando mensajes de prueba...");
    await this.sendDailyHoroscopes();
    await this.sendWeeklyHoroscopes();
  }

  async shutdown() {
    console.log("🛑 Cerrando aplicación...");

    if (this.whatsappClient) {
      await this.whatsappClient.destroy();
    }

    if (this.healthServer) {
      this.healthServer.close();
    }

    schedule.gracefulShutdown();

    console.log("👋 ¡Aplicación cerrada correctamente!");
    process.exit(0);
  }
}

const bot = new HoroscopeWhatsAppBot();

process.on("SIGINT", () => bot.shutdown());
process.on("SIGTERM", () => bot.shutdown());

if (process.argv.includes("--send-now")) {
  setTimeout(() => bot.sendTestMessage(), 10000);
}

console.log("🚀 Horoscope WhatsApp Bot iniciado");
console.log("📱 Esperando conexión de WhatsApp...");

module.exports = HoroscopeWhatsAppBot;
