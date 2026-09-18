//! Natural-language task extraction -- THE SCOPED-OUT PART.
//!
//! `../../docs/the-generative-day-planner-guide.md` (Step 1) says the user should be
//! asked to talk about their day in raw, unfiltered prose, not hand over a task list.
//! The real system this project's README describes turns that prose into structured
//! tasks with a genuine LLM agent: `/home/user/lmmx/sumac`'s `sumac ask` command is the
//! actual, working precedent -- see `sumac/README.md`'s "Optional: natural-language
//! input" section, and `sumac/src/sumac/llm.py` / `sumac/src/sumac/prompt_ui.py` for the
//! real agent code (a `mistralrs`-backed Rust-SDK-via-Python `Runner`, a client-side
//! tool-calling loop, and a review-before-write UX: nothing is written until a human
//! accepts the proposed plan).
//!
//! Running a real `mistralrs` model in THIS project is out of scope for the reason
//! `mistralrs-cuda-notes/` gives for its own out-of-scope call: no GPU in this sandbox,
//! and even CPU inference needs a real GGUF model file downloaded first -- not worth the
//! setup cost for what is, here, a demonstration of the Bend+Pumpkin pipeline downstream
//! of extraction, not of extraction itself. Instead, `extract_tasks` below is an
//! honestly-labeled heuristic: keyword/phrase matching against a small fixed vocabulary,
//! with fixed per-category duration defaults. It is a stand-in, not a simulation of one --
//! it will misclassify real free text constantly, and that is fine, because nothing
//! downstream of it (the Bend proof, the Pumpkin timing) depends on it being smart, only
//! on it producing a `Task` list shaped like the real thing would.
//!
//! Compare `cuda-index-proofs/`'s first pass, which left surjectivity as prose rather
//! than faking a proof of it -- the same instinct applies here: label the stand-in
//! plainly rather than dress it up as more than it is.

/// The guide's own four task categories (Step 4). The Bend proof in
/// `../../bend/alt_no_repeat/` works over exactly two buckets (`Body`/`Mind`); see
/// `alt_sequence.rs` and the README for the Physical->Body, {Cognitive,Creative}->Mind
/// mapping and why Administrative sits outside the alternation guarantee entirely.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Category {
    /// Movement, hygiene, environment-clearing. "Goes early" (Step 4).
    Physical,
    /// Thinking/reading/planning work: lower-variance mental work.
    Cognitive,
    /// Writing/coding/designing: "should come first" among mental work, high-variance,
    /// "needs the best conditions" (Step 4).
    Creative,
    /// Applications, emails, forms, invoices: "lower-variance; it goes fine at any
    /// energy level" (Step 4) -- explicitly NOT part of the alternation rule.
    Administrative,
}

impl Category {
    pub fn label(self) -> &'static str {
        match self {
            Category::Physical => "Physical",
            Category::Cognitive => "Cognitive",
            Category::Creative => "Creative",
            Category::Administrative => "Administrative",
        }
    }

    /// A default duration estimate in minutes, since raw free text usually doesn't
    /// state one. Deliberately crude -- a real NLU agent (or a follow-up question) would
    /// ask the person, or extract an explicit duration if they gave one (see
    /// `extract_duration_minutes` below for the one bit of that this stub does do).
    fn default_duration_minutes(self) -> u32 {
        match self {
            Category::Physical => 30,
            Category::Cognitive => 45,
            Category::Creative => 90,
            Category::Administrative => 45,
        }
    }
}

/// A structured task, per the shape the scheduler needs (project brief section 3):
/// name, modality category, an estimated duration, and a `generative` flag per Step 3
/// of the guide ("if a task genuinely has no generative potential... note that too").
#[derive(Debug, Clone)]
pub struct Task {
    pub name: String,
    pub category: Category,
    pub duration_min: u32,
    pub generative: bool,
}

/// Keyword -> category table. Order matters: earlier entries win on the first match
/// found in a phrase, so more specific words should precede more generic ones. This is
/// literally the whole "model" -- see the module doc comment for why that's an honest
/// choice here, not a shortcut being passed off as more.
const KEYWORDS: &[(&str, Category)] = &[
    // Physical: movement, hygiene, environment-clearing.
    ("shower", Category::Physical),
    ("gym", Category::Physical),
    ("walk", Category::Physical),
    ("run", Category::Physical),
    ("clean", Category::Physical),
    ("tidy", Category::Physical),
    ("tile", Category::Physical),
    ("bathroom", Category::Physical),
    ("repair", Category::Physical),
    ("fix", Category::Physical),
    ("cook", Category::Physical),
    ("shop", Category::Physical),
    ("laundry", Category::Physical),
    ("dishwasher", Category::Physical),
    // Creative: writing/coding/designing -- generative work per Step 4.
    ("code", Category::Creative),
    ("coding", Category::Creative),
    ("program", Category::Creative),
    ("write", Category::Creative),
    ("design", Category::Creative),
    ("draft", Category::Creative),
    ("compose", Category::Creative),
    ("build", Category::Creative),
    // Cognitive: thinking/reading/planning.
    ("think", Category::Cognitive),
    ("read", Category::Cognitive),
    ("plan", Category::Cognitive),
    ("review", Category::Cognitive),
    ("study", Category::Cognitive),
    ("research", Category::Cognitive),
    ("learn", Category::Cognitive),
    // Administrative: applications, chores-on-paper, forms.
    ("apply", Category::Administrative),
    ("application", Category::Administrative),
    ("email", Category::Administrative),
    ("invoice", Category::Administrative),
    ("form", Category::Administrative),
    ("bill", Category::Administrative),
    ("schedule", Category::Administrative),
    ("appointment", Category::Administrative),
    ("job", Category::Administrative),
];

