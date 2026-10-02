#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT_ID:-admob-app-id-9658087638}"
API_KEY="${FIREBASE_WEB_API_KEY:-AIzaSyAdt_EM52cUKuMTsPyKyQJUYiawde2pOjY}"
BASE_URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/dailyPuzzles"

localizations_for_title() {
  case "$1" in
    Titanic)
      printf '%s' '{"fr-FR":{"title":"Titanic","emoji_clue":"🚢🧊❤️","hint_1":"Sorti au cinéma en 1997","hint_2":"Réalisé par James Cameron","accepted_answers":["titanic"]},"es-MX":{"title":"Titanic","emoji_clue":"🚢🧊❤️","hint_1":"Se estrenó en cines en 1997","hint_2":"Dirigida por James Cameron","accepted_answers":["titanic"]},"pt-BR":{"title":"Titanic","emoji_clue":"🚢🧊❤️","hint_1":"Lançado nos cinemas em 1997","hint_2":"Dirigido por James Cameron","accepted_answers":["titanic"]}}'
      ;;
    *)
      printf '{}'
      ;;
  esac
}

seed_row() {
  local date="$1"
  local tmdb_id="$2"
  local title="$3"
  local emoji_clue="$4"
  local hint_1="$5"
  local hint_2="$6"
  local answers_csv="$7"
  local source="${8:-manual-seed}"
  local generated_at="${9:-${date}T05:00:00.000Z}"
  local localizations_json="${10:-$(localizations_for_title "$title")}"

  local answers_json
  answers_json="$(jq -n --arg csv "$answers_csv" '($csv | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)))')"

  local payload
  payload="$(jq -n \
    --arg date "$date" \
    --arg puzzle_id "$date" \
    --arg media_type "movie" \
    --arg tmdb_id "$tmdb_id" \
    --arg title "$title" \
    --arg emoji_clue "$emoji_clue" \
    --arg hint_1 "$hint_1" \
    --arg hint_2 "$hint_2" \
    --arg source "$source" \
    --arg generated_at "$generated_at" \
    --argjson answers "$answers_json" \
    --argjson localizations "$localizations_json" '
      def localized_value:
        {mapValue: {fields: {
          title: {stringValue: .title},
          emoji_clue: {stringValue: .emoji_clue},
          hint_1: {stringValue: .hint_1},
          hint_2: {stringValue: .hint_2},
          accepted_answers: {arrayValue: {values: [.accepted_answers[] | {stringValue: .}]}}
        }}};
      {
        fields: ({
          date: {stringValue: $date},
          puzzle_id: {stringValue: $puzzle_id},
          media_type: {stringValue: $media_type},
          tmdb_id: {integerValue: $tmdb_id},
          title: {stringValue: $title},
          emoji_clue: {stringValue: $emoji_clue},
          hint_1: {stringValue: $hint_1},
          hint_2: {stringValue: $hint_2},
          accepted_answers: {
            arrayValue: {
              values: ($answers | map({stringValue: .}))
            }
          },
          source: {stringValue: $source},
          generated_at: {stringValue: $generated_at}
        } + (if ($localizations | length) > 0 then {
          localizations: {mapValue: {fields: ($localizations | with_entries(.value |= localized_value))}}
        } else {} end))
      }
    ')"

  curl -fsS -X PATCH "${BASE_URL}/${date}?key=${API_KEY}" \
    -H "Content-Type: application/json" \
    --data-binary "$payload" >/dev/null
}

# date|tmdb_id|title|emoji|hint_1|hint_2|accepted_answers
ROWS=(
  "2026-02-18|27205|Inception|😴🌀🏙️|Released in 2010|Directed by Christopher Nolan|inception"
  "2026-02-19|603|The Matrix|🕶️💊🤖|Released in 1999|Features Neo and Morpheus|the matrix,matrix"
  "2026-02-20|329|Jurassic Park|🦖🌴🚙|Released in 1993|Directed by Steven Spielberg|jurassic park"
  "2026-02-21|597|Titanic|🚢🧊❤️|Released in 1997|Directed by James Cameron|titanic"
  "2026-02-22|20352|Despicable Me|🦹‍♂️👧🍌|An animated comedy about a supervillain|He adopts three sisters and has yellow helpers|despicable me"
  "2026-02-23|155|The Dark Knight|🃏🦇🌃|Released in 2008|Gotham vigilante faces the Joker|the dark knight,dark knight"
  "2026-02-24|920|Cars|🏎️🏁⚡|An animated racing adventure|Lightning McQueen learns life is more than winning|cars,disney cars,pixar cars"
  "2026-02-25|13|Forrest Gump|🏃🍫🚌|Released in 1994|Life is like a box of chocolates|forrest gump"
  "2026-02-26|585|Monsters, Inc.|👹🚪😱|Animated monsters collect children's screams|Sulley and Mike work behind magical closet doors|monsters inc,monsters incorporated"
  "2026-02-27|122|The Lord of the Rings: The Return of the King|💍🌋👑|Released in 2003|Concludes the original LOTR trilogy|the lord of the rings the return of the king,the return of the king"
  "2026-02-28|24428|The Avengers|🦸⚡🌍|Released in 2012|Marvel heroes assemble in New York|the avengers,avengers"
  "2026-03-01|299534|Avengers: Endgame|🦸🫰⌛|Released in 2019|Concludes Marvel's Infinity Saga|avengers endgame,avengers: endgame,endgame"
  "2026-03-02|24|Kill Bill: Vol. 1|🗡️🐍🩸|Released in 2003|The Bride seeks revenge|kill bill vol 1,kill bill"
  "2026-03-03|9502|Kung Fu Panda|🐼🥋🐉|An animated panda dreams of martial arts|Po is unexpectedly chosen as the Dragon Warrior|kung fu panda"
  "2026-03-04|238|The Godfather|👴🍝🔫|Released in 1972|Directed by Francis Ford Coppola|the godfather,godfather"
  "2026-03-05|9806|The Incredibles|🦸‍♀️👨‍👩‍👧‍👦💥|An animated family hides its superpowers|Mr. Incredible and Elastigirl return to hero work|the incredibles,incredibles"
  "2026-03-06|11|Star Wars|🚀🌌⚔️|Released in 1977|A farm boy joins the rebellion|star wars"
  "2026-03-07|150540|Inside Out|😊😢🧠|Animated emotions guide a young girl's mind|Joy and Sadness must restore Riley's memories|inside out,insideout"
  "2026-03-08|1891|The Empire Strikes Back|❄️🚀🧔|Released in 1980|Second film in original Star Wars trilogy|the empire strikes back,empire strikes back"
  "2026-03-09|269149|Zootopia|🐰🦊🏙️|An animated city where animals live like people|A rabbit police officer teams up with a fox|zootopia,zootropolis"
)

