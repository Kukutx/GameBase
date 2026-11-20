// What Godot's `%` operator reads in a text: its placeholders ("%s", "%05.1f",
// "%+d", "%%" for a percent sign), and the GDScript that fills a written-out
// text with a count of arguments other than the one its placeholders take.
// check_localization keeps a translation's placeholders those of its text;
// check_code keeps every text the scripts fill given what it takes.

const PLACEHOLDER_RE = /%(?:%|[-+0]*(\*|\d+)?(?:\.(\*|\d+))?([scdoxXfv]))/g;
// The calls that hand back the text written in them (translated or not), so
// `tr("Day %d") % day` fills "Day %d".
const PASS_THROUGH = new Set(["tr", "translate", "String"]);
// The calls that fill their first argument, a text, with their second, an
// array: GameEvents.toastf("Sold %s for %dg", [name, price]),
// Interactable.set_prompt("Talk to %s", [name]).
const FILLERS = new Set(["toastf", "set_prompt"]);

// The kinds of `text`'s placeholders in order ("%s %d"), "%%" left out.
function placeholders(text) {
  return [...text.matchAll(PLACEHOLDER_RE)].filter((match) => match[3]).map((match) => `%${match[3]}`).join(" ");
}

// How many values `%` takes to fill `text`: one a placeholder, and one more
// for each "*" that reads its width or precision from the arguments.
function argumentCount(text) {
  let count = 0;
  for (const match of text.matchAll(PLACEHOLDER_RE)) {
    if (!match[3]) continue;
    count += 1 + (match[1] === "*" ? 1 : 0) + (match[2] === "*" ? 1 : 0);
  }
  return count;
}

// The tokens of a GDScript source: its texts ({kind: "text", value, line}),
// with StringName and NodePath literals apart ("name"), words, numbers and
// single characters of punctuation; comments are left out.
function tokensOf(source) {
  const tokens = [];
  let line = 1;
  let index = 0;
  while (index < source.length) {
    const char = source[index];
    if (char === "\n") line += 1;
    if (/\s|\\/.test(char)) {
      index += 1;
    } else if (char === "#") {
      while (index < source.length && source[index] !== "\n") index += 1;
    } else if (char === '"' || char === "'" || ((char === "&" || char === "^") && /["']/.test(source[index + 1] || ""))) {
      const kind = char === "&" || char === "^" ? "name" : "text";
      const start = kind === "name" ? index + 1 : index;
      const quote = source.startsWith(source[start].repeat(3), start) ? source[start].repeat(3) : source[start];
      let end = start + quote.length;
      while (end < source.length && !source.startsWith(quote, end)) end += source[end] === "\\" ? 2 : 1;
      const value = source.slice(start + quote.length, end);
      tokens.push({ kind, value, line });
      line += (value.match(/\n/g) || []).length;
      index = end + quote.length;
    } else if (/\w/.test(char)) {
      let end = index;
      while (end < source.length && /\w/.test(source[end])) end += 1;
      tokens.push({ kind: "word", value: source.slice(index, end), line });
      index = end;
    } else {
      tokens.push({ kind: "mark", value: char, line });
      index += 1;
    }
  }
  return tokens;
}

function isMark(token, value) {
  return token !== undefined && token.kind === "mark" && token.value === value;
}

// How many values the array literal that opens at `tokens[open]` holds, a
// trailing comma aside.
function arrayLength(tokens, open) {
  let depth = 0;
  let count = 0;
  let pending = false;
  for (let index = open; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token.kind === "mark" && "([{".includes(token.value)) {
      depth += 1;
      if (depth === 1) continue;
    } else if (token.kind === "mark" && ")]}".includes(token.value)) {
      depth -= 1;
      if (depth === 0) return count + (pending ? 1 : 0);
    } else if (depth === 1 && isMark(token, ",")) {
      count += 1;
      pending = false;
      continue;
    }
    pending = true;
  }
  return -1;
}

// The lines of `source` that fill a written-out text with another count of
// values than it takes, each as {line, text, takes, given}: `"..." % [a, b]`
// and `tr("...") % [a, b]` with an array of another length, `"..." % value`
// on a text with no placeholder (one with more may be given an array held in
// `value`), and `toastf("...", [a, b])` or `set_prompt("...", [a, b])`.
function formatProblems(source) {
  const tokens = tokensOf(source);
  const problems = [];
  tokens.forEach((token, index) => {
    if (token.kind !== "text") return;
    const takes = argumentCount(token.value);
    let after = index + 1;
    for (let wrapped = wrappersOf(tokens, index); wrapped > 0 && isMark(tokens[after], ")"); wrapped -= 1) after += 1;
    if (isMark(tokens[after], "%") && !isMark(tokens[after + 1], "=") && tokens[after + 1] !== undefined) {
      const given = isMark(tokens[after + 1], "[") ? arrayLength(tokens, after + 1) : null;
      if (given !== null ? given !== takes : takes === 0) problems.push({ line: token.line, text: token.value, takes, given: given ?? 1 });
    }
    const call = tokens[index - 2];
    if (isMark(tokens[index - 1], "(") && call && call.kind === "word" && FILLERS.has(call.value) && isMark(tokens[index + 1], ",") && isMark(tokens[index + 2], "[")) {
      const given = arrayLength(tokens, index + 2);
      if (given !== takes) problems.push({ line: token.line, text: token.value, takes, given });
    }
  });
  return problems;
}

// How many calls that hand back the text at `tokens[index]` open right around
// it: two in `String(TranslationServer.translate("..."))`.
function wrappersOf(tokens, index) {
  let count = 0;
  let open = index - 1;
  while (isMark(tokens[open], "(") && tokens[open - 1] !== undefined && tokens[open - 1].kind === "word" && PASS_THROUGH.has(tokens[open - 1].value)) {
    count += 1;
    open -= 2;
    while (isMark(tokens[open], ".") && tokens[open - 1] !== undefined && tokens[open - 1].kind === "word") open -= 2;
  }
  return count;
}

module.exports = { PLACEHOLDER_RE, argumentCount, formatProblems, placeholders, tokensOf };
