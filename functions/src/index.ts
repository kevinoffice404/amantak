import * as vision from "@google-cloud/vision";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {parseEgyptianIdText} from "./parser";

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_BASE64_LENGTH = Math.ceil(MAX_IMAGE_BYTES / 3) * 4 + 8;

// استخدام نقطة الاتحاد الأوروبي يمنع معالجة صور البطاقات خارج نطاق EU.
const visionClient = new vision.ImageAnnotatorClient({
  apiEndpoint: "eu-vision.googleapis.com",
});

function isSupportedImage(buffer: Buffer): boolean {
  const isJpeg = buffer.length >= 3 &&
    buffer[0] === 0xff &&
    buffer[1] === 0xd8 &&
    buffer[2] === 0xff;
  const isPng = buffer.length >= 8 &&
    buffer.subarray(0, 8).equals(
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    );
  const isWebP = buffer.length >= 12 &&
    buffer.subarray(0, 4).toString("ascii") === "RIFF" &&
    buffer.subarray(8, 12).toString("ascii") === "WEBP";

  return isJpeg || isPng || isWebP;
}

function decodeImage(value: unknown, fieldName: string): Buffer {
  if (typeof value !== "string" || value.length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required.`);
  }

  if (value.length > MAX_BASE64_LENGTH || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }

  const buffer = Buffer.from(value, "base64");

  if (buffer.length === 0 || buffer.length > MAX_IMAGE_BYTES) {
    throw new HttpsError("invalid-argument", `${fieldName} has invalid size.`);
  }

  if (!isSupportedImage(buffer)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a JPEG, PNG, or WebP image.`,
    );
  }

  return buffer;
}

async function recognizeText(image: Buffer): Promise<string> {
  const [response] = await visionClient.documentTextDetection({
    image: {content: image},
    imageContext: {languageHints: ["ar", "en"]},
  });

  return response.fullTextAnnotation?.text ??
    response.textAnnotations?.[0]?.description ??
    "";
}

export const analyzeEgyptianId = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 60,
    memory: "512MiB",
    concurrency: 10,
    maxInstances: 3,
    enforceAppCheck: true,
  },
  async (request) => {
    try {
      const frontImage = decodeImage(
        request.data?.frontImageBase64,
        "frontImageBase64",
      );
      const backImage = decodeImage(
        request.data?.backImageBase64,
        "backImageBase64",
      );

      const [frontText, backText] = await Promise.all([
        recognizeText(frontImage),
        recognizeText(backImage),
      ]);

      const fields = parseEgyptianIdText(frontText, backText);

      // لا نسجل الصور أو النص المستخرج أو أي بيانات شخصية.
      logger.info("Egyptian ID OCR completed", {
        frontTextDetected: frontText.trim().length > 0,
        backTextDetected: backText.trim().length > 0,
        fieldsFound: Object.values(fields).filter((value) => value != null).length,
      });

      return fields;
    } catch (error) {
      if (error instanceof HttpsError) throw error;

      logger.error("Egyptian ID OCR failed", {
        errorType: error instanceof Error ? error.name : "unknown",
      });

      throw new HttpsError(
        "internal",
        "The ID card could not be analyzed.",
      );
    }
  },
);
