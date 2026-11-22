/**
 * A small server-side filter for words The Crew doesn't allow (App Review
 * Guideline 1.2 asks for one next to report and block). It checks Shout-outs
 * and stage names, the free text other people see.
 *
 * Matching is on whole words after normalizing case, accents, look-alike
 * digits and symbols (f@g, sh1t), stretched letters (fuuuck) and spaced-out
 * letters (f u c k), so ordinary words that merely contain a bad one
 * ("Scunthorpe", "class", "Niger") still pass.
 */

// Checked as written and with stretched letters collapsed ("fuuuck"), so
// list each word in its usual spelling, plus the collapsed one if it differs.
const WORDS = new Set([
  // Slurs
  "nigger", "niggers", "nigga", "niggas", "niggaz", "chink", "chinks", "gook", "gooks",
  "spic", "spics", "kike", "kikes", "wetback", "wetbacks", "raghead", "ragheads",
  "towelhead", "towelheads", "beaner", "beaners", "paki", "pakis",
  "fag", "fags", "faggot", "faggots", "fagot", "fagots", "dyke", "dykes", "tranny",
  "trannies", "trany", "retard", "retards", "retarded",
  // Sexual
  "porn", "porno", "cumshot", "jizz", "dildo", "blowjob", "handjob", "rape", "raped",
  "rapist", "pedo", "pedophile", "whore", "whores", "slut", "sluts", "pussy", "pusy",
  "cunt", "cunts", "twat", "twats",
  // Abuse
  "kys", "bitch", "bitches", "shit", "shits", "shitty", "shitting", "shithead",
  "shitheads", "bullshit", "dipshit", "horseshit",
]);

// Any word that starts with one of these (fucking, motherfucker).
const STEMS = ["fuck", "fuk", "motherf", "nigg", "faggot", "cunt"];

const LOOKALIKES: Record<string, string> = {
  "0": "o", "1": "i", "!": "i", "|": "i", "3": "e", "4": "a", "@": "a",
  "5": "s", "$": "s", "7": "t", "+": "t", "8": "b", "9": "g",
};

function normalize(text: string): string {
  return text
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[01!|34@5$7+89]/g, (c) => LOOKALIKES[c] ?? c);
}

function listed(word: string): boolean {
  return WORDS.has(word) || STEMS.some((s) => word.startsWith(s));
}

function blocked(word: string): boolean {
  if (word.length < 2) return false;
  return listed(word) || listed(word.replace(/(.)\1+/g, "$1"));
}

/** True when [text] has a word The Crew doesn't allow. */
export function hasBlockedWords(text: string): boolean {
  const words = normalize(text).split(/[^a-z]+/).filter(Boolean);
  if (words.some(blocked)) return true;
  // "f u c k" / "f.u.c.k": join runs of single letters and check again.
  let run = "";
  for (const w of [...words, ""]) {
    if (w.length === 1) {
      run += w;
      continue;
    }
    if (run.length > 1 && blocked(run)) return true;
    run = "";
  }
  return false;
}
