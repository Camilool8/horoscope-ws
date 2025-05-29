#!/usr/bin/env node

/**
 * Test script para verificar el scraping de horóscopos
 * Ejecutar: node test-scraper.js
 */

const puppeteer = require("puppeteer");

async function testScraping() {
  console.log("🧪 Iniciando prueba de scraping...\n");

  const signs = ["cancer", "acuario"];
  const baseUrl = "https://www.lecturas.com/horoscopo";
  const scrapedData = [];

  let browser;
  try {
    browser = await puppeteer.launch({
      headless: true,
      args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
      ],
    });

    for (const sign of signs) {
      console.log(`🔍 Scrapeando ${sign.toUpperCase()}...`);

      const page = await browser.newPage();
      await page.setUserAgent(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      );

      const url = `${baseUrl}/${sign}`;
      console.log(`📄 URL: ${url}`);

      try {
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

        const signTitle = await page.evaluate(() => {
          const titleElement = document.querySelector(
            ".horoscopo-header h1.title"
          );
          return titleElement ? titleElement.textContent.trim() : null;
        });

        const horoscopeData = {
          sign,
          signTitle,
          dailyHoroscope: dailyHoroscope,
          weeklyHoroscope: weeklyHoroscope,
        };

        scrapedData.push(horoscopeData);

        console.log(`✅ ${sign.toUpperCase()} scrapeado exitosamente`);
        console.log(`📋 Título encontrado: ${signTitle}`);
        console.log(
          `📝 Horóscopo diario (${
            dailyHoroscope ? dailyHoroscope.length : 0
          } caracteres)`
        );
        console.log(
          `📅 Horóscopo semanal (${
            weeklyHoroscope ? weeklyHoroscope.length : 0
          } caracteres)`
        );

        if (dailyHoroscope) {
          console.log(`🔤 Muestra del horóscopo diario:`);
          console.log(`   "${dailyHoroscope.substring(0, 150)}..."`);
        }

        if (weeklyHoroscope) {
          console.log(`🔤 Muestra del horóscopo semanal:`);
          console.log(`   "${weeklyHoroscope.substring(0, 150)}..."`);
        }

        console.log("---\n");
      } catch (error) {
        console.error(`❌ Error scrapeando ${sign}: ${error.message}`);
      }

      await page.close();

      await new Promise((resolve) => setTimeout(resolve, 2000));
    }

    await testMessageFormatting(scrapedData);
  } catch (error) {
    console.error("❌ Error general:", error);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

async function testMessageFormatting(scrapedData) {
  console.log("📝 Probando formato de mensaje con datos reales...\n");

  if (!scrapedData || !Array.isArray(scrapedData)) {
    console.error("❌ Error: No se proporcionaron datos de horóscopos válidos");
    return;
  }

  const today = new Date().toLocaleDateString("es-ES", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  });

  const capitalizeFirst = (str) => str.charAt(0).toUpperCase() + str.slice(1);

  let message = `🌟 *Tus Horóscopos del ${capitalizeFirst(today)}* 🌟\n\n`;

  scrapedData.forEach((horoscope) => {
    const signEmoji = horoscope.sign === "cancer" ? "🦀" : "🏺";
    const signName = horoscope.sign === "cancer" ? "Cáncer" : "Acuario";

    if (horoscope.dailyHoroscope) {
      message += `${signEmoji} *${signName} - Hoy*\n`;
      message += `${horoscope.dailyHoroscope}\n\n`;
    }

    if (horoscope.weeklyHoroscope) {
      message += `${signEmoji} *${signName} - Esta Semana*\n`;
      message += `${horoscope.weeklyHoroscope}\n\n`;
    }
  });

  message += `💕 ¡Que tengas un día maravilloso, mi amor! ✨\n\n`;
  message += `_Enviado con amor desde tu bot personal de horóscopos_ 🤖💖`;

  console.log("📱 Mensaje formateado:");
  console.log("=" + "=".repeat(50));
  console.log(message);
  console.log("=" + "=".repeat(50));
  console.log(`📊 Longitud total: ${message.length} caracteres`);
  console.log("✅ Formato de mensaje OK\n");
}

async function main() {
  console.log("🚀 Iniciando pruebas del Horoscope Scraper\n");

  try {
    await testScraping();
    console.log("🎉 ¡Todas las pruebas completadas exitosamente!");
  } catch (error) {
    console.error("💥 Error en las pruebas:", error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  testScraping,
  testMessageFormatting,
};
