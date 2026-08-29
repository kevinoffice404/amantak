const ARABIC_DIGITS = "٠١٢٣٤٥٦٧٨٩";
const PERSIAN_DIGITS = "۰۱۲۳۴۵۶۷۸۹";

const EXCLUDED_PHRASES = [
  "جمهورية مصر العربية",
  "وزارة الداخلية",
  "قطاع الأحوال المدنية",
  "بطاقة تحقيق الشخصية",
  "الرقم القومي",
  "تاريخ الميلاد",
  "تاريخ الانتهاء",
  "سارية حتى",
  "محل الإقامة",
  "محل الاقامة",
];

const EXCLUDED_WORDS = new Set([
  "جمهورية",
  "العربية",
  "وزارة",
  "الداخلية",
  "قطاع",
  "الأحوال",
  "الاحوال",
  "المدنية",
  "بطاقة",
  "تحقيق",
  "الشخصية",
  "الرقم",
  "القومي",
  "تاريخ",
  "الميلاد",
  "الانتهاء",
  "سارية",
  "حتى",
  "العنوان",
  "الإقامة",
  "الاقامة",
  "ذكر",
  "أنثى",
  "انثى",
  "مسلم",
  "مسيحي",
  "مركز",
  "قسم",
  "شارع",
  "شياخة",
  "قرية",
  "مدينة",
  "محافظة",
  "القاهرة",
  "الجيزة",
  "القليوبية",
  "الدقهلية",
  "الشرقية",
  "الغربية",
  "المنوفية",
  "البحيرة",
  "الإسكندرية",
  "الاسكندرية",
]);

export interface EgyptianIdFields {
  nationalId: string | null;
  fullName: string | null;
  expiryDate: string | null;
}

export function normalizeDigits(value: string): string {
  let result = value.normalize("NFKC");

  for (let index = 0; index < 10; index++) {
    result = result
      .replaceAll(ARABIC_DIGITS[index], String(index))
      .replaceAll(PERSIAN_DIGITS[index], String(index));
  }

  return result;
}

export function normalizeOcrText(value: string): string {
  return normalizeDigits(value)
    .replace(/[\u200E\u200F\u202A-\u202E\u2066-\u2069]/g, "")
    .replace(/ـ/g, "")
    .replace(/\r\n?/g, "\n")
    .replace(/[ \t]+/g, " ")
    .trim();
}

function isRealDate(year: number, month: number, day: number): boolean {
  const date = new Date(Date.UTC(year, month - 1, day));

  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

export function isValidEgyptianNationalId(value: string): boolean {
  if (!/^[23]\d{13}$/.test(value)) return false;

  const century = value[0] === "2" ? 1900 : 2000;
  const year = century + Number(value.slice(1, 3));
  const month = Number(value.slice(3, 5));
  const day = Number(value.slice(5, 7));

  if (!isRealDate(year, month, day)) return false;

  const birthDate = new Date(Date.UTC(year, month - 1, day));
  const tomorrow = new Date();
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);

  return birthDate < tomorrow;
}

export function extractNationalId(text: string): string | null {
  const normalized = normalizeOcrText(text);
  const lines = normalized.split("\n");

  // الرقم القومي يظهر عادةً في سطر واحد، وقد يفصل OCR بين أرقامه بمسافات.
  for (const line of lines) {
    const digits = line.replace(/\D/g, "");

    for (let start = 0; start <= digits.length - 14; start++) {
      const candidate = digits.slice(start, start + 14);
      if (isValidEgyptianNationalId(candidate)) return candidate;
    }
  }

  // احتياطياً نبحث عن رقم متصل في النص كله.
  for (const match of normalized.matchAll(/(?<!\d)([23]\d{13})(?!\d)/g)) {
    const candidate = match[1];
    if (isValidEgyptianNationalId(candidate)) return candidate;
  }

  return null;
}

interface DateParts {
  year: number;
  month: number;
  day: number;
}

function addDateIfValid(target: DateParts[], value: DateParts): void {
  if (value.year < 2000 || value.year > 2100) return;
  if (!isRealDate(value.year, value.month, value.day)) return;

  const key = `${value.year}-${value.month}-${value.day}`;
  const exists = target.some(
    (item) => `${item.year}-${item.month}-${item.day}` === key,
  );

  if (!exists) target.push(value);
}

