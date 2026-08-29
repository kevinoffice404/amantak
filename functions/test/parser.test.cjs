const assert = require("node:assert/strict");
const test = require("node:test");

const {
  extractArabicName,
  extractExpiryDate,
  extractNationalId,
  isValidEgyptianNationalId,
  normalizeDigits,
  parseEgyptianIdText,
} = require("../lib/parser.js");

test("normalizes Arabic and Persian digits", () => {
  assert.equal(normalizeDigits("٠١٢٣٤٥٦٧٨٩"), "0123456789");
  assert.equal(normalizeDigits("۰۱۲۳۴۵۶۷۸۹"), "0123456789");
});

test("extracts and validates a spaced national ID", () => {
  assert.equal(
    extractNationalId("الرقم ٣ ٠ ٣ ٠ ١ ٠ ١ ١ ٢ ٣ ٤ ٥ ٦ ٧"),
    "30301011234567",
  );
  assert.equal(isValidEgyptianNationalId("30301011234567"), true);
  assert.equal(isValidEgyptianNationalId("30302311234567"), false);
});

test("extracts year-first and day-first expiry dates", () => {
  assert.equal(extractExpiryDate("سارية حتى ٢٠٣٥/٠٧/٣١"), "2035-07-31");
  assert.equal(extractExpiryDate("31-07-2035"), "2035-07-31");
});

test("extracts the Arabic name while ignoring headers and address", () => {
  const text = [
    "جمهورية مصر العربية",
    "وزارة الداخلية",
    "محمد",
    "عبد الله مصطفى أحمد",
    "القاهرة مدينة نصر",
  ].join("\n");

  assert.equal(extractArabicName(text), "محمد عبد الله مصطفى أحمد");
});

test("parses all fields without returning raw OCR text", () => {
  const result = parseEgyptianIdText(
    [
      "جمهورية مصر العربية",
      "محمد أحمد محمود علي",
      "٣٠٣٠١٠١١٢٣٤٥٦٧",
    ].join("\n"),
    "بطاقة سارية حتى ٢٠٣٥/٠٧/٣١",
  );

  assert.deepEqual(result, {
    nationalId: "30301011234567",
    fullName: "محمد أحمد محمود علي",
    expiryDate: "2035-07-31",
  });
  assert.deepEqual(Object.keys(result).sort(), [
    "expiryDate",
    "fullName",
    "nationalId",
  ]);
});
