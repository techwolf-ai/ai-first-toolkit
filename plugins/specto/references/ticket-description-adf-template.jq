# jq template for the create-ticket description body.
#
# WHY ADF and not markdown:
# Some `acli` versions DO NOT auto-convert markdown to ADF when called via
# `--description-file <path>`. The result on some Jira Cloud tenants is that
# `### Heading`, `- bullet`, and `- [ ] checkbox` lines render as LITERAL TEXT
# in the ticket body — the user sees the `###` characters in the rendered page.
# Building the ADF document up front bypasses the acli rendering quirk and
# guarantees a consistent body shape regardless of the helper's auto-conversion
# behaviour. (`md_to_adf.py` is the same idea inside `create-ticket.sh`; this
# template is the static-shape version for the create-ticket flow where
# the section layout is fixed.)
#
# Inputs (supplied via --arg / --argjson at call time):
#   $context              string       Short paragraph for "Context".
#   $goal                 string       Short paragraph for "Goal".
#   $scope                [string|{title,body}]  Scope bullets. A bare string
#                                                renders as one bullet; an
#                                                object renders **bold title**
#                                                followed by the body inline.
#   $out_of_scope         [string]     Out-of-scope bullets. Pass `[]` to omit
#                                                the section entirely.
#   $acceptance_criteria  [string]     Checkbox-style taskItems (TODO). Each is
#                                                an unticked checkbox the
#                                                reviewer ticks as they verify.
#                                                Pass `[]` to omit the section.
#
# Critical invariant encoded ONCE here: every `taskItem.content` array holds
# inline runs DIRECTLY — NO `paragraph` wrapper. acli rejects with
# `INVALID_INPUT` when `taskItem.content[0].type == "paragraph"`.
#
# Caller (create-ticket skill):
#   jq -n \
#     --arg     context "$CONTEXT" \
#     --arg     goal "$GOAL" \
#     --argjson scope "$SCOPE_JSON" \
#     --argjson out_of_scope "$OOS_JSON" \
#     --argjson acceptance_criteria "$AC_JSON" \
#     -f "${CLAUDE_PLUGIN_ROOT}/references/ticket-description-adf-template.jq" \
#     > "$adf_tmp"
#
# Output: a complete ADF document object on stdout.

def heading($text; $level):
  { type: "heading", attrs: {level: $level},
    content: [{ type: "text", text: $text }] };

def para($text):
  { type: "paragraph",
    content: [{ type: "text", text: $text }] };

# A scope bullet can be a plain string OR an object {title, body} that renders
# as bold title + plain body inline.
def scope_item($it):
  if ($it | type) == "string" then
    { type: "listItem", content: [para($it)] }
  else
    { type: "listItem", content: [{
        type: "paragraph",
        content: (
          [ { type: "text", text: ($it.title + " "), marks: [{ type: "strong" }] } ]
          + (if ($it.body // "") == "" then [] else [{ type: "text", text: $it.body }] end)
        )
      }] }
  end;

def scope_list($items):
  { type: "bulletList",
    content: ($items | map(scope_item(.))) };

def bullets($items):
  { type: "bulletList",
    content: ($items | map({
      type: "listItem",
      content: [para(.)]
    })) };

# Acceptance-criteria items render as unticked taskItems. localIds stable
# across renders so a re-run doesn't perturb existing IDs.
def ac_item($idx; $text):
  { type: "taskItem",
    attrs: { localId: ("ac" + ($idx | tostring)), state: "TODO" },
    content: [{ type: "text", text: $text }] };

{
  type: "doc",
  version: 1,
  content: (
    [ heading("Context"; 3), para($context),
      heading("Goal"; 3),    para($goal),
      heading("Scope"; 3),   scope_list($scope) ]
    + (
      if ($out_of_scope | length) > 0 then
        [ heading("Out of scope"; 3), bullets($out_of_scope) ]
      else
        []
      end
    )
    + (
      if ($acceptance_criteria | length) > 0 then
        [ heading("Acceptance criteria"; 3),
          { type: "taskList",
            attrs: { localId: "ac" },
            content: ([$acceptance_criteria | to_entries[] | ac_item(.key + 1; .value)]) } ]
      else
        []
      end
    )
  )
}