function dateValue(value: DateParts): number {
  return Date.UTC(value.year, value.month - 1, value.day);
}

function formatDate(value: DateParts): string {
  return `${String(value.year).padStart(4, "0")}-` +
    `${String(value.month).padStart(2, "0")}-` +
    `${String(value.day).padStart(2, "0")}`;
}

export function extractExpiryDate(text: string): string | null {
  const normalized = normalizeOcrText(text);
  const dates: DateParts[] = [];
  const separator = String.raw`[\s/\.\-–—]+`;
  const yearFirst = new RegExp(
    String.raw`(?:^|\D)(20\d{2})${separator}(\d{1,2})${separator}(\d{1,2})(?!\d)`,
    "gm",
  );
  const dayFirst = new RegExp(
    String.raw`(?:^|\D)(\d{1,2})${separator}(\d{1,2})${separator}(20\d{2})(?!\d)`,
    "gm",
  );

  for (const match of normalized.matchAll(yearFirst)) {
    addDateIfValid(dates, {
      year: Number(match[1]),
      month: Number(match[2]),
      day: Number(match[3]),
    });
  }

  for (const match of normalized.matchAll(dayFirst)) {
    addDateIfValid(dates, {
      year: Number(match[3]),
      month: Number(match[2]),
      day: Number(match[1]),
    });
  }

  if (dates.length === 0) return null;

  dates.sort((left, right) => dateValue(left) - dateValue(right));

  const today = new Date();
  const todayUtc = Date.UTC(
    today.getUTCFullYear(),
    today.getUTCMonth(),
    today.getUTCDate(),
  );
  const futureDates = dates.filter((date) => dateValue(date) >= todayUtc);
  const selected = futureDates.length > 0 ? futureDates.at(-1)! : dates.at(-1)!;

  return formatDate(selected);
}

function comparisonText(value: string): string {
  return value
    .replace(/[أإآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[ًٌٍَُِّْ]/g, "")
    .toLowerCase();
}

function cleanPotentialNameLine(value: string): string | null {
  const withoutLabel = value.replace(/^\s*(?:الاسم|اسم)\s*[:\-–—]?\s*/u, "");

  if (/\d/.test(withoutLabel)) return null;

  const words = withoutLabel.match(/[\u0621-\u064A\u066E-\u06D3]+/gu) ?? [];
  if (words.length === 0 || words.length > 6) return null;

  const line = words.join(" ");
  const comparable = comparisonText(line);

  if (EXCLUDED_PHRASES.some((phrase) => comparable.includes(comparisonText(phrase)))) {
    return null;
  }

  if (words.some((word) => EXCLUDED_WORDS.has(word))) return null;

  return line;
}

function nameScore(wordsCount: number, startLine: number, linesCount: number): number {
  const wordsScore = wordsCount === 4 ? 14 :
    wordsCount === 5 ? 13 :
    wordsCount === 3 ? 9 : 4;
  const positionScore = Math.max(0, 8 - startLine * 0.35);
  const groupingScore = linesCount === 2 ? 3 : linesCount === 1 ? 2 : 1;

  return wordsScore + positionScore + groupingScore;
}

export function extractArabicName(text: string): string | null {
  const normalized = normalizeOcrText(text);
  const rawLines = normalized.split("\n");
  const lines = rawLines.map(cleanPotentialNameLine);

  let bestName: string | null = null;
  let bestScore = Number.NEGATIVE_INFINITY;

  for (let start = 0; start < lines.length; start++) {
    if (lines[start] == null) continue;

    const collectedWords: string[] = [];

    for (let end = start; end < Math.min(lines.length, start + 3); end++) {
      const line = lines[end];
      if (line == null) break;

      collectedWords.push(...line.split(" "));
      if (collectedWords.length > 6) break;
      if (collectedWords.length < 3) continue;

      const score = nameScore(collectedWords.length, start, end - start + 1);

      if (score > bestScore) {
        bestScore = score;
        bestName = collectedWords.join(" ");
      }
    }
  }

  return bestName;
}

export function parseEgyptianIdText(
  frontText: string,
  backText: string,
): EgyptianIdFields {
  return {
    nationalId: extractNationalId(frontText) ?? extractNationalId(backText),
    fullName: extractArabicName(frontText) ?? extractArabicName(backText),
    expiryDate: extractExpiryDate(backText) ?? extractExpiryDate(frontText),
  };
}
