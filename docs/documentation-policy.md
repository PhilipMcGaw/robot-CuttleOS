# Documentation currency policy

Documentation is an engineering deliverable and must be updated in the same change as the behaviour it describes.

## Mandatory updates

Update the relevant documentation whenever a change affects user-visible behaviour, APIs, configuration, hardware support, safety behaviour, deployment, data formats, tests, workflows, frontend architecture, dependencies, or bundled assets. Update `LICENSES.md` whenever a dependency, generated vendor file, font, icon set, stylesheet, JavaScript library, or other third-party asset is added, removed, replaced, or redistributed. Update `MASTER_CONTEXT.md` whenever architecture, project boundaries, operating conventions, or validation status changes.

This is a hard completion requirement, not an optional follow-up. A behaviour-affecting change is incomplete until the same change set contains the relevant documentation updates and, where applicable, an updated `MASTER_CONTEXT.md`. Code review and hand-off must treat missing documentation as a defect.

## Status language

Documentation must distinguish implemented, automated-test verified, bench-tested, production-validated, and planned or unverified behaviour. Code existence alone must never be described as bench-tested or production-validated.

## Enforcement

Run `python tests/test_documentation.py` from the repository root. The audit checks required maintained documents, current-state status sections, status vocabulary, references to scripts, configuration, examples, frontend artefacts, and the required third-party entries in `LICENSES.md`. The pull-request classifier `tests/documentation_change_policy.py` applies the maintainable rules in `tests/documentation_change_policy.json` to changed files. Changes to application code, frontend assets, dependency manifests, or licence material must include a documentation change. A classified behaviour-affecting change must include a documentation file. Intentional exemptions are listed in that JSON file with their reasons. Both checks run in CI and must pass before a change is accepted.

## Change completion gate

Before reporting a change as complete, the author shall confirm that the
appropriate documentation is updated, obsolete contradictory text is removed,
and the documentation currency and consistency checks have been run or their
absence has been recorded. “To be documented later” is not an acceptable
completion state for a behaviour-affecting change.

## Written Style, Formatting, Units, Symbols, and Normative Language

Written information shall, wherever reasonably practicable, follow the principles of clarity, concision, precision, and simplicity set out in *The Elements of Style* by William Strunk Jr. Technical writing shall prioritise unambiguous communication over stylistic variation. A sentence shall be rewritten where its meaning depends upon inference, assumed context, or interpretation by the reader. Conciseness shall not be achieved by omitting information necessary to establish the intended meaning.

Unnecessary words, repetition, verbosity, passive constructions, and unnecessarily complex sentence structures should be avoided. Statements should be direct, logically ordered, and unambiguous, with precise terminology and appropriate use of the active voice. Formatting shall support readability and comprehension rather than decoration. Consistency shall be maintained throughout a document in headings, terminology, punctuation, capitalisation, numbering, units, symbols, lists, and structure.

The Oxford comma (serial comma) shall be used in lists of three or more items, e.g. “voltage, current, and temperature”.

### Terminology and Abbreviations

One term shall be used consistently for one concept. Synonyms shall not be introduced merely for stylistic variation where doing so could imply a distinction that does not exist. Where different terms have distinct technical meanings, those meanings shall be defined clearly.

Abbreviations and acronyms shall be defined at their first use by giving the full term followed by the abbreviation in parentheses, e.g. “electromagnetic compatibility (EMC)”. The abbreviation may then be used consistently thereafter. Abbreviations that are used only once should generally be avoided.

Terminology defined by a referenced standard, specification, protocol, manufacturer, or other authoritative source shall be retained unless an explanatory alternative is necessary. Where an alternative term is introduced, the relationship between the terms shall be made explicit.

Physical quantities shall have consistent names and, where applicable, consistent symbols throughout a document. A distinction shall be maintained between a quantity, its numerical value, its unit, and its unit symbol.

### SI Units and Numerical Conventions

Technical quantities shall follow the SI-unit rules and style conventions published by the National Institute of Standards and Technology (NIST), including the conventions given in the NIST SI Unit rules and style conventions checklist.

