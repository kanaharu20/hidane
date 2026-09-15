# hidane next.awk — next.sh の順位付け・集中・型の決定。next.sh から awk -f で呼ぶ(-v で表と文言を受け取る)。単独では動かない。
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function rank(st) { return (st == "unknown" ? 0 : st == "fuzzy" ? 1 : st == "unasked" ? 2 : 9) }
function label(st) { return (st == "known" ? l_known : st == "fuzzy" ? l_fuzzy : st == "unknown" ? l_unknown : l_unasked) }
BEGIN {
  while ((getline l < map) > 0) { split(l, t, "\t"); c = t[1]; val[c] = t[2]; st[c] = t[5]; if (!(c in st)) st[c] = "unasked" }
  while ((getline l < alllog) > 0) {
    split(l, t, "\t"); repo = t[1]; split(t[2], col, "|"); z = trim(col[9]); res = trim(col[8]); k = split(trim(col[5]), cs, ",")
    for (i = 1; i <= k; i++) { c = trim(cs[i]); sub(/^\*/, "", c); if (c == "") continue
      if (res != "skip" && res != "dispute") answered[c] = 1
      if (z != "") zure[c] = zure[c] "- " (res == "dispute" ? l_dispute ": " : "") z "(" repo ", " substr(trim(col[2]), 1, 10) ")\n" }
  }
}
{
  kind = $1; split($2, col, "|"); place = trim(col[3]); fnm = trim(col[4]); k = split(trim(col[5]), cs, ","); for (i = 1; i <= k; i++) sub(/^\*/, "", cs[i])
  f = place; sub(/:[^:]*$/, "", f); fk = f "\t" fnm
  if (kind == "log") { asked[fk] = 1; next }
  if (kind == "stale") next
  if (place in seenp) next; seenp[place] = 1
  for (i = 1; i <= k; i++) { c = trim(cs[i]); if (c == "") continue; cand[place] = cand[place] (cand[place] == "" ? "" : ", ") c; fname[place] = fnm; fkey[place] = fk }
}
END {
  m = 0
  for (p in cand) {
    if (fkey[p] in asked) continue
    best = 99; bv = 999; bc = ""
    k = split(cand[p], cs, ", ")
    for (i = 1; i <= k; i++) { c = cs[i]; r = rank(st[c]); v = val[c] + 0; if (r < best || (r == best && v < bv)) { best = r; bv = v; bc = c } }
    if (best == 9) continue
    m++; key[m] = sprintf("%d\t%+04d\t%s", best, bv + 100, p); P[m] = p; C[m] = bc
  }
  if (m == 0) { print none_cand (stale > 0 ? " (" stale_note ")" : "") > "/dev/stderr"; exit 1 }
  # 集中: 概念が決まっていればその概念を持つ候補だけ残す(順位はその概念で付け直す)。"?" なら順位最上位の概念に決める
  if (focus != "") {
    if (focus == "?") { best = 99; bv = 999; for (i = 1; i <= m; i++) { c = C[i]; r = rank(st[c]); v = val[c] + 0; if (r < best || (r == best && v < bv)) { best = r; bv = v; focus = c } } }
    mm = 0
    for (i = 1; i <= m; i++) { if ((", " cand[P[i]] ", ") ~ (", " focus ", ")) { mm++; key[mm] = sprintf("%d\t%+04d\t%s", rank(st[focus]), val[focus] + 100, P[i]); P[mm] = P[i]; C[mm] = focus } }
    if (mm == 0) { printf(n_focus_none "\n", focus); focus = ""; printf("") > ff; close(ff); system("rm -f " ff) }
    else { m = mm; printf("%s\t%s\n", focus, fleft) > ff; close(ff) }
  }
  for (i = 2; i <= m; i++) { for (j = i; j > 1 && key[j] < key[j-1]; j--) { sw = key[j]; key[j] = key[j-1]; key[j-1] = sw; sw = P[j]; P[j] = P[j-1]; P[j-1] = sw; sw = C[j]; C[j] = C[j-1]; C[j-1] = sw } }
  if (n > 1) {
    printf("| # | %s | %s | %s | %s | %s | %s |\n|---|---|---|---|---|---|---|\n", h_place, h_func, n_lead, h_state, h_value, n_concepts)
    for (i = 1; i <= m && i <= n; i++) printf("| %d | %s | %s | %s | %s | %+d | %s |\n", i, P[i], fname[P[i]], C[i], label(st[C[i]]), val[C[i]], cand[P[i]])
    exit 0
  }
  p = P[1]; c = C[1]
  if (focus != "") printf(n_focus_left "\n", focus, fleft)
  printf("%s: %s\n%s: %s\n%s: %s\n%s: %s(%s, %+d)\n", n_place, p, n_func, fname[p], n_concepts, cand[p], n_lead, c, label(st[c]), val[c])
  printf("%s: %s\n", n_why, (st[c] == "unknown" ? why_unknown : st[c] == "fuzzy" ? why_fuzzy : why_unasked))
  if (c in answered) { type = "edge"; if (zure[c] != "") printf("%s(%s):\n%s", n_zure, c, zure[c]); printf("%s: edge (%s) — %s\n%s: %s\n", n_type, ty_edge, edge_hint, n_inputs, in_edge) }
  else { type = "trace"; printf("%s: trace (%s)\n%s: %s\n", n_type, ty_trace, n_inputs, in_trace) }
  printf("%s: %s\n", n_form, form_text)
  printf("%s\t%s\t%s\t%s\t%s\n", p, fname[p], cand[p], type, c) > pending
  close(pending)
}