for row in "${ROWS[@]}"; do
  IFS='|' read -r date tmdb_id title emoji hint_1 hint_2 answers <<<"$row"
  seed_row "$date" "$tmdb_id" "$title" "$emoji" "$hint_1" "$hint_2" "$answers"
  printf "Seeded %s\n" "$date"
done

# Keep latest alias aligned to today's row when present, or the most recent seeded row not in the future.
# This avoids pinning clients to a future puzzle (for example when pre-seeding several upcoming days).
latest_alias_date="${LATEST_ALIAS_DATE:-$(date +%F)}"
latest_row=""
for row in "${ROWS[@]}"; do
  IFS='|' read -r row_date _ <<<"$row"
  if [[ "$row_date" < "$latest_alias_date" || "$row_date" == "$latest_alias_date" ]]; then
    latest_row="$row"
  fi
done

# If all seeded rows are in the future relative to latest_alias_date, fall back to the first row.
if [[ -z "$latest_row" ]]; then
  latest_row="${ROWS[0]}"
fi

IFS='|' read -r latest_date latest_tmdb latest_title latest_emoji latest_hint_1 latest_hint_2 latest_answers <<<"$latest_row"
latest_payload="$(jq -n \
  --arg date "$latest_date" \
  --arg puzzle_id "$latest_date" \
  --arg media_type "movie" \
  --arg tmdb_id "$latest_tmdb" \
  --arg title "$latest_title" \
  --arg emoji_clue "$latest_emoji" \
  --arg hint_1 "$latest_hint_1" \
  --arg hint_2 "$latest_hint_2" \
  --arg source "manual-seed" \
  --arg generated_at "${latest_date}T05:00:00.000Z" \
  --arg updated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson localizations "$(localizations_for_title "$latest_title")" \
  --argjson answers "$(jq -n --arg csv "$latest_answers" '($csv | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)))')" '
    def localized_value:
      {mapValue: {fields: {
        title: {stringValue: .title},
        emoji_clue: {stringValue: .emoji_clue},
        hint_1: {stringValue: .hint_1},
        hint_2: {stringValue: .hint_2},
        accepted_answers: {arrayValue: {values: [.accepted_answers[] | {stringValue: .}]}}
      }}};
    {
      fields: ({
        date: {stringValue: $date},
        puzzle_id: {stringValue: $puzzle_id},
        media_type: {stringValue: $media_type},
        tmdb_id: {integerValue: $tmdb_id},
        title: {stringValue: $title},
        emoji_clue: {stringValue: $emoji_clue},
        hint_1: {stringValue: $hint_1},
        hint_2: {stringValue: $hint_2},
        accepted_answers: {
          arrayValue: {
            values: ($answers | map({stringValue: .}))
          }
        },
        source: {stringValue: $source},
        generated_at: {stringValue: $generated_at},
        updated_at: {stringValue: $updated_at}
      } + (if ($localizations | length) > 0 then {
        localizations: {mapValue: {fields: ($localizations | with_entries(.value |= localized_value))}}
      } else {} end))
    }
  ')"

curl -fsS -X PATCH "${BASE_URL}/latest?key=${API_KEY}" \
  -H "Content-Type: application/json" \
  --data-binary "$latest_payload" >/dev/null

printf "Updated latest -> %s\n" "$latest_date"
printf "Latest alias reference date: %s\n" "$latest_alias_date"
printf "Seed complete. Collection: dailyPuzzles (%s docs + latest).\n" "${#ROWS[@]}"