[NIST SI Unit rules and style conventions](https://physics.nist.gov/cuu/Units/checklist.html?utm_source=chatgpt.com)

SI units and recognised SI symbols shall be used wherever applicable. A non-breaking space shall be used between a numerical value and its unit or symbol so that the value and unit remain together when text is reflowed, e.g. `10 V`, `25 °C`, `100 mm`, and `5 µs`.

The degree symbol `°` shall be used where appropriate for angles and temperature. Degrees Celsius shall be written using `°C`, e.g. `25 °C`. The degree symbol shall not be replaced by the word “degrees” where a symbolic representation is appropriate.

The SI prefix *micro* shall be represented by the **micro sign `µ` (U+00B5)**, not by the visually similar Greek small letter mu `μ` (U+03BC). For example, `5 µs` denotes five microseconds. The Greek letter `μ` shall be used only where the Greek letter itself is intended, such as a mathematical or physical variable.

Numerical values shall use commas as thousands separators when writing or displaying large numbers, e.g. `1,000`, `25,000`, and `1,000,000`. A full stop `.` shall be used as the decimal separator, e.g. `1,234.56`. These conventions shall not be applied where they would conflict with a defined programming language, machine-readable format, data interchange format, protocol, or other technical syntax.

Decimal values less than one shall include a leading zero, e.g. `0.5 V`, not `.5 V`.

Trailing zeroes shall be used only where they communicate meaningful precision. For example, `5 V` shall be preferred to `5.0 V` where the additional decimal place does not communicate measurement or specification precision.

The number of significant figures or decimal places shall reflect the accuracy, resolution, tolerance, or precision justified by the underlying measurement, calculation, or requirement. Numerical presentation shall not imply a greater degree of accuracy than the source information supports.

Numerical ranges shall use an en dash `–` where appropriate, e.g. `10–20 V`. Where a range could otherwise be ambiguous, an explicit construction shall be used, such as `−40 °C to +85 °C` or `10 V ≤ V ≤ 20 V`.

Positive and negative values shall use the appropriate mathematical signs where rendered technical text permits. The mathematical minus sign `−` shall be preferred to the ASCII hyphen-minus `-` for negative numerical values, e.g. `−40 °C`.

### Symbols and Typography

Symbols shall be represented using their correct Unicode characters wherever the symbol is intended, rather than visually similar substitutes or improvised ASCII equivalents.

The following symbols shall be used correctly and consistently where applicable:

| Symbol | Meaning |
|---|---|
| `±` | Plus/minus |
| `µ` | SI prefix micro — MICRO SIGN, U+00B5 |
| `μ` | Greek small letter mu — GREEK SMALL LETTER MU, U+03BC |
| `Ω` | Greek capital letter omega |
| `≤` | Less than or equal to |
| `≥` | Greater than or equal to |
| `Δ` | Greek capital letter delta |
| `θ` | Greek small letter theta |
| `§` | Section sign |
| `°` | Degree |
| `τ` | Greek small letter tau |
| `‽` | Interrobang |
| `·` | Interpunct |
| `…` | Ellipsis |
| `⟪` | Mathematical left double angle bracket |
| `⟫` | Mathematical right double angle bracket |

The correct symbol shall be used rather than a textual approximation where the symbol has a defined technical or typographic meaning. For example, `±` shall be preferred to `+/-`, `≤` to `<=`, and `≥` to `>=` in rendered technical documentation. ASCII alternatives may be used where required by programming languages, file formats, protocols, or other machine-readable syntax.

The distinction between the hyphen `-`, en dash `–`, and em dash `—` shall be maintained:

- The hyphen `-` shall be used for compound words and where required by technical syntax.
- The en dash `–` shall be used for numerical ranges and, where appropriate, relationships between paired terms.
- The em dash `—` shall be used for parenthetical interruption where appropriate.

Parentheses shall be used sparingly. Where multiple or nested parentheses make a sentence difficult to parse, the sentence shall be restructured.

### Cross-References

When referring to another section of the same document, the section sign `§` shall be used, e.g. “see §3.2” or “as specified in §4.1.3”, rather than writing “Section 3.2”, unless a governing style, accessibility requirement, or document format requires the latter.

Cross-references shall identify the referenced material precisely. Ambiguous references such as “see above”, “see below”, “as mentioned previously”, or “as described earlier” should be avoided where a specific section, figure, table, equation, or other reference can be provided.

### Requirements and Normative Language

Normative requirements shall use the conventions defined by RFC 2119. The terms `MUST`, `MUST NOT`, `REQUIRED`, `SHALL`, `SHALL NOT`, `SHOULD`, `SHOULD NOT`, `RECOMMENDED`, `MAY`, and `OPTIONAL` shall be used deliberately and only where their normative meaning is intended.

`MUST`, `MUST NOT`, `REQUIRED`, `SHALL`, and `SHALL NOT` shall indicate mandatory requirements. `SHOULD`, `SHOULD NOT`, and `RECOMMENDED` shall indicate recommendations for which there may be a justified exception. `MAY` and `OPTIONAL` shall indicate permitted or optional behaviour.

Illustrative examples shall not inadvertently be presented as normative requirements. Where necessary, examples shall be explicitly identified using terms such as “for example”, “e.g.”, or “illustrative only”.

### Technical Identifiers and Literal Values

Literal technical identifiers shall be distinguished from normal prose using appropriate code formatting. This includes file names, file paths, commands, shell commands, variable names, function names, API endpoints, protocol fields, register names, configuration keys, package names, topic names, and literal configuration values, e.g. `robot_state_publisher`, `/dev/ttyUSB0`, and `baud_rate`.

Technical syntax shall not be altered to comply with prose formatting rules where doing so would change its meaning or make it invalid. Machine-readable formats, programming languages, APIs, protocols, configuration files, and command-line interfaces shall retain their required syntax.

### Dates, Times, and Records

Dates shall be represented in an unambiguous format appropriate to the context. ISO 8601 representations such as `2026-08-19` shall be preferred for technical records and machine-readable data.

Times shall include an explicit time zone or UTC offset where the distinction could affect interpretation. UTC shall be preferred for distributed-system logs, test records, and other technical records unless another time zone is explicitly required.

### Clarity and Ambiguity

Pronouns shall not be used where their antecedent could reasonably be ambiguous. Statements such as “this should then be connected to it” shall be rewritten to identify the relevant objects explicitly.

A statement that could reasonably have two interpretations shall be rewritten so that only the intended interpretation remains. Clarity and precision shall take precedence over brevity.

Information shall be structured logically, with related information grouped together and unnecessary repetition removed. Headings, lists, tables, and other structural elements shall be used where they improve comprehension.

Where the requirements of the subject matter, technical accuracy, accessibility, governing standard, machine-readable syntax, or defined house style conflict with these principles, the applicable higher-priority requirement shall take precedence.