/// Phrase-level cues that a task is a pure obligation with no downstream effect --
/// Step 3's "note that too" case. Deliberately small and literal, matching the rest of
/// this stub's honesty about what it is.
const NO_GENERATIVE_CUES: &[&str] = &["just", "chore", "mandatory", "no point", "pointless"];

/// Splits raw free text into candidate task phrases. A real agent (sumac's `ask`, or an
/// LLM parsing this guide's Step 1 prose) would do this with actual language
/// understanding; this stub just splits on commas, semicolons, " and ", and newlines,
/// which is enough to pull apart the guide's own Step 1 worked example ("I need to apply
/// for jobs, fix my bathroom, and work on a coding project").
fn split_phrases(raw: &str) -> Vec<String> {
    raw.split([',', ';', '\n'])
        .flat_map(|chunk| chunk.split(" and "))
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect()
}

/// Pulls an explicit duration out of a phrase if one is stated in the common forms
/// ("30 minutes", "45 min", "2 hours", "1 hr"). Returns `None` (fall back to the
/// category default) otherwise. This is the one place the stub does something a little
/// more than pure keyword-to-category matching, because durations are load-bearing for
/// the Pumpkin timing layer and a category default alone would flatten every sample
/// input to the same numbers.
fn extract_duration_minutes(phrase: &str) -> Option<u32> {
    let lower = phrase.to_lowercase();
    let words: Vec<&str> = lower.split_whitespace().collect();
    for (i, w) in words.iter().enumerate() {
        if let Ok(n) = w.parse::<u32>() {
            if let Some(next) = words.get(i + 1) {
                if next.starts_with("hour") || next.starts_with("hr") {
                    return Some(n * 60);
                }
                if next.starts_with("min") {
                    return Some(n);
                }
            }
        }
    }
    None
}

/// Cleans a matched phrase up into a short display name: strips leading obligation
/// language ("i need to", "i should", "i have to") the guide's Step 2 calls "debt
/// language", since a generative reframe shouldn't keep repeating it in the schedule.
fn clean_name(phrase: &str) -> String {
    let lower = phrase.to_lowercase();
    let prefixes = [
        "i need to ",
        "i should ",
        "i have to ",
        "i've got to ",
        "i want to ",
        "i'd like to ",
        "gotta ",
    ];
    for p in prefixes {
        if let Some(rest) = lower.strip_prefix(p) {
            let byte_offset = phrase.len() - rest.len();
            return phrase[byte_offset..].trim().to_string();
        }
    }
    phrase.trim().to_string()
}

/// The stub extractor: free text -> `Vec<Task>`. See the module doc comment for what
/// this stands in for and why. Phrases matching no keyword are skipped rather than
/// guessed at -- a real agent would ask a follow-up question; this one just doesn't
/// invent structure it has no basis for.
pub fn extract_tasks(raw: &str) -> Vec<Task> {
    let mut tasks = Vec::new();
    for phrase in split_phrases(raw) {
        let lower = phrase.to_lowercase();
        let category = KEYWORDS
            .iter()
            .find(|(kw, _)| lower.contains(kw))
            .map(|(_, cat)| *cat);

        let Some(category) = category else {
            continue;
        };

        let duration_min = extract_duration_minutes(&phrase).unwrap_or_else(|| category.default_duration_minutes());
        let generative = !NO_GENERATIVE_CUES.iter().any(|cue| lower.contains(cue));

        tasks.push(Task {
            name: clean_name(&phrase),
            category,
            duration_min,
            generative,
        });
    }
    tasks
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_the_guides_own_step_1_example() {
        // "I need to apply for jobs, fix my bathroom, and work on a coding project."
        let tasks = extract_tasks(
            "I need to apply for jobs, fix my bathroom, and work on a coding project",
        );
        assert_eq!(tasks.len(), 3);
        assert_eq!(tasks[0].category, Category::Administrative);
        assert_eq!(tasks[1].category, Category::Physical);
        assert_eq!(tasks[2].category, Category::Creative);
    }

    #[test]
    fn strips_debt_language_from_the_name() {
        let tasks = extract_tasks("I need to apply for jobs");
        assert_eq!(tasks[0].name, "apply for jobs");
    }

    #[test]
    fn picks_up_an_explicit_duration() {
        let tasks = extract_tasks("go for a 20 minute walk");
        assert_eq!(tasks[0].duration_min, 20);
    }

    #[test]
    fn falls_back_to_category_default_duration() {
        let tasks = extract_tasks("shower");
        assert_eq!(tasks[0].duration_min, Category::Physical.default_duration_minutes());
    }

    #[test]
    fn flags_no_generative_potential_when_cued() {
        let tasks = extract_tasks("just file the invoice");
        assert!(!tasks[0].generative);
    }

    #[test]
    fn skips_phrases_matching_no_keyword() {
        let tasks = extract_tasks("stare at the ceiling for a while");
        assert!(tasks.is_empty());
    }

    #[test]
    fn splits_on_and_as_well_as_commas() {
        let tasks = extract_tasks("shower and clean the kitchen and read a chapter");
        assert_eq!(tasks.len(), 3);
    }
}
