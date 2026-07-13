# jq template for the create-test-plan ADF document.
#
# Inputs (supplied via --arg / --argjson at call time):
#   $context        string       Short paragraph under "Context" — just "we want X
#                                because Y" plus a one-line note on why automated
#                                tests can't prove the invariant. NO risks here; the
#                                Risks section owns those.
#   $risks          [string]     One bullet per risk under "Risks". Each test case
#                                in $cases must map to a risk listed here.
#   $prereqs        [string]     OPTIONAL bullets under "Pre-requisites"; pass `[]` to
#                                omit the section. Skip unless there's something the
#                                verifier truly needs to set up before the cases run.
#   $cases          [object]     One taskItem per test case under "Test cases".
#                                Each element: {title: <bolded prefix>, setup: <action>,
#                                expected: <outcome>}. Template renders bold title +
#                                setup + bold "Expected:" + expected, inline.
#   $signoff        [string]     OPTIONAL taskItems under "Sign-off"; pass `[]` to omit
#                                the section. Skip when the case-pass criteria alone
#                                gate the rollout — no separate sign-off bullets needed.
#   $rollout        [string]     OPTIONAL bullet list under "Rollout cadence"; pass an
#                                empty array `[]` to omit the section entirely. Skip the
#                                section for single-deploy changes.
#
# Critical invariant encoded ONCE here: every `taskItem.content` array holds
# inline runs directly — NO `paragraph` wrapper. Wrapping `taskItem` in
# `paragraph` is the most common ADF mistake (acli rejects with
# `INVALID_INPUT`), so the template never lets a caller make it.
#
# Caller (create-test-plan skill):
#   jq -n \
#     --arg     context "$ctx" \
#     --argjson prereqs "$prereqs_arr" \
#     --argjson cases   "$cases_arr" \
#     --argjson signoff "$signoff_arr" \
#     --argjson rollout "$rollout_arr_or_empty" \
#     -f "${CLAUDE_PLUGIN_ROOT}/references/test-plan-adf-template.jq" \
#     > "$adf_tmp"
#
# Output: a complete ADF document object on stdout.

def heading($text; $level):
  { type: "heading", attrs: {level: $level},
    content: [{ type: "text", text: $text }] };

def para($text):
  { type: "paragraph",
    content: [{ type: "text", text: $text }] };

def bullets($items):
  { type: "bulletList",
    content: ($items | map({
      type: "listItem",
      content: [para(.)]
    })) };

# Risks bullet list — each item auto-prefixed with a bold "Rn — " marker so
# test cases can reference R1, R2, … unambiguously.
def risk_bullet($idx; $text):
  { type: "listItem",
    content: [{
      type: "paragraph",
      content: [
        { type: "text", text: ("R" + ($idx | tostring) + " — "),
          marks: [{ type: "strong" }] },
        { type: "text", text: $text }
      ]
    }] };

def risks_list($items):
  { type: "bulletList",
    content: [$items | to_entries[] | risk_bullet(.key + 1; .value)] };

# A taskItem whose content is the inline-runs array DIRECTLY — never wrapped in
# paragraph. $idx is used to mint stable localIds (c1, c2, c3 …) so re-renders
# don't perturb the IDs on every run. Bold title + plain setup + bold
# "Expected:" + plain expected outcome.
def task_case($idx; $case):
  { type: "taskItem",
    attrs: { localId: ("c" + ($idx | tostring)), state: "TODO" },
    content: [
      { type: "text", text: ($case.title + " "), marks: [{ type: "strong" }] },
      { type: "text", text: (($case.setup // "") + " ") },
      { type: "text", text: "Expected: ", marks: [{ type: "strong" }] },
      { type: "text", text: ($case.expected // "") }
    ] };

def task_signoff($idx; $text):
  { type: "taskItem",
    attrs: { localId: ("s" + ($idx | tostring)), state: "TODO" },
    content: [{ type: "text", text: $text }] };

# The doc skeleton. Rollout section appears only when $rollout is non-empty.
{
  type: "doc",
  version: 1,
  content: (
    [
      heading("Context"; 3),
      para($context),
      heading("Risks"; 3),
      risks_list($risks)
    ]
    + (
      if ($rollout | length) > 0 then
        [ heading("Rollout cadence"; 3), bullets($rollout) ]
      else
        []
      end
    )
    + (
      if ($prereqs | length) > 0 then
        [ heading("Pre-requisites"; 3), bullets($prereqs) ]
      else
        []
      end
    )
    + [
      heading("Test cases"; 3),
      {
        type: "taskList",
        attrs: { localId: "cases" },
        content: ([$cases | to_entries[] | task_case(.key + 1; .value)])
      }
    ]
    + (
      if ($signoff | length) > 0 then
        [ heading("Sign-off"; 3),
          { type: "taskList",
            attrs: { localId: "signoff" },
            content: ([$signoff | to_entries[] | task_signoff(.key + 1; .value)]) } ]
      else
        []
      end
    )
  )
}
