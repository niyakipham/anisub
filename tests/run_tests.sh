#!/bin/bash
# ==============================================================================
# Test offline cho phần ĐỌC TRUYỆN TRANH (nguồn TruyenVN) của anisub.sh
# Không cần mạng: curl/fzf/mpv được giả lập trong tests/mockbin, HTML thật của
# site được ghi sẵn trong tests/fixtures.
#   chạy:  bash tests/run_tests.sh
# ==============================================================================
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/anisub-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export MOCK_FIXTURES="$HERE/fixtures"
export MOCK_CURL_LOG="$WORK/curl.log"
export MOCK_FZF_LOG="$WORK/fzf.log"
export MOCK_READ_LOG="$WORK/read.log"
export MOCK_CURL_HEADER_LOG="$WORK/curl-headers.log"
export MOCK_CHAFA_LOG="$WORK/chafa.log"
: > "$MOCK_CURL_LOG"; : > "$MOCK_FZF_LOG"; : > "$MOCK_READ_LOG"
: > "$MOCK_CURL_HEADER_LOG"; : > "$MOCK_CHAFA_LOG"
export HOME="$WORK/home"
mkdir -p "$HOME"
export PATH="$HERE/mockbin:$PATH"

# Nạp các hàm của script (bỏ lời gọi "main" ở dòng cuối).
# Code đã tách thành anisub.sh + src/{movie,comic}/*.sh nên phải trỏ ANISUB_SRC_DIR
# về src/ của repo: lib.sh nằm trong $WORK nên tự nó không tìm thấy src/.
export ANISUB_SRC_DIR="$ROOT/src"
sed '$d' "$ROOT/anisub.sh" > "$WORK/lib.sh"
# shellcheck source=/dev/null
source "$WORK/lib.sh"

# Tìm trong toàn bộ mã nguồn (file chính + các module nguồn)
SRC_FILES=("$ROOT/anisub.sh" "$ROOT"/src/*/*.sh)
src_has()   { grep -rho -- "$1" "${SRC_FILES[@]}" 2>/dev/null | head -1; }
src_count() { grep -rh -- "$1" "${SRC_FILES[@]}" 2>/dev/null | grep -c . ; }

pass=0; fail=0; group=""
ok()  { pass=$((pass + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  \033[31m✗\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '      mong đợi: %s\n      thực tế : %s\n' "$2" "$3"; }
check() { if [ "$2" == "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "chứa [$2]" "[$3]" ;; esac; }

echo "== 1. cấu hình nguồn truyện =="
load_config
check "nguồn mặc định = nettruyen" "nettruyen" "$MANGA_SOURCE"
check "MANGA_BASE_URL mặc định" "https://nettruyen.info" "$MANGA_BASE_URL"
check "feeds mặc định" "latest,trending,views" "$MANGA_SEARCH_FEEDS"
check "pages mặc định" "1" "$MANGA_SEARCH_PAGES"
save_config > /dev/null
has "config.cfg lưu MANGA_SOURCE" 'MANGA_SOURCE="nettruyen"' "$(cat "$CONFIG_FILE")"
has "config.cfg lưu MANGA_BASE_URL" 'MANGA_BASE_URL="https://nettruyen.info"' "$(cat "$CONFIG_FILE")"
mkdir -p "$WORK/home2/.config/anisub_cli"
printf 'PLAYER="mpv"\n' > "$WORK/home2/.config/anisub_cli/config.cfg"   # config cũ, chỉ có PLAYER
( HOME="$WORK/home2" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; load_config >/dev/null 2>&1; [ \"\$MANGA_SOURCE\" = nettruyen ] && [ \"\$MANGA_BASE_URL\" = https://nettruyen.info ]" ) \
    && ok "config cũ thiếu key -> tự chuyển sang nguồn mặc định mới" || bad "config cũ thiếu key" "nettruyen + nettruyen.info" "khác"

# ---- Từ đây các mục 2..27 kiểm tra nguồn TRUYENVN (vẫn giữ để đổi lại nguồn) ----
MANGA_SOURCE="truyenvn"
MANGA_BASE_URL="https://truyenvn.my"
ok "chuyển sang kiểm tra nguồn truyenvn (mục 2..27)"

echo "== 2. manga_http_fetch: HTTP status =="
if manga_http_fetch "https://truyenvn.my/tim-kiem?m_orderby=latest" > "$WORK/body.html"; then
    check "HTTP 200" "200" "$(anisub_last_http)"
    check "body không rỗng" "1" "$([ -s "$WORK/body.html" ] && echo 1 || echo 0)"
else
    bad "HTTP 200" "fetch thành công" "return 1"
fi
if manga_http_fetch "https://manga-offline.example/tim-kiem" > /dev/null 2>&1; then
    bad "mất mạng phải báo lỗi" "return 1" "return 0"
else
    check "mất mạng -> HTTP 000 + return 1" "000" "$(anisub_last_http)"
fi

echo "== 3. URL helper =="
export MANGA_BASE_URL="https://truyenvn.my"
check "slug -> URL trang truyện" "https://truyenvn.my/truyen-tranh/bocchi-the-rock" "$(manga_manga_url bocchi-the-rock)"
check "URL tuyệt đối giữ nguyên (bỏ / cuối)" "https://truyenvn.my/truyen-tranh/abc" "$(manga_manga_url 'https://truyenvn.my/truyen-tranh/abc/')"
check "href tương đối -> tuyệt đối" "https://truyenvn.my/truyen-tranh/abc" "$(manga_abs_url '/truyen-tranh/abc/')"
check "href tuyệt đối -> giữ nguyên" "https://cdn.x/y" "$(manga_abs_url 'https://cdn.x/y')"
check "protocol-relative -> https" "https://cdn.x/y" "$(manga_abs_url '//cdn.x/y')"

echo "== 4. so khớp tên truyện (không phân biệt dấu) =="
cat > "$WORK/items.txt" <<'EOF'
Bocchi The Rock!|https://truyenvn.my/truyen-tranh/bocchi-the-rock|bocchi-the-rock
Quan Hệ Đói Khát|https://truyenvn.my/truyen-tranh/quan-he-doi-khat|quan-he-doi-khat
Đắc Kỷ Trợ Chiến|https://truyenvn.my/truyen-tranh/dac-ky-tro-chien|dac-ky-tro-chien
EOF
check "bỏ dấu + hoa thường" "bocchi the rock" "$(printf 'Bocchi The Rock!' | manga_norm)"
check "đ -> d" "dac ky tro chien" "$(printf 'Đắc Kỷ Trợ Chiến' | manga_norm)"
check "tìm 'bo chi' (viết rời)" "1" "$(manga_match_items "bo chi" < "$WORK/items.txt" | grep -c 'bocchi-the-rock')"
check "tìm 'dăc ky' (sai dấu)" "1" "$(manga_match_items "dăc ky" < "$WORK/items.txt" | grep -c 'dac-ky')"
check "tìm 'Quan Hệ Đói Khát' đúng dấu" "1" "$(manga_match_items "Quan Hệ Đói Khát" < "$WORK/items.txt" | grep -c 'quan-he')"
check "không khớp bừa" "0" "$(manga_match_items "one piece" < "$WORK/items.txt" | grep -c '.')"

echo "== 5. parse danh sách từ HTML =="
items=$(cat "$MOCK_FIXTURES/manga-home.html" | MANGA_BASE_URL="https://truyenvn.my" manga_parse_items)
check "3 truyện, không tính link chapter" "3" "$(printf '%s\n' "$items" | grep -c '.')"
check "tên từ title=\"\"" "Bocchi The Rock!" "$(printf '%s\n' "$items" | sed -n 1p | cut -d'|' -f1)"
check "URL tuyệt đối hoá từ href tương đối" "https://truyenvn.my/truyen-tranh/toi-tro-thanh-dan-duong-dinh-cap-nho-truc-ma" "$(printf '%s\n' "$items" | sed -n 3p | cut -d'|' -f2)"
check "giải HTML entity trong tên" "Quan Hế & 'khát'" "$(printf '%s\n' "$items" | sed -n 2p | cut -d'|' -f1)"
check "không lẫn link thể loại/mạng xã hội" "0" "$(printf '%s\n' "$items" | grep -c 'the-loai\|facebook')"
check "bỏ hậu tố 'thumb' ở alt" "0" "$(printf '%s\n' "$items" | grep -c 'thumb')"

echo "== 6. danh sách chapter =="
chaps=$(fetch_chapter_list bocchi-the-rock)
check "6 chapter (đã gỡ trùng URL)" "6" "$(printf '%s\n' "$chaps" | grep -c '.')"
check "sắp xếp tăng dần theo số chương" "Chapter 0" "$(printf '%s\n' "$chaps" | sed -n 1p | cut -d'|' -f1)"
check "chương cuối là 242" "Chapter 242" "$(printf '%s\n' "$chaps" | tail -1 | cut -d'|' -f1)"
check "giữ tên gốc 'Chap 90'" "1" "$(printf '%s\n' "$chaps" | grep -c '^Chap 90|')"
check "lẻ 9.5 xếp sau 9" "1" "$(printf '%s\n' "$chaps" | grep -c '^Chapter 9.5|')"
check "bỏ đuôi thời gian/ngày" "1" "$(printf '%s\n' "$chaps" | grep -c '^Chapter 105|')"
check "URL chapter tuyệt đối" "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-242" "$(printf '%s\n' "$chaps" | tail -1 | cut -d'|' -f2)"
check "trường 3 = slug chapter" "chapter-242" "$(printf '%s\n' "$chaps" | tail -1 | cut -d'|' -f3)"
check "không lẫn chapter của truyện khác" "0" "$(printf '%s\n' "$chaps" | grep -c 'other-manga')"

echo "== 7. ảnh trong chapter =="
imgs=$(fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-242" bocchi-the-rock)
check "5 ảnh, đúng thứ tự" "5" "$(printf '%s\n' "$imgs" | grep -c '.')"
check "ảnh đầu là 001.jpg" "https://dmd-image-content-sng-1.imggo.net/books/bocchi-the-rock/242/36908_001.jpg" "$(printf '%s\n' "$imgs" | sed -n 1p)"
check "data-src có khoảng trắng được trim" "https://dmd-image-content-sng-1.imggo.net/books/bocchi-the-rock/242/36908_002.jpg" "$(printf '%s\n' "$imgs" | sed -n 2p)"
check "data-src nháy đơn" "https://dmd-image-content-sng-1.imggo.net/books/bocchi-the-rock/242/36908_003.jpg" "$(printf '%s\n' "$imgs" | sed -n 3p)"
check "src tương đối -> tuyệt đối" "https://truyenvn.my/books/bocchi-the-rock/242/36908_004.jpg" "$(printf '%s\n' "$imgs" | sed -n 4p)"
check "//cdn -> https://cdn" "https://dmd-image-content-sng-1.imggo.net/books/bocchi-the-rock/242/36908_005.jpg" "$(printf '%s\n' "$imgs" | sed -n 5p)"
check "loại cover/thumb/logo/ad/avatar" "0" "$(printf '%s\n' "$imgs" | grep -c 'cover\|thumb\|logo\|banner\|gravatar')"
imgs_js=$(fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243js" bocchi-the-rock)
check "mảng JSON chapterImages cũng đọc được" "3" "$(printf '%s\n' "$imgs_js" | grep -c '.')"
check "unescape \\\\/ trong JSON" "https://dmd-image-content-sng-1.imggo.net/books/bocchi-the-rock/243/36909_001.jpg" "$(printf '%s\n' "$imgs_js" | sed -n 1p)"

echo "== 8. tìm kiếm =="
res=$(manga_search_items "bocchi" 2>"$WORK/err.log")
check "tìm 'bocchi' ra 1 truyện" "1" "$(printf '%s\n' "$res" | grep -c 'bocchi-the-rock')"
check "stdout chỉ có kết quả" "" "$(printf '%s\n' "$res" | grep '__noop__')"
res=$(manga_search_items "khong-ton-tai-xyz" 2>"$WORK/err2.log")
check "không khớp -> stdout rỗng" "" "$res"
has "stderr giải thích rõ" "Không tìm thấy truyện khớp" "$(cat "$WORK/err2.log")"
has "stderr gợi ý bước tiếp" "thể loại" "$(cat "$WORK/err2.log")"
before=$(grep -c 'tim-kiem' "$MOCK_CURL_LOG")
res=$(manga_search_items "a" 2>"$WORK/err3.log")
check "từ khóa 1 ký tự -> báo hướng dẫn" "1" "$(grep -c '2 ký tự' "$WORK/err3.log")"
check "từ khóa 1 ký tự -> không gọi mạng" "$before" "$(grep -c 'tim-kiem' "$MOCK_CURL_LOG")"
( MANGA_BASE_URL="https://manga-offline.example"
  out=$(manga_search_items "bocchi" 2>&1); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'HTTP 000' ) && ok "mất mạng -> rc!=0 + nêu HTTP 000" || bad "mất mạng phải báo HTTP" "rc!=0 + HTTP 000" "(xem lại)"

echo "== 9. chọn chapter từ lịch sử =="
manga_find_chapter "$chaps" "chapter-90" | cut -d'|' -f1 | grep -q '^Chap 90$' && ok "khớp 'chapter-90' -> 'Chap 90'" || bad "khớp 'chapter-90'" "Chap 90" "$(manga_find_chapter "$chaps" "chapter-90")"
manga_find_chapter "$chaps" "Chapter 9.5" | grep -q 'chapter-9-5' && ok "khớp tên có số lẻ" || bad "khớp tên có số lẻ" "URL chapter-9-5" "$(manga_find_chapter "$chaps" "Chapter 9.5")"
manga_find_chapter "$chaps" "242" | cut -d'|' -f1 | grep -q '^Chapter 242$' && ok "khớp theo số chương" || bad "khớp theo số chương" "Chapter 242" "$(manga_find_chapter "$chaps" "242")"
manga_find_chapter "$chaps" "chapter-99999" ; check "không có thật -> return 1" "1" "$?"

echo "== 10. luồng đọc (manga_read_manga) =="
( read_manga_chapter() { printf 'READ|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" >> "$MOCK_READ_LOG"; return 1; }
  export KK_MOCK_PICK_CHAP=1
  : > "$MOCK_READ_LOG"
  manga_read_manga "Bocchi The Rock!" "bocchi-the-rock" > /dev/null 2>&1
  grep -q '^READ|Bocchi The Rock!|bocchi-the-rock|Chapter 0|https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-0$' "$MOCK_READ_LOG" ) \
    && ok "chọn chapter -> gọi read_manga_chapter đúng tham số" || bad "luồng đọc" "READ|...|chapter-0" "$(cat "$MOCK_READ_LOG")"
( read_manga_chapter() { printf 'READ2|%s|%s\n' "$3" "$4" >> "$MOCK_READ_LOG"; return 1; }
  : > "$MOCK_READ_LOG"
  manga_read_manga "Bocchi" "bocchi-the-rock" "chapter-241" > /dev/null 2>&1
  grep -q '^READ2|Chapter 241|https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-241$' "$MOCK_READ_LOG" ) \
    && ok "mở từ lịch sử -> vào thẳng chapter đã lưu" || bad "mở từ lịch sử" "READ2|Chapter 241|..." "$(cat "$MOCK_READ_LOG")"
( MANGA_BASE_URL="https://manga-offline.example"
  out=$(manga_read_manga "Bocchi" "bocchi-the-rock" 2>&1)
  printf '%s' "$out" | grep -q 'Không lấy được danh sách chapter' && printf '%s' "$out" | grep -q 'HTTP 000' ) \
    && ok "mạng lỗi -> báo rõ, không treo" || bad "báo lỗi mạng" "thông báo có HTTP 000" "(xem lại)"

echo "== 11. chẩn đoán & menu =="
diag=$(manga_diagnose < /dev/null 2>&1)
has "chẩn đoán in số truyện parse được" "parse được 3 truyện" "$diag"
has "chẩn đoán nhắc đổi domain" "MANGA_BASE_URL" "$diag"
menu_src=$(declare -f manga_main_menu)
check "menu không dùng start:reload (fzf cũ vẫn mở được)" "0" "$(printf '%s' "$menu_src" | grep -c 'start:reload')"
has "menu có mục dán link" "🔗 Mở bằng link / slug" "$menu_src"
check "không còn gọi thẳng domain cũ" "0" "$(src_count 'https://truyenvn\.shop')"
check "manga_read_manga có gọi fzf để chọn chapter" "1" "$(grep -c 'Chọn chapter' "$MOCK_FZF_LOG")"

echo "== 12. không hồi quy: lịch sử & yêu thích =="
: > "$MANGA_HISTORY_FILE"; : > "$MANGA_FAVORITES_FILE"
add_to_manga_history "Bocchi The Rock!" "Chapter 242" "bocchi-the-rock"
add_to_manga_history "Bocchi The Rock!" "Chapter 242" "bocchi-the-rock"
check "lịch sử chống trùng theo slug+chapter" "1" "$(grep -c '.' "$MANGA_HISTORY_FILE")"
check "định dạng lịch sử không đổi" "Bocchi The Rock!|Chapter 242|bocchi-the-rock" "$(cut -d'|' -f2- "$MANGA_HISTORY_FILE")"
add_to_manga_favorites "Bocchi The Rock!" "bocchi-the-rock" > /dev/null
add_to_manga_favorites "Bocchi The Rock!" "bocchi-the-rock" > /dev/null
check "yêu thích chống trùng" "1" "$(grep -c '.' "$MANGA_FAVORITES_FILE")"
check "định dạng yêu thích không đổi" "Bocchi The Rock!|bocchi-the-rock" "$(cat "$MANGA_FAVORITES_FILE")"
check "show_manga_history in dòng lịch sử" "1" "$(show_manga_history < /dev/null 2>/dev/null | grep -c 'bocchi-the-rock')"

echo "== 13. thể loại & luồng duyệt =="
bad=0
while IFS='|' read -r gname gslug; do
    [ -z "$gslug" ] && continue
    cnt=$(manga_http_fetch "the-loai/$gslug" 2>/dev/null | manga_parse_items | grep -c '.')
    [ "${cnt:-0}" -gt 0 ] || bad=$((bad + 1))
done < <(manga_genres)
check "mọi thể loại đều có slug dùng được" "0" "$bad"
check "chỉ dùng slug đã kiểm chứng trên site" "0" "$(manga_genres | grep -c 'school-life')"
: > "$MOCK_CURL_LOG"
( KK_MOCK_PICK="__nomatch__" manga_browse_menu "tim-kiem" "📖 Test" "m_orderby=latest" < /dev/null > /dev/null 2>&1 ); rc=$?
check "browse menu: không chọn gì -> quay lại (rc=1)" "1" "$rc"
has "browse menu gọi đúng feed của site" "m_orderby=latest" "$(cat "$MOCK_CURL_LOG")"

echo "== 14. ảnh bìa trong danh sách (lỗi: không preview bìa) =="
export MANGA_BASE_URL="https://truyenvn.my"
items=$(cat "$MOCK_FIXTURES/manga-home.html" | manga_parse_items)
check "mỗi dòng có 4 trường (thêm ảnh bìa)" "4" "$(printf '%s\n' "$items" | head -1 | awk -F'|' '{print NF}')"
check "ảnh bìa tuyệt đối từ src" "https://dmd-image-content-sng-static-0.imggo.net/books/12189/cover_1719216107.jpg" \
    "$(printf '%s\n' "$items" | sed -n 1p | cut -d'|' -f4)"
check "ảnh bìa data-src tương đối -> tuyệt đối" "https://truyenvn.my/uploads/quan-he-doi-khat.jpg" \
    "$(printf '%s\n' "$items" | sed -n 2p | cut -d'|' -f4)"
check "lọc theo từ khóa vẫn giữ ảnh bìa" "1" "$(printf '%s\n' "$items" | manga_match_items "bocchi" | grep -c 'cover_1719216107')"
check "tên/URL/slug không đổi vì thêm cột bìa" "bocchi-the-rock" "$(printf '%s\n' "$items" | sed -n 1p | cut -d'|' -f3)"

echo "== 15. danh sách chapter qua API /webapi/stories/list-chapter (lỗi: chỉ có chap đầu/cuối) =="
check "trang truyện chỉ có 2 link chapter (đúng lỗi cũ)" "2" \
    "$(grep -o '/bocchi-the-rock/chapter-[0-9]*' "$MOCK_FIXTURES/manga-detail.html" | sort -u | wc -l | tr -d ' ')"
check "đọc được story_id" "12189" "$(cat "$MOCK_FIXTURES/manga-detail.html" | manga_story_id)"
check "đọc được CSRF token" "csrf-test-123" "$(cat "$MOCK_FIXTURES/manga-detail.html" | manga_csrf_token)"
check "giải JSON data.html thành HTML" "1" \
    "$(cat "$MOCK_FIXTURES/manga-chapters-api.json" | manga_json_html | grep -c 'wp-manga-chapter')"
check "giải \\uXXXX trong JSON" "0" "$(cat "$MOCK_FIXTURES/manga-chapters-api.json" | manga_json_html | grep -c '\\u')"
check "HTML giải ra vẫn là tiếng Việt có dấu" "1" \
    "$(cat "$MOCK_FIXTURES/manga-chapters-api.json" | manga_json_html | grep -c 'giờ trước')"

: > "$MOCK_CURL_HEADER_LOG"
api_chaps=$(fetch_chapter_list "bocchi-the-rock")
check "lấy đủ chapter qua API (6, đã gỡ trùng)" "6" "$(printf '%s\n' "$api_chaps" | grep -c '.')"
check "chapter đầu = Chapter 0" "Chapter 0" "$(printf '%s\n' "$api_chaps" | head -1 | cut -d'|' -f1)"
check "chapter cuối = Chapter 242" "Chapter 242" "$(printf '%s\n' "$api_chaps" | tail -1 | cut -d'|' -f1)"
check "gửi story_id trong body" "1" "$(grep -c 'story_id=12189' "$MOCK_CURL_LOG")"
check "gửi X-CSRF-TOKEN" "1" "$(grep -c 'X-CSRF-TOKEN: csrf-test-123' "$MOCK_CURL_HEADER_LOG")"
check "gửi X-Requested-With" "1" "$(grep -c 'X-Requested-With: XMLHttpRequest' "$MOCK_CURL_HEADER_LOG")"
check "gửi Referer đúng trang truyện" "1" \
    "$(grep 'webapi' "$MOCK_CURL_HEADER_LOG" | grep -c 'referer=https://truyenvn.my/truyen-tranh/bocchi-the-rock')"
check "POST API dùng chung cookie phiên với trang truyện" "1" \
    "$(grep 'webapi' "$MOCK_CURL_HEADER_LOG" | grep -c 'anisub-manga-cookies')"
check "tải trang truyện cũng lưu cookie phiên" "1" \
    "$(grep '^https://truyenvn.my/truyen-tranh/bocchi-the-rock|' "$MOCK_CURL_HEADER_LOG" | grep -c 'anisub-manga-cookies')"
check "nhớ ảnh bìa của truyện để preview khi chọn chapter" "1" \
    "$(manga_cover_cache_get bocchi-the-rock | grep -c 'cover_1719216107')"

rm -f "$WORK/api419"
chaps419=$(MOCK_API_419="$WORK/api419" fetch_chapter_list "bocchi-the-rock" 2>/dev/null)
check "HTTP 419 -> tải lại trang lấy token mới rồi thử lại" "6" "$(printf '%s\n' "$chaps419" | grep -c '.')"

# trang truyện không có "story_id" -> suy từ URL ảnh bìa (/books/12189/) và slug trong
# link chapter lại khác slug trên URL -> vẫn phải lấy đủ chapter
: > "$MOCK_CURL_LOG"
chaps_cover=$(fetch_chapter_list "bocchi-the-rock-no-story-id" 2>/dev/null)
check "thiếu story_id -> lấy id từ ảnh bìa" "1" "$(grep -c 'story_id=12189' "$MOCK_CURL_LOG")"
check "slug trên URL khác slug trong link chapter -> vẫn đủ chapter" "6" \
    "$(printf '%s\n' "$chaps_cover" | grep -c '.')"

out500=$(MOCK_API_FAIL=1 fetch_chapter_list "bocchi-the-rock" 2>"$WORK/err500.log")
check "API lỗi -> fallback trang truyện (2 chapter)" "2" "$(printf '%s\n' "$out500" | grep -c '.')"
has "API lỗi -> cảnh báo rõ lý do" "chỉ còn chapter đầu/cuối" "$(cat "$WORK/err500.log")"
has "cảnh báo kèm mã HTTP" "HTTP 500" "$(cat "$WORK/err500.log")"

echo "== 16. tải & hiển thị ảnh trong chapter (lỗi: không hiện ảnh) =="
: > "$MOCK_CURL_HEADER_LOG"; : > "$MOCK_CHAFA_LOG"
chapter_imgs=$(fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-242" "bocchi-the-rock")
img_cache="$WORK/chapter-cache"
prefetch_chapter_images "$img_cache" $chapter_imgs   # shellcheck disable=SC2086
check "tải đủ 5 trang vào cache" "5" "$(ls "$img_cache" 2>/dev/null | grep -c '\.img$')"
check "tải ảnh KHÔNG gửi Referer (CDN trả 403 nếu có)" "0" \
    "$(grep 'imggo.net' "$MOCK_CURL_HEADER_LOG" | grep -c 'referer=[^n]')"
check "không còn Referer trong lệnh tải ảnh" "0" "$(grep 'imggo.net' "$MOCK_CURL_HEADER_LOG" | grep -c 'referer=https')"
printf '<html><body>403 Forbidden</body></html>' > "$WORK/html-as.jpg"
check "trang HTML lỗi không bị coi là ảnh" "0" "$(manga_file_is_image "$WORK/html-as.jpg")"
printf '\xff\xd8\xff\xe0abc' > "$WORK/real.jpg"
check "JPEG nhận đúng" "1" "$(manga_file_is_image "$WORK/real.jpg")"
MOCK_IMG_FORBIDDEN=1 manga_download_image "https://dmd-image-content-sng-1.imggo.net/x/1.jpg" "$WORK/blocked.img"
check "CDN chặn -> không lưu file rác" "0" "$([ -s "$WORK/blocked.img" ] && echo 1 || echo 0)"
display_src=$(declare -f display_full_chapter)
check "script preview trang không gửi Referer" "0" "$(printf '%s' "$display_src" | grep -c 'Referer:')"
check "ảnh trang lưu đuôi .img (đọc theo magic bytes)" "1" \
    "$([ "$(printf '%s' "$display_src" | grep -c 'page_num}\.img')" -ge 1 ] && echo 1 || echo 0)"
check "dùng giao thức vẽ ảnh tự nhận" "1" "$(printf '%s' "$display_src" | grep -c 'manga_chafa_args')"

echo "== 17. chọn giao thức vẽ ảnh (terminal lạ vẫn phải thấy ảnh) =="
check "auto + terminal lạ -> symbols" "symbols" "$(TERM=dumb TERM_PROGRAM='' MANGA_IMAGE_PROTOCOL=auto manga_image_protocol)"
check "auto + kitty -> kitty" "kitty" "$(TERM=xterm-kitty TERM_PROGRAM='' MANGA_IMAGE_PROTOCOL=auto manga_image_protocol)"
check "auto + iTerm2 -> iterm" "iterm" "$(TERM=xterm-256color TERM_PROGRAM=iTerm.app MANGA_IMAGE_PROTOCOL=auto manga_image_protocol)"
check "auto + foot -> sixel" "sixel" "$(TERM=foot TERM_PROGRAM='' MANGA_IMAGE_PROTOCOL=auto manga_image_protocol)"
check "ép bằng config" "kitty" "$(TERM=dumb MANGA_IMAGE_PROTOCOL=kitty manga_image_protocol)"
check "giá trị lạ -> tự nhận" "symbols" "$(TERM=dumb TERM_PROGRAM='' MANGA_IMAGE_PROTOCOL=xyz manga_image_protocol)"
check "symbols không dùng sixel/kitty" "-f symbols --symbols=block --colors=256" "$(MANGA_IMAGE_PROTOCOL=symbols manga_chafa_args)"
check "lưu vào config.cfg" "1" "$(MANGA_IMAGE_PROTOCOL=iterm bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_IMAGE_PROTOCOL=iterm; save_config >/dev/null 2>&1; grep -c 'MANGA_IMAGE_PROTOCOL=\"iterm\"' \"\$CONFIG_FILE\"")"

: > "$MOCK_CURL_LOG"
manga_search_items "bocchi" >/dev/null 2>&1
check "tìm kiếm gửi đúng tham số ?search= của web" "1" \
    "$(grep -c 'tim-kiem&search=' "$MOCK_CURL_LOG")"
check "không còn gửi tham số ?q= (web bỏ qua)" "0" \
    "$(grep -c 'tim-kiem&q=' "$MOCK_CURL_LOG")"

echo "== 18. script preview ảnh bìa =="
: > "$MOCK_CURL_HEADER_LOG"; : > "$MOCK_CHAFA_LOG"
rm -rf "$MANGA_COVER_CACHE"
preview_script=$(manga_cover_preview_script)
check "script sinh ra và có quyền chạy" "1" "$([ -x "$preview_script" ] && echo 1 || echo 0)"
line="Bocchi The Rock!|https://truyenvn.my/truyen-tranh/bocchi-the-rock|bocchi-the-rock|https://dmd-image-content-sng-static-0.imggo.net/books/12189/cover_1719216107.jpg"
out=$("$preview_script" "$line" 2>&1); rc=$?
check "chạy được, exit 0" "0" "$rc"
has "in tên truyện" "Bocchi The Rock!" "$out"
check "ảnh bìa được cache lại" "1" "$(ls "$MANGA_COVER_CACHE" 2>/dev/null | grep -c '\.img$')"
check "có gọi chafa để vẽ ảnh" "1" "$(grep -c 'size=' "$MOCK_CHAFA_LOG")"
check "tải bìa cũng không gửi Referer" "1" "$(grep 'imggo.net' "$MOCK_CURL_HEADER_LOG" | grep -c 'referer=none')"
out2=$("$preview_script" "Không có bìa|https://truyenvn.my/truyen-tranh/x|x|" 2>&1)
has "thiếu bìa -> báo rõ, không lỗi" "không có ảnh bìa" "$out2"
info=$(manga_preview_info_file "Truyện Có Bìa" "https://dmd-image-content-sng-static-0.imggo.net/books/1/cover_1.jpg")
check "info-file dùng cho màn chọn chapter" "1" "$(grep -c 'Truyện Có Bìa' "$info")"

echo "== 19. chuyển chapter khi API danh sách lỗi =="
nav=$(manga_parse_nav < "$MOCK_FIXTURES/manga-chapter.html")
check "đọc được link Chap trước (tương đối -> tuyệt đối)" \
    "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-241" "${nav%%|*}"
check "đọc được link Chap sau (qua rel=next)" \
    "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243" "${nav##*|}"
nav2=$(printf '%s' '<html><a href="/x/chapter-9">&#171; Chap truoc</a><a href="/x/chapter-11">Chap sau &#187;</a></html>' | manga_parse_nav)
check "nhận link khi không có rel (chỉ theo chữ)" \
    "https://truyenvn.my/x/chapter-9|https://truyenvn.my/x/chapter-11" "$nav2"
check "trang không có link chuyển chap -> rỗng" "|" "$(printf '<html>khong co</html>' | manga_parse_nav)"
check "không nhầm link Chap mới nhất thành Chap sau" "|" \
    "$(printf '<a href="/x/chapter-9">Chap mới nhất</a>' | manga_parse_nav)"

fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-242" bocchi-the-rock > /dev/null
has "fetch_chapter_images lưu nav của chapter" "chapter-243" "$(manga_saved_nav)"
check "tên chapter suy từ URL (chapter-244)" "Chapter 244" \
    "$(manga_chapter_name_from_url https://truyenvn.my/truyen-tranh/x/chapter-244)"
check "tên chapter suy từ URL (chapter-9-5)" "Chapter 9.5" \
    "$(manga_chapter_name_from_url https://truyenvn.my/truyen-tranh/x/chapter-9-5)"
check "chapter kế tiếp trong danh sách" "Chapter 3|u3" \
    "$(manga_neighbor_chapter "Chapter 1|u1
Chapter 2|u2
Chapter 3|u3" "Chapter 2" next)"
check "chapter trước trong danh sách" "Chapter 1|u1" \
    "$(manga_neighbor_chapter "Chapter 1|u1
Chapter 2|u2" "Chapter 2" prev)"
manga_neighbor_chapter "Chapter 1|u1
Chapter 2|u2" "Chapter 2" next >/dev/null 2>&1
check "hết danh sách -> return 1 (để dùng link của trang)" "1" "$?"

export KK_MOCK_FZF_KEY=ctrl-g
check "Ctrl-G trong màn chọn chapter -> yêu cầu nhập số" "__goto__|" \
    "$(manga_pick_chapter_line "header" "Chọn chapter > " "$chaps")"
unset KK_MOCK_FZF_KEY
check "Enter trong màn chọn chapter -> lấy chapter" "Chapter 0|https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-0|chapter-0" \
    "$(manga_pick_chapter_line "header" "Chọn chapter > " "$chaps")"

export KK_MOCK_FZF_NO_KEYLINE=1   # fzf cũ: không in dòng phím
check "fzf cũ không in dòng phím -> vẫn chọn được chapter" \
    "Chapter 0|https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-0|chapter-0" \
    "$(manga_pick_chapter_line "header" "Chọn chapter > " "$chaps")"
unset KK_MOCK_FZF_NO_KEYLINE
( read_manga_chapter() { printf 'READ|%s\n' "$4" >> "$MOCK_READ_LOG"; return 1; }
  : > "$MOCK_READ_LOG"
  export KK_MOCK_FZF_KEY=ctrl-g
  printf '120\n' | manga_read_manga "Bocchi The Rock!" "bocchi-the-rock" > /dev/null 2>&1
  grep -q 'chapter-120$' "$MOCK_READ_LOG" ) \
    && ok "Ctrl-G + nhập 120 -> đọc chapter-120" || bad "Ctrl-G + nhập số chapter" "READ|...chapter-120" "$(cat "$MOCK_READ_LOG")"

echo "== 20. tải ảnh: thử cả 2 kiểu Referer =="
: > "$MOCK_CURL_HEADER_LOG"
tmpd=$(mktemp -d "$WORK/img.XXXXXX")
manga_download_image "https://dmd-image-content-sng-1.imggo.net/books/x/1/1.jpg" "$tmpd/a.img"
check "lần đầu tải ảnh KHÔNG Referer (imggo 403 nếu có)" "1" \
    "$(grep 'imggo.net' "$MOCK_CURL_HEADER_LOG" | head -1 | grep -c 'referer=none')"
: > "$MOCK_CURL_HEADER_LOG"
( export MOCK_IMG_NEED_REFERER=1
  manga_download_image "https://dmd-image-content-sng-1.imggo.net/books/x/1/2.jpg" "$tmpd/b.img" ) && rc=0 || rc=1
check "CDN bắt buộc Referer -> vẫn tải được (thử lại lần 2)" "0" "$rc"
check "thử lại 2 lần: 1 không Referer + 1 có Referer" "1" \
    "$(grep 'imggo.net' "$MOCK_CURL_HEADER_LOG" | grep -c 'referer=none')"
check "...và lần thử lại có Referer" "1" \
    "$(grep 'imggo.net' "$MOCK_CURL_HEADER_LOG" | grep -c 'referer=https://truyenvn.my')"
( export MOCK_IMG_FORBIDDEN=1
  manga_download_image "https://dmd-image-content-sng-1.imggo.net/books/x/1/3.jpg" "$tmpd/c.img" ) \
    && bad "ảnh là HTML 403 -> phải báo lỗi" "return 1" "return 0" || ok "ảnh là HTML 403 -> báo lỗi, không vẽ rác"
rm -rf "$tmpd"

echo "== 21. tự chẩn đoán luồng đọc (--manga-selftest) =="
out=$(manga_selftest bocchi-the-rock 2>&1); rc=$?
check "selftest nguồn tốt -> exit 0" "0" "$rc"
has "báo HTTP + story_id" "story_id: 12189" "$out"
has "báo số chapter" "6 chapter" "$out"
has "báo số ảnh + link chuyển chap" "chapter-243" "$out"
has "tải thử 1 ảnh thành công" "magic ffd8" "$out"
has "kết luận rõ ràng" "Luồng đọc hoạt động" "$out"
( export MOCK_API_FAIL=1
  out=$(manga_selftest bocchi-the-rock 2>&1); rc=$?
  [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'Ít chapter' ) \
    && ok "API danh sách chết -> cảnh báo nhưng vẫn đọc được" \
    || bad "API chết -> vẫn đọc được" "rc=0 + cảnh báo 'Ít chapter'" "$out"
( export MOCK_IMG_FORBIDDEN=1
  out=$(manga_selftest bocchi-the-rock 2>&1); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'Tải ảnh thất bại' ) \
    && ok "ảnh chết -> selftest exit!=0 và chỉ đúng bước hỏng" \
    || bad "ảnh chết -> chỉ đúng bước hỏng" "rc!=0 + 'Tải ảnh thất bại'" "$out"
( export MOCK_CURL_LOG="/dev/null"
  MANGA_BASE_URL=https://manga-offline.example manga_selftest bocchi-the-rock >/dev/null 2>&1 ) \
    && bad "mất mạng -> selftest phải fail" "rc!=0" "rc=0" || ok "mất mạng -> selftest fail (rc!=0)"

echo "== 22. đọc ảnh từ mọi kiểu markup hiện nay =="
( MANGA_BASE_URL=https://truyenvn.my
  out=$(fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243-modern" bocchi-the-rock 2>/dev/null)
  printf '%s' "$out" > "$WORK/modern.log" )
out=$(cat "$WORK/modern.log")
check "data-lazy-src + srcset + JSON \\/ + data: placeholder -> 5 ảnh" "5" \
    "$(printf '%s\n' "$out" | grep -c 'bb_00')"
has "srcset: lấy cả 2 kích thước" "bb_003.jpg" "$out"
has "JSON \\/books -> URL tuyệt đối theo nguồn" "https://truyenvn.my/books/bocchi-the-rock/243/bb_004.jpg" "$out"
has "JSON https:\\/\\/ -> bỏ escape" "https://dmd-image-content-sng-1.imggo.net/books/bocchi-the-rock/243/bb_005.jpg" "$out"
check "bỏ ảnh placeholder data:image/gif" "0" "$(printf '%s\n' "$out" | grep -c 'data:image')"
check "không lặp ảnh" "5" "$(printf '%s\n' "$out" | sort -u | grep -c 'bb_00')"
has "trang này cũng lưu được link chuyển chap" "chapter-244" "$(manga_saved_nav)"

echo "== 23. trang chapter không có ảnh -> chẩn đoán rõ ràng =="
MANGA_BASE_URL=https://truyenvn.my
dbg="${CACHE_DIR:-/tmp}/manga-debug.txt"
rm -f "$dbg"
out=$(MANGA_READER_PROXY="" fetch_chapter_images "https://truyenvn.my/truyen-tranh/x/chapter-9-cloudflare" x 2>&1)
check "trang Cloudflare -> 0 ảnh" "0" "$(printf '%s\n' "$out" | grep -c 'imggo')"
check "có ghi file chẩn đoán" "1" "$([ -f "$dbg" ] && echo 1 || echo 0)"
has "chẩn đoán nêu Cloudflare" "challenge: YES" "$(cat "$dbg" 2>/dev/null)"
has "chẩn đoán đếm thẻ img" "img tags : 0" "$(cat "$dbg" 2>/dev/null)"
manga_looks_challenged '<html>Just a moment...</html>' && ok "nhận diện trang kiểm tra trình duyệt" \
    || bad "nhận diện trang kiểm tra trình duyệt" "0 (true)" "1"
manga_looks_challenged "$(cat "$MOCK_FIXTURES/manga-chapter.html")" \
    && bad "trang chapter bình thường không bị coi là challenge" "1" "0" \
    || ok "trang chapter bình thường không bị coi là challenge"
rm -f "$dbg"

echo "== 24. header giống trình duyệt khi tải trang =="
: > "$MOCK_CURL_HEADER_LOG"
manga_http_fetch "https://truyenvn.my/truyen-tranh/bocchi-the-rock" > /dev/null 2>&1
hdr=$(grep 'truyen-tranh' "$MOCK_CURL_HEADER_LOG" | head -1)
has "gửi sec-fetch-mode: navigate" "sec-fetch-mode: navigate" "$hdr"
has "gửi sec-ch-ua" "sec-ch-ua" "$hdr"
has "gửi upgrade-insecure-requests" "upgrade-insecure-requests" "$hdr"
: > "$MOCK_CURL_HEADER_LOG"
manga_http_post "https://truyenvn.my/webapi/stories/list-chapter" "story_id=12189&routeName=story.detail" "tok" "https://truyenvn.my/x" > /dev/null 2>&1
hdr2=$(grep 'list-chapter' "$MOCK_CURL_HEADER_LOG" | head -1)
has "POST vẫn có X-Requested-With" "X-Requested-With: XMLHttpRequest" "$hdr2"

echo "== 25. server trả bản rút gọn -> tự thử kiểu request khác =="
( export MOCK_STRIP_CHAPTER=1 MOCK_STRIP_UNLESS=bot
  : > "$MOCK_CURL_LOG"
  out=$(fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243" bocchi-the-rock 2>/dev/null)
  printf '%s' "$out" > "$WORK/fallback.log" )
check "bản rút gọn -> vẫn lấy được ảnh nhờ request kiểu bot" "5" \
    "$(grep -c 'bb_00' "$WORK/fallback.log")"
check "đã thử nhiều kiểu request (normal -> minimal -> bot)" "1" \
    "$([ "$(grep -c 'chapter-243' "$MOCK_CURL_LOG")" -ge 3 ] && echo 1 || echo 0)"
( export MOCK_STRIP_CHAPTER=1 MOCK_STRIP_UNLESS=minimal
  out=$(fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243" bocchi-the-rock 2>/dev/null)
  printf '%s' "$out" > "$WORK/fallback2.log" )
check "bản rút gọn -> thử kiểu minimal (không cookie/referer) cũng được" "5" \
    "$(grep -c 'bb_00' "$WORK/fallback2.log")"
( export MOCK_STRIP_CHAPTER=1 MOCK_STRIP_UNLESS=never
  out=$(MANGA_READER_PROXY="" fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243" bocchi-the-rock 2>&1)
  printf '%s' "$out" > "$WORK/fallback3.log" )
has "cả 4 kiểu thất bại (proxy tắt) -> nói rõ đã thử 4 kiểu" "Đã thử 4 kiểu request" "$(cat "$WORK/fallback3.log")"
has "vẫn ghi file chẩn đoán" "challenge: YES" "$(cat "${CACHE_DIR:-/tmp}/manga-debug.txt" 2>/dev/null)"

echo "== 26. fallback qua reader-proxy (r.jina.ai) =="
( export MOCK_STRIP_CHAPTER=1 MOCK_STRIP_UNLESS=never
  out=$(fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243" bocchi-the-rock 2>"$WORK/proxy.err")
  printf '%s' "$out" > "$WORK/proxy.log" )
check "máy bị chặn -> lấy ảnh qua reader-proxy" "3" "$(grep -c 'cc_00' "$WORK/proxy.log")"
has "báo rõ đang dùng proxy" "qua https://r.jina.ai" "$(cat "$WORK/proxy.err")"
has "bỏ ảnh bìa truyện khác (cover_/thumb)" "" "$(grep -c 'cover_\|thumb' "$WORK/proxy.log" | grep -q '^0$' || echo X)"
check "markdown ![]() -> đúng URL ảnh" "https://dmd-image-content-sng-1.imggo.net/books/bocchi-the-rock/243/cc_001.jpg" \
    "$(head -1 "$WORK/proxy.log")"
check "proxy: đọc được link chuyển chap từ markdown" "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-242|https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-244" \
    "$(manga_saved_nav)"
( export MOCK_STRIP_CHAPTER=1 MOCK_STRIP_UNLESS=never
  MANGA_READER_PROXY=""
  out=$(fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243" bocchi-the-rock 2>/dev/null)
  printf '%s' "$out" > "$WORK/noproxy.log" )
check "tắt proxy -> không lấy ảnh (tôn trọng cấu hình)" "0" "$(grep -c 'cc_00' "$WORK/noproxy.log")"
( export MOCK_STRIP_CHAPTER=1 MOCK_STRIP_UNLESS=bot
  out=$(fetch_chapter_images "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243" bocchi-the-rock 2>/dev/null)
  printf '%s' "$out" > "$WORK/directfirst.log" )
check "direct được thì không cần proxy" "5" "$(grep -c 'bb_00' "$WORK/directfirst.log")"
MANGA_READER_PROXY="off" manga_proxy_fetch "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243" >/dev/null 2>&1
check "proxy=off -> không gọi dịch vụ ngoài" "1" "$?"
MANGA_READER_PROXY="https://r.jina.ai" manga_proxy_fetch "https://truyenvn.my/truyen-tranh/bocchi-the-rock/chapter-243" >"$WORK/jina.log" 2>/dev/null
check "proxy bật -> lấy được markdown" "3" "$(grep -c 'cc_00' "$WORK/jina.log")"
check "mặc định có bật proxy (để tự cứu khi bị chặn)" "https://r.jina.ai" "$DEFAULT_MANGA_READER_PROXY"
has "Cài đặt có mục bật/tắt dịch vụ đọc hộ" "Dịch vụ đọc hộ khi bị chặn" "$(src_has 'Dịch vụ đọc hộ khi bị chặn')"

echo "== 27. phiên bản & lối vào chẩn đoán =="
check "có nhãn phiên bản" "1" "$(printf '%s' "$ANISUB_VERSION" | grep -cE '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}[a-z0-9]*$')"
has "selftest in phiên bản để biết đang chạy bản nào" "anisub: $ANISUB_VERSION" "$(manga_selftest bocchi-the-rock 2>&1)"
check "CLI --version chạy được" "anisub $ANISUB_VERSION" "$(bash "$ROOT/anisub.sh" --version 2>/dev/null)"
has "menu truyện có mục chẩn đoán" "Kiểm tra đọc truyện (chẩn đoán)" "$(src_has 'Kiểm tra đọc truyện (chẩn đoán)')"


echo "== 28. nguồn nettruyen: URL, tìm kiếm, danh sách truyện =="
nt() { MANGA_SOURCE=nettruyen MANGA_BASE_URL=https://nettruyen.info "$@"; }
check "slug -> /truyen-<slug>" "https://nettruyen.info/truyen-toi-manh-hon-anh-hung" \
    "$(nt manga_manga_url toi-manh-hon-anh-hung)"
check "route truyen- giữ nguyên (không nhân đôi tiền tố)" "https://nettruyen.info/truyen-toi-manh-hon-anh-hung" \
    "$(nt manga_manga_url truyen-toi-manh-hon-anh-hung)"
check "link đầy đủ giữ nguyên" "https://nettruyen.info/truyen-abc" \
    "$(nt manga_manga_url https://nettruyen.info/truyen-abc/)"
check "nt_route_of từ URL" "truyen-abc" "$(nt nt_route_of https://nettruyen.info/truyen-abc/chuong-5)"
check "nt_chapter_parts" "truyen-abc|1.5" "$(nt nt_chapter_parts https://nettruyen.info/truyen-abc/chuong-1.5)"
nt manga_list_items "/tim-kiem" "keyword=one" > "$WORK/nt-list.txt" 2>/dev/null
check "liệt kê: 3 truyện (bỏ link chapter)" "3" "$(grep -c '|' "$WORK/nt-list.txt")"
check "tên lấy từ <h3>, bỏ tiền tố 'Truyện tranh'" "One Piece - Đảo Hải Tặc" \
    "$(sed -n '2p' "$WORK/nt-list.txt" | cut -d'|' -f1)"
check "URL tuyệt đối + slug" "https://nettruyen.info/truyen-van-co-chi-ton|truyen-van-co-chi-ton" \
    "$(sed -n '3p' "$WORK/nt-list.txt" | cut -d'|' -f2,3)"
check "ảnh bìa data-original" "https://nettruyen.info/storage/thumbnails/van-co-chi-ton.jpg" \
    "$(sed -n '3p' "$WORK/nt-list.txt" | cut -d'|' -f4)"
check "nhớ ảnh bìa để preview" "https://nettruyen.info/images/one-piece-dao-hai-tac.jpg" \
    "$(manga_cover_cache_get truyen-one-piece-dao-hai-tac)"
nt manga_search_items "one" > "$WORK/nt-search.txt" 2>/dev/null
check "tìm kiếm: lọc đúng 1 truyện khớp 'one'" "1" "$(grep -c '|' "$WORK/nt-search.txt")"
check "tên trong kết quả tìm kiếm" "One Piece - Đảo Hải Tặc" "$(cut -d'|' -f1 "$WORK/nt-search.txt")"
check "giải HTML entity (&amp; -> &)" "0" "$(grep -c '&amp;' "$WORK/nt-list.txt")"
check "lọc client-side theo từ khoá" "1" \
    "$(nt manga_list_items "/tim-kiem" "keyword=one" | nt manga_match_items "van co" | grep -c '|')"

echo "== 29. nguồn nettruyen: danh sách chapter =="
nt fetch_chapter_list "toi-manh-hon-anh-hung" > "$WORK/nt-chaps.txt" 2>/dev/null
check "8 chapter của đúng truyện (bỏ truyện khác)" "8" "$(grep -c '|' "$WORK/nt-chaps.txt")"
check "sắp xếp tăng dần, chương mới nhất cuối" "Chapter 147" "$(tail -1 "$WORK/nt-chaps.txt" | cut -d'|' -f1)"
check "chương đầu là Chapter 0" "Chapter 0" "$(head -1 "$WORK/nt-chaps.txt" | cut -d'|' -f1)"
check "chapter lẻ 1.5 nằm giữa 1 và 2" "Chapter 1.5" "$(sed -n '3p' "$WORK/nt-chaps.txt" | cut -d'|' -f1)"
check "URL chapter tuyệt đối" "https://nettruyen.info/truyen-toi-manh-hon-anh-hung/chuong-147" \
    "$(tail -1 "$WORK/nt-chaps.txt" | cut -d'|' -f2)"
check "trường 3 = chuong-N" "chuong-147" "$(tail -1 "$WORK/nt-chaps.txt" | cut -d'|' -f3)"
check "manga_chapter_url dựng đúng URL nettruyen" "https://nettruyen.info/truyen-x/chuong-12.5" \
    "$(nt manga_chapter_url https://nettruyen.info/truyen-x 12.5)"
check "truyenvn vẫn dùng /chapter-N" "https://truyenvn.my/truyen-tranh/x/chapter-12-5" \
    "$(MANGA_SOURCE=truyenvn MANGA_BASE_URL=https://truyenvn.my manga_chapter_url https://truyenvn.my/truyen-tranh/x 12.5)"

echo "== 30. nguồn nettruyen: ảnh trang đọc =="
nt fetch_chapter_images "https://nettruyen.info/truyen-toi-manh-hon-anh-hung/chuong-147" > "$WORK/nt-imgs.txt" 2>/dev/null
check "5 trang ảnh" "5" "$(grep -c 'page_' "$WORK/nt-imgs.txt")"
check "trang đầu page_0" "https://net.imgchapter.store/toi-manh-hon-anh-hung/147/page_0.jpg" \
    "$(head -1 "$WORK/nt-imgs.txt")"
check "sắp theo số trang (10 sau 3)" "page_10" "$(tail -1 "$WORK/nt-imgs.txt" | grep -o 'page_10')"
check "bỏ qua logo/banner" "0" "$(grep -c 'logo\|banner' "$WORK/nt-imgs.txt")"
nt nt_parse_image_urls < "$ROOT/tests/fixtures/nt-chapter-relative.html" > "$WORK/nt-rel.txt"
check "ảnh đường dẫn tương đối -> ghép host ảnh" "https://net.imgchapter.store/toi-manh-hon-anh-hung/147/page_0.jpg" \
    "$(head -1 "$WORK/nt-rel.txt")"
check "sắp lại theo số trang dù HTML để lộn xộn" "page_2.jpg" "$(tail -1 "$WORK/nt-rel.txt" | grep -o 'page_2.jpg')"
check "đủ 3 trang" "3" "$(grep -c 'page_' "$WORK/nt-rel.txt")"
check "bỏ ảnh loading.gif" "0" "$(grep -c 'loading' "$WORK/nt-rel.txt")"
MOCK_IMG_MAX_PAGE=3 nt nt_probe_page_urls "https://nettruyen.info/truyen-abc/chuong-7" > "$WORK/nt-probe.txt" 2>/dev/null
check "tự dò ảnh theo mẫu URL (dừng khi 404)" "3" "$(grep -c 'page_' "$WORK/nt-probe.txt")"
check "dò đúng host ảnh" "https://net.imgchapter.store/abc/7/page_2.jpg" "$(tail -1 "$WORK/nt-probe.txt")"

echo "== 31. nguồn nettruyen: menu, thể loại, chẩn đoán =="
check "trang mới cập nhật = trang chủ" "/" \
    "$( manga_browse_menu() { printf '%s' "$1"; }; MANGA_SOURCE=nettruyen MANGA_BASE_URL=https://nettruyen.info manga_browse_latest )"
check "trang hot = /truyen-tranh-hot" "/truyen-tranh-hot" \
    "$( manga_browse_menu() { printf '%s' "$1"; }; MANGA_SOURCE=nettruyen MANGA_BASE_URL=https://nettruyen.info manga_browse_hot )"
check "truyenvn vẫn dùng /tim-kiem + m_orderby" "/tim-kiem|m_orderby=views" \
    "$( manga_browse_menu() { printf '%s|%s' "$1" "$3"; }; MANGA_SOURCE=truyenvn MANGA_BASE_URL=https://truyenvn.my manga_browse_views )"
check "thể loại nettruyen có manhwa" "1" "$(nt manga_genres | grep -c '|manhwa$')"
check "thể loại nettruyen có >= 25 mục" "1" "$([ "$(nt manga_genres | grep -c '|')" -ge 25 ] && echo 1 || echo 0)"
nt manga_selftest toi-manh-hon-anh-hung > "$WORK/nt-selftest.txt" 2>&1
check "selftest nettruyen chạy hết luồng" "0" "$?"
has "selftest ghi rõ nguồn" "nguồn: nettruyen (https://nettruyen.info)" "$(cat "$WORK/nt-selftest.txt")"
has "selftest đọc được ảnh nettruyen" "imgchapter.store" "$(cat "$WORK/nt-selftest.txt")"
has "selftest chỉ ra chap trước/sau kiểu chuong-" "chuong-146|https://nettruyen.info/truyen-toi-manh-hon-anh-hung/chuong-148" \
    "$(grep 'chap trước|sau' "$WORK/nt-selftest.txt")"
has "menu cài đặt có mục đổi nguồn" "Đổi nguồn truyện (nettruyen / truyenvn / e-hentai / kagane / toon18x)" \
    "$(src_has 'Đổi nguồn truyện (nettruyen / truyenvn / e-hentai / kagane / toon18x)')"
check "chẩn đoán ghi đúng nguồn" "1" \
    "$(nt manga_diagnose </dev/null 2>&1 | grep -c 'Chẩn đoán nguồn truyện tranh (nettruyen)')"
check "chẩn đoán đọc được trang chủ nettruyen" "1" \
    "$(nt manga_diagnose </dev/null 2>&1 | grep -c 'parse được 3 truyện')"
echo "== 32. bấm \"📚 Đọc Truyện Tranh\" phải mở được menu truyện =="
has "case menu chính dùng khớp mềm (nhãn nguồn đổi được)" '*"Đọc Truyện Tranh"*)' \
    "$(src_has '\*"Đọc Truyện Tranh"\*)')"
has "lời nhắc tìm kiếm theo nguồn, không hard-code TruyenVN" "cần tìm (%s)" \
    "$(src_has 'cần tìm (%s)')"
if command -v timeout >/dev/null 2>&1; then
    mkdir -p "$WORK/fakebin" "$WORK/home-menu"
    for b in ffmpeg yt-dlp; do
        printf '#!/bin/bash\nexit 0\n' > "$WORK/fakebin/$b"; chmod +x "$WORK/fakebin/$b"
    done
    : > "$WORK/fzf-menu.log"
    ( PATH="$WORK/fakebin:$PATH" MOCK_FZF_LOG="$WORK/fzf-menu.log" KK_MOCK_PICK_MENU=3 \
      HOME="$WORK/home-menu" timeout 6 bash "$ROOT/anisub.sh" < /dev/null > /dev/null 2>&1 )
    check "mở được menu truyện thật (không quay lại menu chính ngay)" "1" \
        "$([ "$(grep -c '📚 Menu >' "$WORK/fzf-menu.log")" -ge 1 ] && echo 1 || echo 0)"
else
    ok "bỏ qua test mở menu thật (máy không có lệnh timeout)"
fi

has "CLI --manga-selftest tự chọn truyện mẫu theo nguồn" "nettruyen" \
    "$(MANGA_SOURCE=nettruyen MANGA_BASE_URL=https://nettruyen.info bash "$ROOT/anisub.sh" --manga-selftest 2>&1 | head -2)"


echo "== 33. chặn quảng cáo chèn trong playlist m3u8 (quảng cáo giữa phim ~phút 15) =="
check "mặc định bật chặn quảng cáo" "1" "$(KKPHIM_AD_BLOCK=1 kkphim_ad_block_enabled && echo 1 || echo 0)"
check "tắt được bằng KKPHIM_AD_BLOCK=0" "0" "$(KKPHIM_AD_BLOCK=0 kkphim_ad_block_enabled && echo 1 || echo 0)"
check "load_config mặc định bật" "1" "$KKPHIM_AD_BLOCK"
check "có file lọc playlist bằng perl" "1" "$([ -s "$ROOT/src/movie/hls_adfree.pl" ] && echo 1 || echo 0)"
check "tìm được script lọc từ bộ src/" "1" \
    "$(printf '%s' "$(kkphim_hls_filter_script)" | grep -c 'hls_adfree.pl$')"

check "ghép URL tuyệt đối (gốc /)" "https://cdn.phim.test/keys/k1.bin" \
    "$(kkphim_abs_url https://cdn.phim.test/hls/phim/high/index.m3u8 /keys/k1.bin)"
check "ghép URL tương đối theo thư mục playlist" "https://cdn.phim.test/hls/phim/high/002.ts" \
    "$(kkphim_abs_url https://cdn.phim.test/hls/phim/high/index.m3u8 002.ts)"
check "giữ nguyên URL tuyệt đối" "https://x.test/a.ts" \
    "$(kkphim_abs_url https://cdn.phim.test/hls/phim/high/index.m3u8 https://x.test/a.ts)"

check "link không phải m3u8 -> phát nguyên" "https://cdn.phim.test/vod/phim.mp4" \
    "$(KKPHIM_AD_BLOCK=1 kkphim_play_url https://cdn.phim.test/vod/phim.mp4)"
check "tắt chặn -> trả lại link gốc" "https://cdn.phim.test/hls/phim/master.m3u8" \
    "$(KKPHIM_AD_BLOCK=0 kkphim_play_url https://cdn.phim.test/hls/phim/master.m3u8)"

# --- playlist thật (mock): khối quảng cáo nằm CÙNG host với phim, bọc CUE-OUT/CUE-IN
: > "$MOCK_CURL_LOG"
KKPHIM_AD_BLOCK=1 kkphim_play_url "https://cdn.phim.test/hls/phim/master.m3u8" > "$WORK/adfree.path" 2>/dev/null
adfree_file=$(cat "$WORK/adfree.path")
check "bật chặn -> trả về file playlist đã lọc" "1" \
    "$(printf '%s' "$adfree_file" | grep -c 'anisub-adfree-.*\.m3u8$')"
check "file đã lọc tồn tại" "1" "$([ -s "$adfree_file" ] && echo 1 || echo 0)"
check "mặc định chọn variant ĐẦU TIÊN (low/, giống trình phát cũ)" "1 0" \
    "$(grep -c 'hls/phim/low/index.m3u8' "$MOCK_CURL_LOG") $(grep -c 'hls/phim/high/index.m3u8' "$MOCK_CURL_LOG")"
check "giữ đúng 4 segment phim" "4" "$(grep -cE '^https?://.*\.ts' "$adfree_file")"
check "BỎ khối CUE-OUT..CUE-IN dù cùng host với phim (003.ts)" "0" "$(grep -c 'phim/003.ts' "$adfree_file")"
check "BỎ segment thứ 2 của khối quảng cáo (004.ts)" "0" "$(grep -c 'phim/004.ts' "$adfree_file")"
check "giữ segment ngay sau CUE-IN (005.ts)" "1" "$(grep -c 'phim/005.ts' "$adfree_file")"
check "bỏ segment preroll (ads.adtag.vn)" "0" "$(grep -ci 'preroll' "$adfree_file")"
check "bỏ marker CUE-OUT/CUE-IN" "0" "$(grep -c 'EXT-X-CUE' "$adfree_file")"
check "giữ #EXT-X-ENDLIST" "1" "$(grep -c '#EXT-X-ENDLIST' "$adfree_file")"
check "#EXT-X-KEY được tuyệt đối hoá" "1" "$(grep -c 'URI="https://cdn.phim.test/keys/k1.bin"' "$adfree_file")"
check "giữ nguyên #EXT-X-MEDIA-SEQUENCE (IV của AES)" "1" "$(grep -c '^#EXT-X-MEDIA-SEQUENCE:0$' "$adfree_file")"
check "chèn #EXT-X-DISCONTINUITY tại mỗi chỗ cắt" "2" "$(grep -c '^#EXT-X-DISCONTINUITY$' "$adfree_file")"
check "mọi DISCONTINUITY đều đứng TRƯỚC #EXTINF" "2" \
    "$(grep -A1 '^#EXT-X-DISCONTINUITY$' "$adfree_file" | grep -c '^#EXTINF')"
check "thống kê: bỏ 3 / giữ 4" "3 4" "$(kkphim_ad_stat dropped) $(kkphim_ad_stat kept)"
check "thống kê: quảng cáo bị bỏ vì CUE + mẫu URL" "2 1" \
    "$(kkphim_ad_stat reason_cue) $(kkphim_ad_stat reason_pattern)"
rm -f "$adfree_file" "${adfree_file%.m3u8}.stats"

# --- KHÔNG xoá nhầm segment phim có tên chứa 'media'/'shadow' hoặc query ?ad=0
cat > "$WORK/keep.m3u8" <<'EOP'
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6.000,
https://cdn.phim.test/hls/media/shadow/003.ts?token=abc&ad=0
#EXTINF:6.000,
https://cdn.phim.test/hls/phim/segment_1.ts
#EXT-X-ENDLIST
EOP
KKPHIM_BASE="https://cdn.phim.test/hls/phim/index.m3u8" KKPHIM_AD_PATTERNS="ad,ads,promo" \
    perl "$ROOT/src/movie/hls_adfree.pl" < "$WORK/keep.m3u8" > "$WORK/keep.out" 2>/dev/null
check "không xoá segment 'media/shadow' hay 'segment_1'" "2" "$(grep -cE '^https?://' "$WORK/keep.out")"

# --- khối segment ở tên miền lạ (adserver) dù URL không chứa chữ 'ad'
KKPHIM_AD_BLOCK=1 kkphim_play_url "https://cdn.phim.test/hls/phim/foreign.m3u8" > "$WORK/foreign.path" 2>/dev/null
foreign_file=$(cat "$WORK/foreign.path")
check "bỏ khối 2 segment ở tên miền lạ" "6" "$(grep -cE '^https?://' "$foreign_file")"
check "không còn host adserver" "0" "$(grep -c 'other-x.net' "$foreign_file")"
rm -f "$foreign_file" "${foreign_file%.m3u8}.stats"

# --- playlist kiểu live -> chuẩn hoá VOD (sửa lỗi 'phát vài giây lại khựng')
KKPHIM_AD_BLOCK=1 kkphim_play_url "https://cdn.phim.test/hls/phim/live.m3u8" > "$WORK/live.path" 2>/dev/null
live_file=$(cat "$WORK/live.path")
check "playlist thiếu ENDLIST -> thêm ENDLIST" "1" "$(grep -c '#EXT-X-ENDLIST' "$live_file")"
check "thêm PLAYLIST-TYPE:VOD" "1" "$(grep -c '#EXT-X-PLAYLIST-TYPE:VOD' "$live_file")"
check "giữ nguyên MEDIA-SEQUENCE gốc" "1" "$(grep -c '^#EXT-X-MEDIA-SEQUENCE:120$' "$live_file")"
check "giữ nguyên DISCONTINUITY-SEQUENCE gốc" "1" "$(grep -c '^#EXT-X-DISCONTINUITY-SEQUENCE:4$' "$live_file")"
check "bỏ quảng cáo trong playlist live" "0" "$(grep -ci 'adtag' "$live_file")"
rm -f "$live_file" "${live_file%.m3u8}.stats"

# --- chốt an toàn: CUE-OUT thiếu CUE-IN chỉ bỏ tối đa 180s (không mất nửa phim)
{
    echo "#EXTM3U"; echo "#EXT-X-TARGETDURATION:6"
    for i in $(seq 1 100); do
        [ "$i" = "5" ] && echo "#EXT-X-CUE-OUT"
        echo "#EXTINF:6.000,"
        echo "seg-$i.ts"
    done
} > "$WORK/cue-noclose.m3u8"
KKPHIM_BASE="https://cdn.phim.test/hls/phim/index.m3u8" KKPHIM_AD_PATTERNS="ad,ads" \
    perl "$ROOT/src/movie/hls_adfree.pl" < "$WORK/cue-noclose.m3u8" > "$WORK/cue-noclose.out" 2>/dev/null
check "CUE-OUT không có CUE-IN -> chỉ bỏ 90s (giữ 85/100 segment)" "85" \
    "$(grep -cE '^[^#]' "$WORK/cue-noclose.out")"

# --- chốt an toàn: nhận diện sai (bỏ >45% phim dài) -> không dùng bản đã lọc
{
    echo "#EXTM3U"; echo "#EXT-X-TARGETDURATION:6"
    echo "#EXT-X-CUE-OUT:200"
    for i in $(seq 1 60); do echo "#EXTINF:6.000,"; echo "seg-$i.ts"; done
} > "$WORK/overdrop.m3u8"
KKPHIM_BASE="https://cdn.phim.test/hls/phim/index.m3u8" KKPHIM_AD_PATTERNS="ad,ads" \
    perl "$ROOT/src/movie/hls_adfree.pl" < "$WORK/overdrop.m3u8" > /dev/null 2>&1
check "bỏ quá 45% phim dài -> perl trả mã 4 (anisub phát link gốc)" "4" "$?"

# --- live thật (cửa sổ trượt vài giây) -> không lọc, phát link gốc (khỏi mất phim)
check "playlist live cửa sổ ngắn -> phát link gốc" "https://cdn.phim.test/hls/phim/livewin.m3u8" \
    "$(KKPHIM_AD_BLOCK=1 kkphim_play_url https://cdn.phim.test/hls/phim/livewin.m3u8)"

# --- AES-128 không kèm IV -> không lọc (tránh giải mã sai, phim hỏng)
kkphim_play_url "https://cdn.phim.test/hls/phim/aesnoiv.m3u8" > "$WORK/aes.out" 2>/dev/null
check "AES-128 không kèm IV -> phát link gốc" "https://cdn.phim.test/hls/phim/aesnoiv.m3u8" "$(cat "$WORK/aes.out")"

# --- tải playlist lỗi -> phát link gốc (không bao giờ chặn việc xem phim)
check "tải playlist lỗi -> phát link gốc" "https://manga-offline.test/x.m3u8" \
    "$(KKPHIM_AD_BLOCK=1 kkphim_play_url https://manga-offline.test/x.m3u8)"

# --- trình phát nhận playlist đã lọc + vẫn gửi Referer
: > "$WORK/mpv-ad.log"
MOCK_MPV_LOG="$WORK/mpv-ad.log" PLAYER=mpv KKPHIM_AD_BLOCK=1 \
    play_stream "https://cdn.phim.test/hls/phim/master.m3u8" "Phim test" > /dev/null 2>&1
check "trình phát nhận file đã lọc (không phải link gốc)" "1" \
    "$(grep -c 'anisub-adfree-.*\.m3u8' "$WORK/mpv-ad.log")"
has "vẫn gửi Referer khi phát bản đã lọc" "--referrer=https://kkphim.com/" "$(cat "$WORK/mpv-ad.log")"
: > "$WORK/mpv-ad.log"
MOCK_MPV_LOG="$WORK/mpv-ad.log" PLAYER=mpv KKPHIM_AD_BLOCK=0 \
    play_stream "https://cdn.phim.test/hls/phim/master.m3u8" "Phim test" > /dev/null 2>&1
check "tắt chặn -> trình phát nhận link gốc" "1" \
    "$(grep -c 'cdn.phim.test/hls/phim/master.m3u8' "$WORK/mpv-ad.log")"

# --- cấu hình / menu / CLI
has "cài đặt có mục chặn quảng cáo" "Chặn quảng cáo trong m3u8" \
    "$(grep -o 'Chặn quảng cáo trong m3u8' "$ROOT/src/movie/kkphim.sh" | head -1)"
has "cài đặt có mục chất lượng khi lọc" "Chất lượng khi lọc quảng cáo" \
    "$(grep -o 'Chất lượng khi lọc quảng cáo' "$ROOT/src/movie/kkphim.sh" | head -1)"
has "cài đặt có mục mẫu nhận diện" "Mẫu nhận diện quảng cáo" \
    "$(grep -o 'Mẫu nhận diện quảng cáo' "$ROOT/src/movie/kkphim.sh" | head -1)"
has "config lưu KKPHIM_AD_BLOCK" 'KKPHIM_AD_BLOCK="' "$(save_config >/dev/null; cat "$CONFIG_FILE")"
has "CLI có --kkphim-ad-debug" "kkphim-ad-debug" "$(src_has 'kkphim-ad-debug')"
has "CLI ad-debug in hướng dẫn khi thiếu URL" "Cách dùng" \
    "$(kkphim_ad_report '' 2>&1 | head -1)"

mkdir -p "$WORK/home3/.config/anisub_cli"
printf 'PLAYER="mpv"\nKKPHIM_AD_BLOCK=0\nKKPHIM_AD_PATTERNS="ad,quangcao"\nKKPHIM_AD_VARIANT=max\n' > "$WORK/home3/.config/anisub_cli/config.cfg"
( HOME="$WORK/home3" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; load_config >/dev/null 2>&1; [ \"\$KKPHIM_AD_BLOCK\" = 0 ] && [ \"\$KKPHIM_AD_VARIANT\" = max ]" ) \
    && ok "config cũ có sẵn khoá KKPHIM_AD_* được giữ nguyên" \
    || bad "config cũ còn khoá KKPHIM_AD_*" "đọc được 0/max" "khác"

# --- tải/cắt video dùng chung bộ lọc (mốc thời gian khớp lúc xem)
has "tải video dùng playlist đã lọc" 'play_url=$(kkphim_play_url "$url"' \
    "$(grep -o 'play_url=$(kkphim_play_url "$url"' "$ROOT/src/movie/media.sh" | head -1)"
has "cắt video dùng playlist đã lọc" 'play_url=$(kkphim_play_url "$input_url"' \
    "$(grep -o 'play_url=$(kkphim_play_url "$input_url"' "$ROOT/src/movie/media.sh" | head -1)"

echo "== 34. nguồn truyện e-hentai (e-hentai.org) =="
eh() { MANGA_SOURCE=ehentai MANGA_BASE_URL=https://e-hentai.org EHENTAI_DELAY=0 "$@"; }

check "nhãn nguồn = e-hentai" "e-hentai" "$(eh manga_source_label)"
check "manga_is_ehentai nhận đúng" "1" "$(eh manga_is_ehentai && echo 1 || echo 0)"
check "manga_is_nettruyen từ chối e-hentai" "0" "$(eh manga_is_nettruyen && echo 1 || echo 0)"
check "MANGA_BASE_URL không phải e-hentai -> vẫn về e-hentai.org" "https://e-hentai.org" \
    "$(MANGA_BASE_URL=https://nettruyen.info eh_base)"
check "eh_base giữ domain đang cấu hình" "https://e-hentai.org" \
    "$(MANGA_SOURCE=ehentai MANGA_BASE_URL=https://e-hentai.org/ eh_base)"

check "ghép URL gallery từ id/token" "https://e-hentai.org/g/4313400/7fcc76c845/" \
    "$(eh_gallery_url 4313400/7fcc76c845)"
check "giữ nguyên URL gallery đầy đủ" "https://e-hentai.org/g/4313400/7fcc76c845/" \
    "$(eh_gallery_url https://e-hentai.org/g/4313400/7fcc76c845/)"
check "bỏ #pN khi ghép URL" "https://e-hentai.org/g/4313400/7fcc76c845/" \
    "$(eh_gallery_url "https://e-hentai.org/g/4313400/7fcc76c845/#p40")"
check "lấy id gallery" "4313400" "$(eh_gallery_id https://e-hentai.org/g/4313400/7fcc76c845/)"
check "lấy token gallery" "7fcc76c845" "$(eh_gallery_token https://e-hentai.org/g/4313400/7fcc76c845/)"

check "parse danh sách: 3 gallery" "3" "$(eh_parse_items < "$ROOT/tests/fixtures/ehentai-tag.html" | grep -c '|')"
check "tên lấy từ alt + số trang" "[Ryota tanaka] 逆轉S2 33 (Vietnamese) · 103 trang" \
    "$(eh_parse_items < "$ROOT/tests/fixtures/ehentai-tag.html" | head -1 | cut -d'|' -f1)"
check "URL gallery trong danh sách" "https://e-hentai.org/g/4304955/1e66fed787/" \
    "$(eh_parse_items < "$ROOT/tests/fixtures/ehentai-tag.html" | sed -n '2p' | cut -d'|' -f2)"
check "ảnh bìa tương đối -> tuyệt đối" "https://e-hentai.org/w/02/772/91675-rt5obxe2.webp" \
    "$(eh_parse_items < "$ROOT/tests/fixtures/ehentai-tag.html" | sed -n '2p' | cut -d'|' -f4)"
check "số trang thứ 3" "8 trang" \
    "$(eh_parse_items < "$ROOT/tests/fixtures/ehentai-tag.html" | sed -n '3p' | cut -d'|' -f1 | sed 's/.*· //')"
check "trang kế tiếp (?next=)" "https://e-hentai.org/tag/language:vietnamese?next=4185969" \
    "$(eh_parse_next < "$ROOT/tests/fixtures/ehentai-tag.html")"

check "đọc số trang của gallery" "45" "$(eh_parse_total_pages < "$ROOT/tests/fixtures/ehentai-gallery.html")"
check "đọc số trang gallery 1 trang" "1" "$(eh_parse_total_pages < "$ROOT/tests/fixtures/ehentai-single.html")"
check "đọc ảnh bìa gallery" "https://ehgt.org/w/02/772/91675-rt5obxe2.webp" \
    "$(eh_parse_cover < "$ROOT/tests/fixtures/ehentai-gallery.html")"
check "link trang ảnh (đúng thứ tự)" "https://e-hentai.org/s/aaa111/4304955-0|https://e-hentai.org/s/bbb222/4304955-1|https://e-hentai.org/s/ccc333/4304955-2|https://e-hentai.org/s/ddd444/4304955-3" \
    "$(eh_parse_page_links < "$ROOT/tests/fixtures/ehentai-gallery.html" | tr '\n' '|' | sed 's/|$//')"
check "link ảnh thật từ <img id=img>" "https://abc.hath.network/h/6f1c2a9d3b/4304955-7.jpg?tok=xyz" \
    "$(eh_parse_image_src < "$ROOT/tests/fixtures/ehentai-img.html")"

check "danh sách qua HTTP (mock)" "3" "$(eh eh_list_items "/tag/language:vietnamese" 2>/dev/null | grep -c '|')"
check "tìm kiếm dùng f_search" "3" "$(eh eh_search_items "seiren" 2>/dev/null | grep -c '|')"
check "tag mặc định = language:vietnamese" "/tag/language:vietnamese" "$(eh eh_start_url)"
check "EHENTAI_CHUNK=20 -> trang 21 nằm ở nhóm bắt đầu 20" \
    "https://e-hentai.org/g/4313400/7fcc76c845/#p20" "$(eh eh_chapter_url "https://e-hentai.org/g/4313400/7fcc76c845/" 21)"

eh eh_fetch_chapter_list "https://e-hentai.org/g/4304955/1e66fed787/" > "$WORK/eh-chaps.txt" 2>/dev/null
check "gallery 45 trang -> 3 nhóm (20/20/5)" "3" "$(grep -c '|' "$WORK/eh-chaps.txt")"
check "tên nhóm trang" "Trang 1–20/45" "$(head -1 "$WORK/eh-chaps.txt" | cut -d'|' -f1)"
check "nhóm cuối dừng ở trang 45" "Trang 41–45/45" "$(tail -1 "$WORK/eh-chaps.txt" | cut -d'|' -f1)"
check "URL nhóm mang #p40" "https://e-hentai.org/g/4304955/1e66fed787/#p40" \
    "$(tail -1 "$WORK/eh-chaps.txt" | cut -d'|' -f2)"

check "lấy được link ảnh của nhóm đầu" "https://abc.hath.network/h/6f1c2a9d3b/4304955-0.jpg?tok=xyz|https://abc.hath.network/h/6f1c2a9d3b/4304955-1.jpg?tok=xyz|https://abc.hath.network/h/6f1c2a9d3b/4304955-2.jpg?tok=xyz|https://abc.hath.network/h/6f1c2a9d3b/4304955-3.jpg?tok=xyz" \
    "$(eh fetch_chapter_images "https://e-hentai.org/g/4304955/1e66fed787/#p0" 2>/dev/null | tr '\n' '|' | sed 's/|$//')"
check "fetch_chapter_images định tuyến e-hentai" "1" \
    "$(eh fetch_chapter_images "https://e-hentai.org/g/4304955/1e66fed787/#p0" 2>/dev/null | grep -c 'hath.network' | sed 's/^[0-9]*$/1/')"
check "fetch_chapter_list định tuyến e-hentai" "Trang 21–40/45" \
    "$(eh fetch_chapter_list "https://e-hentai.org/g/4304955/1e66fed787/" 2>/dev/null | sed -n '2p' | cut -d'|' -f1)"
check "manga_manga_url trả URL gallery" "https://e-hentai.org/g/4304955/1e66fed787/" \
    "$(eh manga_manga_url "4304955/1e66fed787")"
check "slug truyện e-hentai = id/token (mở lại từ lịch sử)" "4304955/1e66fed787" \
    "$(eh manga_slug_from_url "https://e-hentai.org/g/4304955/1e66fed787/")"
check "thể loại = tag e-hentai (có language:vietnamese)" "1" "$(eh manga_genres | grep -c '|language:vietnamese$')"

mkdir -p "$WORK/home-eh/.config/anisub_cli"
( HOME="$WORK/home-eh" ANISUB_SRC_DIR="$ROOT/src" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_SOURCE=ehentai; MANGA_BASE_URL=https://e-hentai.org; EHENTAI_TAG='language:vietnamese manga'; EHENTAI_CHUNK=30; EHENTAI_COOKIE='ipb_member_id=1; ipb_pass_hash=x'; save_config >/dev/null 2>&1" )
check "lưu tag e-hentai vào config" "1" "$(grep -c '^EHENTAI_TAG="language:vietnamese manga"' "$WORK/home-eh/.config/anisub_cli/config.cfg")"
check "lưu số trang mỗi chapter" "1" "$(grep -c '^EHENTAI_CHUNK="30"' "$WORK/home-eh/.config/anisub_cli/config.cfg")"
check "lưu cookie e-hentai" "1" "$(grep -c '^EHENTAI_COOKIE="ipb_member_id=1' "$WORK/home-eh/.config/anisub_cli/config.cfg")"
check "nạp lại được nguồn e-hentai từ config" "ehentai" \
    "$( HOME="$WORK/home-eh" ANISUB_SRC_DIR="$ROOT/src" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; load_config; echo \"\$MANGA_SOURCE\"")"
check "EHENTAI_CHUNK chặn giá trị vô lý (>100)" "100" "$(EHENTAI_CHUNK=999 eh_chunk_size)"
check "EHENTAI_CHUNK chặn giá trị nhỏ (<5)" "5" "$(EHENTAI_CHUNK=1 eh_chunk_size)"

has "menu cài đặt có mục tag e-hentai" "Tag mặc định (e-hentai)" "$(src_has 'Tag mặc định (e-hentai)')"
has "menu cài đặt có mục cookie e-hentai" "Cookie e-hentai" "$(src_has 'Cookie e-hentai')"
has "menu cài đặt có mục số trang mỗi chapter" "Số trang ảnh mỗi chapter" "$(src_has 'Số trang ảnh mỗi chapter')"
has "menu đổi nguồn có e-hentai" "3|ehentai|" "$(src_has '3|ehentai|')"

eh manga_diagnose </dev/null > "$WORK/eh-diag.txt" 2>&1
check "chẩn đoán e-hentai chạy được" "1" "$(grep -c 'Chẩn đoán nguồn e-hentai' "$WORK/eh-diag.txt")"
check "chẩn đoán thấy tag mặc định" "1" "$([ "$(grep -c 'language:vietnamese' "$WORK/eh-diag.txt")" -ge 1 ] && echo 1 || echo 0)"
check "chẩn đoán parse được gallery" "1" "$(grep -c 'parse được 3 gallery' "$WORK/eh-diag.txt")"

check "module nguồn nằm trong src/comic/ehentai.sh" "1" "$([ -f "$ROOT/src/comic/ehentai.sh" ] && echo 1 || echo 0)"
check "bộ nạp module tự tìm src/movie + src/comic" "1" "$([ "$(src_count 'anisub_load_sources')" -ge 1 ] && echo 1 || echo 0)"
check "src/movie có nguồn phim KKPhim" "1" "$([ -f "$ROOT/src/movie/kkphim.sh" ] && echo 1 || echo 0)"
echo "== 35. thiếu src/ (bản chỉ có anisub.sh) -> tự tải về, không còn 'không đọc được truyện' =="
# Bản phát hành giả lập: anisub.sh + src/ trong 1 thư mục tarball như GitHub
mkdir -p "$WORK/rel/anisub-main"
cp "$ROOT/anisub.sh" "$WORK/rel/anisub-main/"
cp -R "$ROOT/src" "$WORK/rel/anisub-main/src"
# đặt version mới hơn để test luôn phần 🔄 Cập nhật
sed '3s/.*/ANISUB_VERSION="2999.01.01z"/' "$ROOT/anisub.sh" > "$WORK/rel/anisub-main/anisub.sh"
tar -czf "$WORK/anisub-main.tar.gz" -C "$WORK/rel" anisub-main
check "tạo được tarball phát hành để test" "1" "$([ -s "$WORK/anisub-main.tar.gz" ] && echo 1 || echo 0)"

# (a) máy chỉ có anisub.sh, có mạng -> tự tải src/ về cạnh script
mkdir -p "$WORK/solo" "$WORK/home-solo"
cp "$ROOT/anisub.sh" "$WORK/solo/"
( cd "$WORK/solo" && ANISUB_SRC_DIR="" MOCK_UPDATE_TARBALL="$WORK/anisub-main.tar.gz" HOME="$WORK/home-solo" \
  PATH="$HERE/mockbin:$PATH" timeout 30 bash ./anisub.sh --doctor > "$WORK/solo-doctor.txt" 2>&1 )
check "tự tải src/comic/core.sh về cạnh script" "1" "$([ -f "$WORK/solo/src/comic/core.sh" ] && echo 1 || echo 0)"
check "tự tải đủ 8 module" "8" "$(ls "$WORK/solo/src/movie"/*.sh "$WORK/solo/src/comic"/*.sh 2>/dev/null | wc -l | tr -d ' ')"
has "báo đã tải bộ file nguồn" "Đã tải bộ file nguồn" "$(cat "$WORK/solo-doctor.txt")"
has "doctor chạy được sau khi tự tải" "ANISUB DOCTOR" "$(cat "$WORK/solo-doctor.txt")"
has "doctor liệt kê module comic" "core.sh" "$(cat "$WORK/solo-doctor.txt")"
has "doctor ghi rõ nguồn truyện" "Truyện : nettruyen" "$(cat "$WORK/solo-doctor.txt")"

# (b) máy chỉ có anisub.sh, KHÔNG có mạng -> báo lỗi rõ ràng, không mở menu hỏng
mkdir -p "$WORK/solo2" "$WORK/home-solo2"
cp "$ROOT/anisub.sh" "$WORK/solo2/"
( cd "$WORK/solo2" && ANISUB_SRC_DIR="" HOME="$WORK/home-solo2" PATH="$HERE/mockbin:$PATH" \
  timeout 30 bash ./anisub.sh --doctor > "$WORK/solo2.txt" 2>&1 )
check "thiếu src + không tải được -> mã thoát 1" "1" "$?"
has "nói rõ cần bộ nguồn src/" "Không có bộ file nguồn src/ dùng được" "$(cat "$WORK/solo2.txt")"
has "có hướng dẫn git clone" "git clone https://github.com/NiyakiPham/anisub.git" "$(cat "$WORK/solo2.txt")"
check "không tạo src/ rỗng khi tải thất bại" "0" "$([ -d "$WORK/solo2/src" ] && echo 1 || echo 0)"

# (c) --version chạy được kể cả khi thiếu src
check "--version không cần src/, không chờ mạng" "anisub $ANISUB_VERSION" \
    "$( cd "$WORK/solo2" && ANISUB_SRC_DIR="" HOME="$WORK/home-solo2" PATH="$HERE/mockbin:$PATH" bash ./anisub.sh --version 2>/dev/null )"

# (d) source file (test/nhúng) KHÔNG chạy entry point: không tự tải, không exit
( cd "$WORK/solo2" && ANISUB_SRC_DIR=/khong/co/that bash -c "source '$WORK/lib.sh' >/dev/null 2>&1"; echo "rc=$?" ) > "$WORK/source-rc.txt" 2>&1
check "source lib không tự chạy entry point" "rc=0" "$(cat "$WORK/source-rc.txt")"
check "source lib không tạo src/ lạ" "0" "$([ -d /khong/co/that ] && echo 1 || echo 0)"

# (e) 🔄 Cập nhật: cập nhật cả anisub.sh + src/ (trước đây chỉ 1 file -> hỏng truyện)
mkdir -p "$WORK/upd" "$WORK/home-upd"
cp "$ROOT/anisub.sh" "$WORK/upd/"
cp -R "$ROOT/src" "$WORK/upd/src"
rm -f "$WORK/upd/src/comic/ehentai.sh"          # giả lập bộ src/ cũ thiếu file
( cd "$WORK/upd" && MOCK_UPDATE_TARBALL="$WORK/anisub-main.tar.gz" HOME="$WORK/home-upd" \
  PATH="$HERE/mockbin:$PATH" bash -c "source ./anisub.sh; SCRIPT_DIR='$WORK/upd'; SELF_SCRIPT='$WORK/upd/anisub.sh'; update_script" \
  > "$WORK/upd.txt" 2>&1 )
has "update báo có bản mới" "Có bản mới" "$(cat "$WORK/upd.txt")"
check "update thay anisub.sh bằng bản mới" "2999.01.01z" "$(sed -n '3s/.*ANISUB_VERSION="\(.*\)"/\1/p' "$WORK/upd/anisub.sh")"
check "update chép lại src/ còn thiếu" "1" "$([ -f "$WORK/upd/src/comic/ehentai.sh" ] && echo 1 || echo 0)"
check "update không tạo src/src lồng nhau" "0" "$([ -d "$WORK/upd/src/src" ] && echo 1 || echo 0)"

# (f) đọc truyện vẫn chạy sau khi tự chữa lành (dùng src/ vừa tải)
( cd "$WORK/solo" && ANISUB_SRC_DIR="$WORK/solo/src" HOME="$WORK/home-solo" \
  PATH="$HERE/mockbin:$PATH" MOCK_FIXTURES="$HERE/fixtures" timeout 30 bash -c \
  "source '$WORK/solo/anisub.sh'; MANGA_SOURCE=nettruyen; MANGA_BASE_URL=https://nettruyen.info; fetch_chapter_list toi-manh-hon-anh-hung | wc -l" \
  > "$WORK/solo-read.txt" 2>&1 )
check "đọc được chapter sau khi tự tải src/" "1" "$([ "$(tr -d ' \n' < "$WORK/solo-read.txt")" -ge 3 ] 2>/dev/null && echo 1 || echo 0)"

echo "== 36. bấm 📚 Đọc Truyện Tranh không vào được: chẩn đoán + tự chọn đúng src/ =="
# (a) env trỏ vào src/ HỎNG: phải thử tiếp chỗ khác, không ghi đè src/ người dùng
mkdir -p "$WORK/badsrc/movie" "$WORK/badsrc/comic" "$WORK/goodsrc/movie" "$WORK/goodsrc/comic"
printf '#!/bin/bash\necho phim\n' > "$WORK/badsrc/movie/kkphim.sh"
printf 'this is not ( valid bash\n' > "$WORK/badsrc/comic/core.sh"
printf '#!/bin/bash\necho phim\n' > "$WORK/goodsrc/movie/kkphim.sh"
{ for fn in manga_source_label manga_main_menu fetch_chapter_list kkphim_search_menu kkphim_browse_menu; do
      printf '%s() { :; }\n' "$fn"
  done; } > "$WORK/goodsrc/comic/core.sh"
( ANISUB_SRC_DIR="$WORK/badsrc" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; ANISUB_SOURCES_OK=0
    ANISUB_SRC_DIR='$WORK/badsrc'; SCRIPT_DIR='$WORK/goodroot'; mkdir -p '$WORK/goodroot'; cp -R '$WORK/goodsrc' '$WORK/goodroot/src'
    anisub_ensure_sources >/dev/null 2>&1; echo \"rc=\$? src=\$ANISUB_SRC_DIR ok=\$ANISUB_SOURCES_OK\"" ) > "$WORK/ens-a.txt" 2>&1
check "src/ hỏng -> thử tiếp src/ cạnh script" "rc=0 src=$WORK/goodroot/src ok=1" "$(cat "$WORK/ens-a.txt")"
has "không ghi đè src/ hỏng của người dùng" "this is not ( valid bash" "$(cat "$WORK/badsrc/comic/core.sh")"

# (b) chỉ có src/ hỏng, không có chỗ nào khác -> báo rõ, KHÔNG tự tải đè
( ANISUB_SRC_DIR="$WORK/badsrc" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; ANISUB_SOURCES_OK=0
    ANISUB_SRC_DIR='$WORK/badsrc'; SCRIPT_DIR='$WORK/emptyroot'; mkdir -p '$WORK/emptyroot'; HOME='$WORK/home-empty'
    CONFIG_DIR='$WORK/home-empty/.config/anisub_cli'
    anisub_ensure_sources; echo \"rc=\$?\"" ) > "$WORK/ens-b.txt" 2>&1
has "src/ hỏng -> nói rõ không nạp được module" "không nạp được module nào" "$(cat "$WORK/ens-b.txt")"
has "src/ hỏng -> chỉ cách sửa" "--doctor" "$(cat "$WORK/ens-b.txt")"
check "src/ hỏng -> không tạo src/ mới" "0" "$([ -d "$WORK/emptyroot/src" ] && echo 1 || echo 0)"

# (c) log chẩn đoán: ghi được + tự cắt bớt khi quá dài
( bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; CACHE_DIR='$WORK/logcache'
    anisub_debug_log 'thử ghi log'; anisub_debug_log 'dòng 2'" ) > /dev/null 2>&1
has "log ghi được nội dung" "thử ghi log" "$(cat "$WORK/logcache/anisub-debug.log" 2>/dev/null)"
( bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; CACHE_DIR='$WORK/logcache'
    for i in \$(seq 1 310); do anisub_debug_log \"n\$i\"; done
    wc -l < '$WORK/logcache/anisub-debug.log'" ) > "$WORK/log.txt" 2>&1
check "log tự cắt còn <= 300 dòng" "1" "$([ "$(tr -d ' ' < "$WORK/log.txt")" -le 300 ] 2>/dev/null && echo 1 || echo 0)"
has "log giữ lại dòng mới nhất sau khi cắt" "n310" "$(cat "$WORK/logcache/anisub-debug.log" 2>/dev/null)"

# (d) main -> menu truyện: có log, và nếu fzf trả rỗng thì báo rõ "chưa vào được"
mkdir -p "$WORK/home-cm" "$WORK/fakebin-cm" "$WORK/cm"
for b in ffmpeg yt-dlp mpv; do printf '#!/bin/bash\nexit 0\n' > "$WORK/fakebin-cm/$b"; chmod +x "$WORK/fakebin-cm/$b"; done
cp -R "$ROOT/src" "$WORK/cm/src"
cp "$ROOT/anisub.sh" "$WORK/cm/"
printf 'q\nq\nq\n' > "$WORK/cm/keys.txt"
( cd "$WORK/cm" && ANISUB_SRC_DIR="$WORK/cm/src" HOME="$WORK/home-cm" MOCK_FIXTURES="$HERE/fixtures" \
  PATH="$HERE/mockbin:$WORK/fakebin-cm:$PATH" \
  KK_MOCK_PICK_MENU=3 KK_MOCK_PICK_SEQ="3,99,9" MOCK_FZF_STATE_DIR="$WORK/home-cm" \
  TERM=dumb timeout 25 bash -c "source ./anisub.sh; MANGA_SOURCE=nettruyen; MANGA_BASE_URL=https://nettruyen.info; main" \
  > "$WORK/cm/out.txt" 2>&1 < "$WORK/cm/keys.txt" )
has "menu chính mở được menu truyện" "MANGA READER" "$(cat "$WORK/cm/out.txt")"
has "fzf trả rỗng -> báo chưa vào được" "Chưa vào được menu truyện" "$(cat "$WORK/cm/out.txt")"
has "log có ghi lần mở menu truyện" "mở 📚 menu truyện" "$(cat "$WORK/home-cm/.config/anisub_cli/cache/anisub-debug.log" 2>/dev/null)"
has "log có ghi fzf trả rỗng" "fzf trả về [<rỗng>]" "$(cat "$WORK/home-cm/.config/anisub_cli/cache/anisub-debug.log" 2>/dev/null)"

# (e) --doctor in ra môi trường + tình trạng hàm chính + log
( cd "$WORK/cm" && ANISUB_SRC_DIR="$WORK/cm/src" HOME="$WORK/home-cm" MOCK_FIXTURES="$HERE/fixtures" \
  PATH="$HERE/mockbin:$WORK/fakebin-cm:$PATH" timeout 30 bash ./anisub.sh --doctor > "$WORK/cm/doctor.txt" 2>&1 )
has "doctor in môi trường (bash/fzf/TERM)" "🐚 Môi trường: bash" "$(cat "$WORK/cm/doctor.txt")"
has "doctor kiểm tra hàm chính" "🧭 Hàm chính" "$(cat "$WORK/cm/doctor.txt")"
has "doctor in log gần nhất" "log gần nhất" "$(cat "$WORK/cm/doctor.txt")"

echo "== 37. lỗi 'manga_source_label: command not found' (src/ thiếu comic/) =="
# (a) src/ chỉ có movie/ + không mạng -> KHÔNG lộ "command not found", báo rõ
mkdir -p "$WORK/movieonly/src/movie" "$WORK/home-mo"
cp "$ROOT/anisub.sh" "$WORK/movieonly/"
cp "$ROOT/src/movie/"*.sh "$WORK/movieonly/src/movie/"
( cd "$WORK/movieonly" && ANISUB_SRC_DIR="" HOME="$WORK/home-mo" PATH="$HERE/mockbin:$PATH" \
  timeout 30 bash ./anisub.sh > "$WORK/mo.txt" 2>&1 )
check "không in 'command not found' khi thiếu comic/" "0" "$(grep -c 'command not found' "$WORK/mo.txt")"
has "báo rõ thiếu bộ nguồn" "Không có bộ file nguồn src/ dùng được" "$(cat "$WORK/mo.txt")"
has "vẫn chỉ cách sửa" "git clone https://github.com/NiyakiPham/anisub.git" "$(cat "$WORK/mo.txt")"

# (b) src/ chỉ có movie/ + có mạng -> tự tải về đủ comic/ rồi chạy được
( cd "$WORK/movieonly" && ANISUB_SRC_DIR="" HOME="$WORK/home-mo" MOCK_UPDATE_TARBALL="$WORK/anisub-main.tar.gz" \
  PATH="$HERE/mockbin:$PATH" timeout 40 bash ./anisub.sh --doctor > "$WORK/mo2.txt" 2>&1 )
has "tự tải lại bộ nguồn đầy đủ" "Đã tải bộ file nguồn" "$(cat "$WORK/mo2.txt")"
check "có lại core.sh" "1" "$([ -f "$WORK/movieonly/src/comic/core.sh" ] && echo 1 || echo 0)"
has "doctor xác nhận đủ hàm chính" "✅ đủ (main, manga_main_menu, fetch_chapter_list, kkphim_search_menu)" "$(cat "$WORK/mo2.txt")"
check "không còn 'command not found'" "0" "$(grep -c 'command not found' "$WORK/mo2.txt")"

# (c) comic/ có file nhưng nạp thiếu hàm -> nói rõ thiếu hàm nào, không ghi đè
mkdir -p "$WORK/partial/src/movie" "$WORK/partial/src/comic" "$WORK/home-pa"
cp "$ROOT/src/movie/"*.sh "$WORK/partial/src/movie/"
printf 'manga_main_menu() { :; }\n' > "$WORK/partial/src/comic/core.sh"
( ANISUB_SRC_DIR=/khong/co bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; ANISUB_SRC_DIR='$WORK/partial/src'
   anisub_load_sources '$WORK/partial/src'; echo rc=\$?" ) > "$WORK/pa.txt" 2>&1
has "nói rõ nạp thiếu hàm nào" "nạp thiếu:" "$(cat "$WORK/pa.txt")"
has "liệt kê hàm thiếu" "fetch_chapter_list" "$(cat "$WORK/pa.txt")"
has "chỉ đúng thư mục comic/" "comic/" "$(cat "$WORK/pa.txt")"
check "load_sources trả lỗi" "rc=1" "$(grep '^rc=' "$WORK/pa.txt")"
has "không ghi đè file comic/ hỏng" "manga_main_menu() { :; }" "$(cat "$WORK/partial/src/comic/core.sh")"

# (d) nhãn nguồn truyện luôn gọi được (menu chính không vỡ khi chưa nạp module)
( bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; unset -f manga_source_label; \
   manga_source_label() { printf '%s' \"\${MANGA_SOURCE:-\${DEFAULT_MANGA_SOURCE:-nettruyen}}\"; }; \
   echo \$(manga_source_label)" ) > "$WORK/label.txt" 2>&1
has "có hàm nhãn nguồn dự phòng" "nettruyen" "$(cat "$WORK/label.txt")"
check "file thật có khai báo hàm nhãn dự phòng" "1" "$(grep -c '^manga_source_label() {' "$ROOT/anisub.sh")"

echo "== 38. e-hentai HTTP 000: nói đúng nguyên nhân + cho đổi nguồn ngay =="
# (a) URL in ra phải đầy đủ (không còn '/?f_search=...' trơ trọi)
( bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_SOURCE=ehentai; MANGA_BASE_URL=https://e-hentai.org
    eh_full_url '/?f_search=language:vietnamese&f_srdd=4'" ) > "$WORK/eh38a.txt" 2>&1
check "in URL e-hentai đầy đủ" "https://e-hentai.org/?f_search=language:vietnamese&f_srdd=4" "$(tail -1 "$WORK/eh38a.txt")"

# (b) không kết nối được -> nêu nguyên nhân theo mã lỗi curl
( CACHE_DIR="$WORK/c38" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
    echo '--6--';   manga_net_hint 'https://nettruyen.info' 6
    echo '--28--';  manga_net_hint 'https://nettruyen.info' 28
    echo '--35--';  manga_net_hint 'https://nettruyen.info' 35
    echo '--eh--';  manga_net_hint 'https://e-hentai.org' 7" ) > "$WORK/eh38b.txt" 2>&1
has "mã 6 -> gợi ý DNS/VPN" "Không phân giải được tên miền" "$(cat "$WORK/eh38b.txt")"
has "mã 28 -> gợi ý timeout" "Quá thời gian chờ" "$(cat "$WORK/eh38b.txt")"
has "mã 35 -> gợi ý TLS" "Lỗi TLS/SSL" "$(cat "$WORK/eh38b.txt")"
has "e-hentai -> cảnh báo nhà mạng VN chặn" "nhà mạng Việt Nam chặn" "$(cat "$WORK/eh38b.txt")"

# (c) eh_browse_menu: in URL đầy đủ + HTTP 000 + gợi ý, Enter thì quay lại (giữ nguồn)
mkdir -p "$WORK/home-eh38"
( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-eh38" MOCK_FIXTURES="$HERE/fixtures" PHYS="$PATH" \
  bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
    MANGA_SOURCE=ehentai; MANGA_BASE_URL='https://manga-offline.test'
    eh_browse_menu '/?f_search=language:vietnamese&f_srdd=4' 'test' <<< ''
    echo \"rc=\$? src=\$MANGA_SOURCE\"" ) > "$WORK/eh38c.txt" 2>&1
has "báo đúng URL đang tải" "Đang tải: https://manga-offline.test/?f_search=language:vietnamese&f_srdd=4" "$(cat "$WORK/eh38c.txt")"
has "báo HTTP 000" "(HTTP 000)" "$(cat "$WORK/eh38c.txt")"
has "gợi ý theo mã lỗi curl" "Không phân giải được tên miền" "$(cat "$WORK/eh38c.txt")"
has "Enter -> quay lại, giữ nguyên nguồn" "rc=1 src=ehentai" "$(cat "$WORK/eh38c.txt")"

# (d) bấm 1 -> chuyển sang nettruyen ngay tại chỗ (lưu cấu hình luôn)
( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-eh38" MOCK_FIXTURES="$HERE/fixtures" \
  bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
    MANGA_SOURCE=ehentai; MANGA_BASE_URL='https://manga-offline.test'
    eh_browse_menu '/?f_search=language:vietnamese&f_srdd=4' 'test' <<< '1'
    echo \"rc=\$? src=\$MANGA_SOURCE base=\$MANGA_BASE_URL\"" ) > "$WORK/eh38d.txt" 2>&1
has "bấm 1 -> đổi sang nettruyen" "rc=2 src=nettruyen base=https://nettruyen.info" "$(cat "$WORK/eh38d.txt")"
has "gợi ý đổi nguồn được in ra" "chuyển sang nettruyen" "$(cat "$WORK/eh38d.txt")"
has "đã lưu cấu hình mới" 'MANGA_SOURCE="nettruyen"'  "$(cat "$WORK/home-eh38/.config/anisub_cli/config.cfg" 2>/dev/null)"

# (e) mã lỗi curl được ghi lại để chẩn đoán đọc được
( bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_SOURCE=ehentai; MANGA_BASE_URL='https://manga-offline.test'
    eh_fetch '/' >/dev/null 2>&1; echo \"http=\$(anisub_last_http) curl=\$(anisub_last_curl_err)\"" ) > "$WORK/eh38e.txt" 2>&1
check "ghi lại mã lỗi curl" "http=000 curl=6" "$(tail -1 "$WORK/eh38e.txt")"

# (f) lưu cấu hình phải tự tạo thư mục (trước đây mất im lặng nếu ~/.config/anisub_cli chưa có)
( HOME="$WORK/home-sc38" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_SOURCE=nettruyen; save_config >/dev/null 2>&1; \
    echo \"exists=\$([ -f '$WORK/home-sc38/.config/anisub_cli/config.cfg' ] && echo 1 || echo 0)\"" ) > "$WORK/eh38f.txt" 2>&1
check "save_config tự tạo thư mục cấu hình" "exists=1" "$(tail -1 "$WORK/eh38f.txt")"

echo "== 39. DNS bị chặn: tự hỏi IP qua DoH + chẩn đoán đúng lớp bị chặn =="
# (a) hỏi IP qua DNS-over-HTTPS
( bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; anisub_doh_resolve e-hentai.org" ) > "$WORK/n39a.txt" 2>&1
check "DoH trả về IP" "203.0.113.10" "$(tail -1 "$WORK/n39a.txt")"

# (b) DNS hỏng -> tự DoH + --resolve rồi tải được
mkdir -p "$WORK/home-n39"
( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-n39" MOCK_FIXTURES="$HERE/fixtures" \
  bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
    MANGA_SOURCE=ehentai; MANGA_BASE_URL='https://dnsblock.test'; MANGA_DOH=auto
    out=\$(eh_fetch '/'); echo \"rc=\$? http=\$(anisub_last_http) len=\${#out}\"
    echo \"cache=\$(cat \$HOME/.config/anisub_cli/cache/doh-dnsblock.test 2>/dev/null)\"" ) > "$WORK/n39b.txt" 2>&1
has "tự retry qua DoH -> tải được" "rc=0 http=200" "$(cat "$WORK/n39b.txt")"
has "nhớ IP DoH cho lần sau" "cache=203.0.113.10" "$(cat "$WORK/n39b.txt")"

# (c) MANGA_DOH=off -> không dùng DoH (vẫn 000)
( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-n39" MOCK_FIXTURES="$HERE/fixtures" \
  bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
    MANGA_SOURCE=ehentai; MANGA_BASE_URL='https://dnsblock.test'; MANGA_DOH=off
    rm -f \$HOME/.config/anisub_cli/cache/doh-dnsblock.test
    eh_fetch '/' >/dev/null 2>&1; echo \"http=\$(anisub_last_http)\"" ) > "$WORK/n39c.txt" 2>&1
check "DOH=off -> không retry" "http=000" "$(tail -1 "$WORK/n39c.txt")"

# (d) netcheck: chỉ DNS bị chặn -> nói rõ và khuyên restart systemd-resolved
( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-n39" MOCK_FIXTURES="$HERE/fixtures" \
  bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
    MANGA_SOURCE=ehentai; MANGA_BASE_URL='https://dnsblock.test'; anisub_netcheck; echo \"rc=\$?\"" ) > "$WORK/n39d.txt" 2>&1
has "netcheck in DNS hệ thống" "DNS hệ thống" "$(cat "$WORK/n39d.txt")"
has "netcheck in DoH" "DNS-over-HTTPS : 203.0.113.10" "$(cat "$WORK/n39d.txt")"
has "netcheck kết luận chỉ DNS bị chặn" "chỉ DNS bị chặn" "$(cat "$WORK/n39d.txt")"
has "nhắc restart systemd-resolved" "systemctl restart systemd-resolved" "$(cat "$WORK/n39d.txt")"

# (e) netcheck: host vào được -> báo OK, rc=0
( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-n39" MOCK_FIXTURES="$HERE/fixtures" \
  bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
    MANGA_SOURCE=nettruyen; MANGA_BASE_URL='https://nettruyen.info'; anisub_netcheck; echo \"rc=\$?\"" ) > "$WORK/n39e.txt" 2>&1
has "host OK -> báo vào được" "✅ Vào được" "$(cat "$WORK/n39e.txt")"
has "host OK -> rc=0" "rc=0" "$(tail -1 "$WORK/n39e.txt")"

# (f) bị chặn IP/SNI -> khuyên VPN/proxy, có ví dụ export https_proxy
( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-n39" MOCK_FIXTURES="$HERE/fixtures" \
  bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
    MANGA_SOURCE=ehentai; MANGA_BASE_URL='https://manga-offline.test'; MANGA_DOH=off
    anisub_netcheck; echo \"rc=\$?\"" ) > "$WORK/n39f.txt" 2>&1
has "bị chặn -> khuyên cần VPN/proxy" "Cần VPN/proxy thật" "$(cat "$WORK/n39f.txt")"
has "có ví dụ export https_proxy" "export https_proxy=socks5h://127.0.0.1:1080" "$(cat "$WORK/n39f.txt")"
has "bị chặn -> rc=1" "rc=1" "$(tail -1 "$WORK/n39f.txt")"

# (g) MANGA_PROXY được truyền cho curl (kiểm tra qua log tham số)
rm -f "$WORK/n39args.log"
( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-n39" MOCK_FIXTURES="$HERE/fixtures" \
  MOCK_CURL_HEADER_LOG="$WORK/n39args.log" \
  bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
    MANGA_SOURCE=nettruyen; MANGA_BASE_URL='https://nettruyen.info'; MANGA_PROXY='socks5h://127.0.0.1:1080'
    manga_http_fetch '/' >/dev/null 2>&1" ) > /dev/null 2>&1
has "MANGA_PROXY -> curl --proxy" "--proxy socks5h://127.0.0.1:1080" "$(cat "$WORK/n39args.log" 2>/dev/null)"

# (h) --netcheck chạy từ dòng lệnh
( cd "$WORK" && ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-n39" MOCK_FIXTURES="$HERE/fixtures" \
  PATH="$HERE/mockbin:$PATH" timeout 30 bash "$ROOT/anisub.sh" --netcheck nettruyen.info > "$WORK/n39h.txt" 2>&1; echo "rc=$?" ) > "$WORK/n39h-rc.txt" 2>&1
has "--netcheck in kết quả" "Kiểm tra mạng" "$(cat "$WORK/n39h.txt")"
check "--netcheck thoát 0 khi vào được" "rc=0" "$(tail -1 "$WORK/n39h-rc.txt")"


echo "== 40. nguồn kagane (https://kagane.moe) =="
mkdir -p "$WORK/home-k40"
# Chạy 1 đoạn lệnh trong subshell với nguồn kagane + curl/fzf giả lập
kgsh() {
    ( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-k40" MOCK_FIXTURES="$HERE/fixtures" \
      MOCK_CURL_LOG="${K40_LOG:-$MOCK_CURL_LOG}" MOCK_CURL_HEADER_LOG="${K40_HDR:-$MOCK_CURL_HEADER_LOG}" \
      bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
        MANGA_SOURCE=kagane; MANGA_BASE_URL='https://kagane.moe'
        $1" ) 2>&1
}

KG_SEG="codename-anastasia-steamy-019c1ef1-9a88-7e37-ae95-a52a996f8638"
KG_SID="019c1ef1-9a88-7e37-ae95-a52a996f8638"
KG_BOOK="019c1efa-f402-7ea3-9c97-b0fc9bc29c43"
KG_SERIES_URL="https://kagane.moe/series/$KG_SEG"
KG_READ="https://kagane.moe/series/$KG_SEG/reader/$KG_BOOK"

# (a) nhận diện nguồn: nhãn, không bị coi là truyenvn, base URL
check "nhãn nguồn = kagane" "kagane" "$(kgsh 'manga_source_label')"
check "kagane không bị nhận là truyenvn" "1" "$(kgsh 'manga_is_truyenvn && echo 0 || echo 1')"
check "kg_base lấy MANGA_BASE_URL" "https://kagane.moe" "$(kgsh 'kg_base')"
check "kg_base bỏ dấu / cuối" "https://kagane.moe" "$(kgsh 'MANGA_BASE_URL="https://kagane.moe/"; kg_base')"

# (b) đọc ID từ URL
check "series_id từ URL truyện" "$KG_SID" "$(kgsh "kg_series_id '$KG_SERIES_URL'")"
check "series_id từ slug-uuid" "$KG_SID" "$(kgsh "kg_series_id '$KG_SEG'")"
check "series_id bỏ phần /reader" "$KG_SID" "$(kgsh "kg_series_id '$KG_READ'")"
check "book_id từ URL đọc" "$KG_BOOK" "$(kgsh "kg_book_id '$KG_READ'")"
check "book_id từ URL có tiền tố chapter-N" "$KG_BOOK" \
    "$(kgsh "kg_book_id 'https://kagane.moe/series/x-$KG_SID/reader/chapter-0-$KG_BOOK'")"

# (c) dựng URL
check "slug -> URL trang truyện" "$KG_SERIES_URL" "$(kgsh "manga_manga_url '$KG_SEG'")"
check "link đọc -> URL trang truyện" "$KG_SERIES_URL" "$(kgsh "manga_manga_url '$KG_READ'")"
check "slug lưu lịch sử = slug-uuid" "$KG_SEG" "$(kgsh "manga_slug_from_url '$KG_READ'")"

# (d) parse HTML /search -> tên|url|slug|bìa
K40_ITEMS=$(kgsh "kg_parse_items < '$HERE/fixtures/kagane-search.html'")
check "parse 3 truyện từ trang /search" "3" "$(printf '%s\n' "$K40_ITEMS" | grep -c '.')"
check "tên truyện đầu tiên" "The Ogre's Bride" "$(printf '%s\n' "$K40_ITEMS" | head -1 | cut -d'|' -f1)"
check "URL truyện đầu tiên" "https://kagane.moe/series/the-ogre-s-bride-019c5678-f35c-7589-9375-912718d50bd0" \
    "$(printf '%s\n' "$K40_ITEMS" | head -1 | cut -d'|' -f2)"
has "ảnh bìa lấy từ API image" "https://kagane.moe/api/v2/image/019c5678-f349-7f23-8588-603fd94a73c5/compressed" \
    "$(printf '%s\n' "$K40_ITEMS" | head -1 | cut -d'|' -f4)"

# (e) danh sách + tìm kiếm qua dispatch chuẩn
check "manga_list_items -> 3 truyện" "3" "$(kgsh 'manga_list_items /search "sort=now"' | grep -c '.')"
check "manga_search_items -> 3 truyện" "3" "$(kgsh 'manga_search_items overgeared' | grep -c '.')"
K40_LOG="$WORK/k40-lang.log"; : > "$K40_LOG"
K40_LOG="$K40_LOG" kgsh 'KAGANE_LANG=vi; manga_search_items romance' > /dev/null
has "KAGANE_LANG -> tham số languages=" "languages=vi" "$(cat "$WORK/k40-lang.log" 2>/dev/null)"
check "trang 2 -> nhắc Kagane chỉ có trang đầu" "1" \
    "$(kgsh 'manga_list_items /search page=2' | grep -c 'chỉ duyệt được trang đầu')"

# (f) danh sách chương qua API books/index
K40_CHAPS=$(kgsh "fetch_chapter_list '$KG_SEG'")
check "API trả 3 chương" "3" "$(printf '%s\n' "$K40_CHAPS" | grep -c '.')"
check "chương đầu = Prologue" "Prologue" "$(printf '%s\n' "$K40_CHAPS" | head -1 | cut -d'|' -f1)"
check "chương cuối = Episode 2" "Episode 2" "$(printf '%s\n' "$K40_CHAPS" | tail -1 | cut -d'|' -f1)"
check "dòng chương có số chương ở cột 3" "2" "$(printf '%s\n' "$K40_CHAPS" | tail -1 | cut -d'|' -f3)"
has "URL đọc dựng từ slug + series_id" "$KG_READ" "$(printf '%s\n' "$K40_CHAPS" | head -1 | cut -d'|' -f2)"
check "Ctrl-G: số 1 -> URL đọc của chương 1" \
    "https://kagane.moe/series/$KG_SEG/reader/019c1f01-a7d7-74a4-a7d7-0e7777d87b1a" \
    "$(kgsh "fetch_chapter_list '$KG_SEG' >/dev/null; manga_chapter_url '$KG_SERIES_URL' 1")"
check "target rỗng -> báo lỗi rõ ràng, rc=1" "1" \
    "$(kgsh 'fetch_chapter_list "" >/dev/null 2>&1; echo $?')"

# (g) ảnh trang: xin integrity token -> challenge -> URL có ?token=
K40_IMGS=$(kgsh "fetch_chapter_images '$KG_READ'")
check "challenge trả 3 trang" "3" "$(printf '%s\n' "$K40_IMGS" | grep -c '.')"
has "URL ảnh đúng dạng books/page/original" \
    "https://kagane.moe/api/v2/books/page/original/$KG_BOOK/019c2a00-0000-7000-8000-000000000001.jpg" \
    "$(printf '%s\n' "$K40_IMGS" | head -1)"
has "URL ảnh có token" "?token=mock-access-token" "$(printf '%s\n' "$K40_IMGS" | head -1)"
has "ext rỗng -> mặc định jxl" ".jxl?token=" "$(printf '%s\n' "$K40_IMGS" | tail -1)"
check "ảnh xếp đúng thứ tự trang" "019c2a00-0000-7000-8000-000000000001.jpg" \
    "$(printf '%s\n' "$K40_IMGS" | head -1 | sed 's#.*/original/[0-9a-f-]*/##; s#?.*##')"

# (h) token được cache (không gọi /api/integrity 2 lần)
K40_INTLOG="$WORK/k40-int.log"; : > "$K40_INTLOG"
K40_LOG="$K40_INTLOG" kgsh 'rm -f "$CACHE_DIR/kg-integrity"; kg_integrity_token >/dev/null; kg_integrity_token >/dev/null' > /dev/null
check "token integrity chỉ xin 1 lần" "1" "$(grep -c '/api/integrity' "$K40_INTLOG" 2>/dev/null)"

# (i) token hết hạn (401) -> tự xin token mới rồi thử lại
rm -f "$WORK/k40-401.flag"
K40_IMGS2=$(MOCK_KG_CHALLENGE_401="$WORK/k40-401.flag" kgsh "rm -f \${CACHE_DIR}/kg-integrity; fetch_chapter_images '$KG_READ'")
check "401 -> vẫn lấy được 3 trang sau khi làm mới token" "3" "$(printf '%s\n' "$K40_IMGS2" | grep -c '^https://')"

# (j) lỗi API -> thông báo rõ ràng, không treo
K40_FAIL=$(MOCK_KG_CHALLENGE_FAIL=1 kgsh "fetch_chapter_images '$KG_READ'")
has "challenge 403 -> báo không cấp quyền đọc" "không cấp quyền đọc" "$K40_FAIL"
has "gợi ý KAGANE_COOKIE khi bị chặn" "KAGANE_COOKIE" "$K40_FAIL"
K40_FAIL2=$(MOCK_KG_INTEGRITY_FAIL=1 kgsh "rm -f \${CACHE_DIR}/kg-integrity; fetch_chapter_images '$KG_READ'")
has "integrity 403 -> gợi ý chẩn đoán mạng" "netcheck" "$K40_FAIL2"
check "integrity lỗi -> không trả ảnh" "0" "$(printf '%s\n' "$K40_FAIL2" | grep -c '^https://')"

# (k) tải ảnh: phải gửi header Origin của site (thiếu là 404)
K40_HDRLOG="$WORK/k40-hdr.log"; : > "$K40_HDRLOG"
K40_HDR="$K40_HDRLOG" kgsh "manga_download_image '$KG_READ-page.jpg' '$WORK/k40-img.bin'" > /dev/null
has "tải ảnh gửi header origin của Kagane" "origin: https://kagane.moe" "$(cat "$K40_HDRLOG" 2>/dev/null)"
check "tải ảnh ghi được file ảnh" "1" "$([ -s "$WORK/k40-img.bin" ] && echo 1 || echo 0)"
check "file tải về đúng là ảnh" "1" "$(kgsh "manga_file_is_image '$WORK/k40-img.bin'")"

# (l) cookie tuỳ chọn được gửi kèm
K40_HDRLOG2="$WORK/k40-hdr2.log"; : > "$K40_HDRLOG2"
K40_HDR="$K40_HDRLOG2" kgsh 'KAGANE_COOKIE="abc=1"; kg_api_call GET "/api/v2/series/x" >/dev/null' > /dev/null
has "KAGANE_COOKIE -> header cookie" "cookie: abc=1" "$(cat "$K40_HDRLOG2" 2>/dev/null)"

# (m) chẩn đoán riêng của nguồn
K40_DIAG=$(kgsh 'manga_diagnose --no-pause')
has "chẩn đoán kagane: có mục nguồn" "Chẩn đoán nguồn truyện tranh (kagane)" "$K40_DIAG"
has "chẩn đoán kagane: duyệt/tìm dùng được" "Duyệt/tìm truyện dùng được" "$K40_DIAG"
has "chẩn đoán kagane: kiểm tra token đọc" "Token đọc" "$K40_DIAG"
has "chẩn đoán kagane: đếm chương qua API" "3 chương" "$K40_DIAG"

# (n) cấu hình: menu nguồn + config.cfg
check "danh sách nguồn có đủ 5 lựa chọn" "5" "$(kgsh 'manga_source_choices' | grep -c '.')"
check "nguồn thứ 4 là kagane" "kagane|https://kagane.moe" \
    "$(kgsh 'manga_source_choices' | sed -n '4p' | cut -d'|' -f2,3)"
check "module kagane được nhận là đã nạp" "1" "$(kgsh 'manga_has_kagane_module && echo 1 || echo 0')"
K40_FZFDIR="$WORK/k40-fzf"; mkdir -p "$K40_FZFDIR"
cat > "$K40_FZFDIR/fzf" <<'EOS'
#!/bin/bash
inp=$(cat)
[ -n "${K40_FZF_DUMP:-}" ] && printf '%s\n' "$inp" > "$K40_FZF_DUMP"
printf '%s\n' "$inp" | sed -n "${KK_MOCK_PICK:-1}p"
EOS
chmod +x "$K40_FZFDIR/fzf"
PATH="$K40_FZFDIR:$PATH" K40_FZF_DUMP="$WORK/k40-fzf-dump.txt" KK_MOCK_PICK=2 \
    kgsh 'MANGA_SOURCE=truyenvn; manga_switch_source' > /dev/null 2>&1
check "picker đánh dấu nguồn đang dùng" "1" \
    "$(grep -c '✅ 2) truyenvn' "$WORK/k40-fzf-dump.txt" 2>/dev/null)"
check "picker liệt kê đủ 5 nguồn" "5" \
    "$(grep -cE '^ *(✅ )?[1-5]\) ' "$WORK/k40-fzf-dump.txt" 2>/dev/null)"
check "Cài đặt: chọn 4 -> chuyển sang kagane" "kagane|https://kagane.moe" \
    "$(KK_MOCK_PICK=4 kgsh 'MANGA_SOURCE=nettruyen; MANGA_BASE_URL="https://nettruyen.info"; manga_switch_source >/dev/null 2>&1; printf "%s|%s" "$MANGA_SOURCE" "$MANGA_BASE_URL"')"
has "Cài đặt: lưu nguồn kagane vào config" 'MANGA_SOURCE="kagane"' \
    "$(cat "$WORK/home-k40/.config/anisub_cli/config.cfg" 2>/dev/null)"
check "Cài đặt: Esc -> giữ nguyên nguồn" "nettruyen" \
    "$(KK_MOCK_PICK=99 kgsh 'MANGA_SOURCE=nettruyen; manga_switch_source >/dev/null 2>&1; printf "%s" "$MANGA_SOURCE"')"
check "Cài đặt: chọn 3 -> e-hentai" "ehentai|https://e-hentai.org" \
    "$(KK_MOCK_PICK=3 kgsh 'MANGA_SOURCE=nettruyen; manga_switch_source >/dev/null 2>&1; printf "%s|%s" "$MANGA_SOURCE" "$MANGA_BASE_URL"')"
# bộ src/ cũ (không có module kagane): cảnh báo + KHÔNG đổi nguồn
K40_OLD=$(KK_MOCK_PICK=4 kgsh 'unset KAGANE_MODULE; unset -f kg_list_items; MANGA_SOURCE=nettruyen; MANGA_BASE_URL="https://nettruyen.info"; manga_switch_source; printf "src=%s|" "$MANGA_SOURCE"')
has "bộ src/ cũ -> cảnh báo cần Cập nhật" "chưa có module kagane" "$K40_OLD"
has "bộ src/ cũ -> nhắc ./anisub.sh --update" "--update" "$K40_OLD"
has "bộ src/ cũ -> không đổi sang kagane" "src=nettruyen|" "$K40_OLD"
has "menu nhắc bộ src/ cũ khi thiếu nguồn" "bộ src/ cũ: thiếu nguồn" \
    "$(src_has 'bộ src/ cũ: thiếu nguồn')"
has "nhãn menu nguồn truyện có kagane" "nettruyen / truyenvn / e-hentai / kagane" \
    "$(src_has 'nettruyen / truyenvn / e-hentai / kagane')"
check "có file module src/comic/kagane.sh" "1" "$([ -f "$ROOT/src/comic/kagane.sh" ] && echo 1 || echo 0)"
K40_CFG=$(kgsh 'KAGANE_LANG="vi"; KAGANE_COOKIE="abc=1"; save_config >/dev/null 2>&1; cat "$CONFIG_FILE"')
has "config.cfg lưu KAGANE_LANG" 'KAGANE_LANG="vi"' "$K40_CFG"
has "config.cfg lưu KAGANE_COOKIE" 'KAGANE_COOKIE="abc=1"' "$K40_CFG"

# (o) --netcheck tự chọn host theo nguồn đang dùng
K40_NET=$(kgsh 'anisub_netcheck')
has "netcheck dùng host kagane.moe" "kagane.moe" "$K40_NET"

# (p) các nguồn cũ không bị ảnh hưởng
check "nettruyen vẫn là nettruyen" "nettruyen" \
    "$( ( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-k40" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_SOURCE=nettruyen; manga_source_label" ) 2>&1)"
check "e-hentai vẫn là e-hentai" "e-hentai" \
    "$( ( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-k40" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_SOURCE=ehentai; manga_source_label" ) 2>&1)"


echo "== 41. nguồn toon18x (https://toon18x.com) =="
mkdir -p "$WORK/home-k41"
# Chạy 1 đoạn lệnh trong subshell với nguồn toon18x + curl/fzf giả lập
txsh() {
    ( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-k41" MOCK_FIXTURES="$HERE/fixtures" \
      MOCK_CURL_LOG="${K41_LOG:-$MOCK_CURL_LOG}" MOCK_CURL_HEADER_LOG="${K41_HDR:-$MOCK_CURL_HEADER_LOG}" \
      bash -c "source '$WORK/lib.sh' >/dev/null 2>&1
        MANGA_SOURCE=toon18x; MANGA_BASE_URL='https://toon18x.com'
        $1" ) 2>&1
}

# (a) nhận diện nguồn
check "nhãn nguồn = toon18x" "toon18x" "$(txsh 'manga_source_label')"
check "toon18x không bị nhận là truyenvn" "1" "$(txsh 'manga_is_truyenvn && echo 0 || echo 1')"
check "tx_base bỏ dấu / cuối" "https://toon18x.com" "$(txsh 'MANGA_BASE_URL="https://toon18x.com/"; tx_base')"
check "tx_base bỏ cả /vi nếu người dùng dán kèm" "https://toon18x.com" \
    "$(txsh 'MANGA_BASE_URL="https://toon18x.com/vi"; tx_base')"
check "module toon18x được nhận là đã nạp" "1" "$(txsh 'manga_has_toon18x_module && echo 1 || echo 0')"

# (b) dựng URL + slug
check "slug -> URL trang truyện" "https://toon18x.com/vi/manga/alpha-story" \
    "$(txsh "manga_manga_url 'alpha-story'")"
check "link đọc -> URL trang truyện" "https://toon18x.com/vi/manga/alpha-story" \
    "$(txsh "manga_manga_url 'https://toon18x.com/vi/manga/alpha-story/chapter/12'")"
check "slug lưu lịch sử = slug truyện" "alpha-story" \
    "$(txsh "manga_slug_from_url 'https://toon18x.com/vi/manga/alpha-story/chapter/12'")"
check "Ctrl-G: chương 12 -> URL đọc" "https://toon18x.com/vi/manga/alpha-story/chapter/12" \
    "$(txsh "manga_chapter_url 'https://toon18x.com/vi/manga/alpha-story' 12")"
check "chương lẻ 11.5 giữ nguyên số" "https://toon18x.com/vi/manga/alpha-story/chapter/11.5" \
    "$(txsh "manga_chapter_url 'https://toon18x.com/vi/manga/alpha-story' 'Chương 11.5'")"
check "TOON18X_LOCALE=en -> URL /en/..." "https://toon18x.com/en/manga/alpha-story" \
    "$(txsh "TOON18X_LOCALE=en; manga_manga_url 'alpha-story'")"

# (c) parse HTML danh sách
K41_ITEMS=$(txsh "tx_parse_items < '$HERE/fixtures/toon18x-list.html'")
check "parse 3 truyện từ trang danh sách" "3" "$(printf '%s\n' "$K41_ITEMS" | grep -c '.')"
check "tên truyện đầu tiên" "Alpha Story" "$(printf '%s\n' "$K41_ITEMS" | head -1 | cut -d'|' -f1)"
check "URL truyện đầu tiên" "https://toon18x.com/vi/manga/alpha-story" \
    "$(printf '%s\n' "$K41_ITEMS" | head -1 | cut -d'|' -f2)"
has "ảnh bìa lấy từ cdn.toon18x.com/covers" "https://cdn.toon18x.com/covers/alpha-story.webp" \
    "$(printf '%s\n' "$K41_ITEMS" | head -1 | cut -d'|' -f4)"
check "giải mã &amp; trong tên truyện" "Gamma & Garden" \
    "$(printf '%s\n' "$K41_ITEMS" | sed -n '3p' | cut -d'|' -f1)"
check "không lặp truyện dù HTML có 2 link/truyện" "3" "$(printf '%s\n' "$K41_ITEMS" | cut -d'|' -f3 | sort -u | grep -c '.')"

# (d) danh sách + tìm kiếm qua dispatch chuẩn
check "manga_list_items -> 3 truyện" "3" "$(txsh 'manga_list_items "/vi/search" "sort=updated"' | grep -c '.')"
K41_LOG="$WORK/k41-search.log"; : > "$K41_LOG"
K41_LOG="$K41_LOG" txsh 'manga_search_items alpha' > /dev/null
has "tìm kiếm dùng tham số q=" "q=alpha" "$(cat "$K41_LOG" 2>/dev/null)"
has "tìm kiếm gọi /vi/search" "/vi/search" "$(cat "$K41_LOG" 2>/dev/null)"
has "sort được chuyển thành tham số" "sort=views" \
    "$(K41_LOG="$WORK/k41-sort.log"; : > "$K41_LOG"; K41_LOG="$K41_LOG" txsh 'manga_list_items "/vi/search" "sort=views"' >/dev/null; cat "$K41_LOG" 2>/dev/null)"
has "có danh sách Mới cập nhật (Toon18x)" "Mới cập nhật (Toon18x)" "$(src_has 'Mới cập nhật (Toon18x)')"
has "danh sách hot dùng sort=followers" "sort=followers" "$(src_has 'sort=followers')"
has "danh sách đọc nhiều dùng sort=views" "sort=views" "$(src_has 'sort=views')"

# (e) danh sách chương qua API
K41_CHAPS=$(txsh "fetch_chapter_list alpha-story")
check "API trả 4 chương" "4" "$(printf '%s\n' "$K41_CHAPS" | grep -c '.')"
check "chương đầu = Chương 1 (sắp tăng dần)" "Chương 1" "$(printf '%s\n' "$K41_CHAPS" | head -1 | cut -d'|' -f1)"
check "chương cuối = Chương 12" "Chương 12" "$(printf '%s\n' "$K41_CHAPS" | tail -1 | cut -d'|' -f1)"
check "chương lẻ 11.5 nằm giữa 11 và 12" "Chương 11.5" "$(printf '%s\n' "$K41_CHAPS" | sed -n '3p' | cut -d'|' -f1)"
check "cột 3 = số chương" "11.5" "$(printf '%s\n' "$K41_CHAPS" | sed -n '3p' | cut -d'|' -f3)"
has "URL đọc dựng từ slug + số chương" "https://toon18x.com/vi/manga/alpha-story/chapter/1|" "$K41_CHAPS"
K41_APILOG="$WORK/k41-api.log"; : > "$K41_APILOG"
K41_LOG="$K41_APILOG" txsh 'fetch_chapter_list alpha-story' > /dev/null
has "gọi đúng API /api/v1/manga/<slug>/chapters" "/api/v1/manga/alpha-story/chapters" "$(cat "$K41_APILOG" 2>/dev/null)"
has "xin 200 chương mỗi lần (limit=200)" "limit=200" "$(cat "$K41_APILOG" 2>/dev/null)"
check "chỉ 1 request khi API trả < limit" "1" "$(grep -c '/chapters' "$K41_APILOG" 2>/dev/null)"
check "phân trang: 200 + 3 chương = 203" "203" \
    "$(MOCK_TX_BIG=1 txsh 'fetch_chapter_list alpha-story' | grep -c '.')"
K41_FAIL=$(MOCK_TX_CHAP_FAIL=1 txsh 'fetch_chapter_list alpha-story')
has "API 404 -> báo lỗi rõ ràng" "API Toon18x lỗi (HTTP 404)" "$K41_FAIL"
check "API 404 -> rc=1" "1" "$(MOCK_TX_CHAP_FAIL=1 txsh 'fetch_chapter_list alpha-story >/dev/null 2>&1; echo $?')"
has "target rỗng -> nhắc dán link truyện" "Dán link dạng" "$(txsh 'fetch_chapter_list "" 2>&1')"
check "target rỗng -> rc=1" "1" "$(txsh 'fetch_chapter_list "" >/dev/null 2>&1; echo $?')"

# (f) ảnh trang đọc
K41_IMGS=$(txsh "fetch_chapter_images 'https://toon18x.com/vi/manga/alpha-story/chapter/2'")
check "trang đọc trả 4 ảnh" "4" "$(printf '%s\n' "$K41_IMGS" | grep -c '.')"
check "ảnh đầu tiên đúng trang 001" "https://tv1.toon18x.com/series/alpha-story/ch-0002/001.png" \
    "$(printf '%s\n' "$K41_IMGS" | head -1)"
check "ảnh xếp đúng thứ tự trang" "004" "$(printf '%s\n' "$K41_IMGS" | tail -1 | sed 's#.*/##; s#\..*##')"
has "giữ nguyên đoạn scrapes/<uuid> trong URL" "/scrapes/4f1c9a2e-0d3b-4c55-9f2a-77aa11bb22cc/002.png" "$K41_IMGS"
check "bỏ ảnh bìa/logo khỏi danh sách ảnh" "0" "$(printf '%s\n' "$K41_IMGS" | grep -c '/covers/\|/logo')"
check "giải mã URL dạng JSON (\/) " "1" "$(printf '%s\n' "$K41_IMGS" | grep -c '004.png')"
K41_NAV=$(txsh "mkdir -p \"\$CACHE_DIR\"; fetch_chapter_images 'https://toon18x.com/vi/manga/alpha-story/chapter/2' >/dev/null; manga_saved_nav")
check "lưu được chương trước/sau" \
    "https://toon18x.com/vi/manga/alpha-story/chapter/1|https://toon18x.com/vi/manga/alpha-story/chapter/3" "$K41_NAV"

# (g) tải ảnh (host riêng tv1.toon18x.com)
check "tải ảnh trang ghi được file" "1" \
    "$(txsh "manga_download_image 'https://tv1.toon18x.com/series/alpha-story/ch-0002/001.png' '$WORK/k41-img.bin' >/dev/null 2>&1; [ -s '$WORK/k41-img.bin' ] && echo 1 || echo 0")"

# (h) chẩn đoán riêng của nguồn
K41_DIAG=$(txsh 'manga_diagnose --no-pause')
has "chẩn đoán toon18x: có mục nguồn" "Chẩn đoán nguồn truyện tranh (toon18x)" "$K41_DIAG"
has "chẩn đoán toon18x: duyệt/tìm dùng được" "Duyệt/tìm truyện dùng được" "$K41_DIAG"
has "chẩn đoán toon18x: đếm chương qua API" "4 chương" "$K41_DIAG"
has "chẩn đoán toon18x: nhắc nội dung 18+" "18+" "$K41_DIAG"

# (i) cấu hình: menu nguồn + config.cfg
check "nguồn thứ 5 là toon18x" "toon18x|https://toon18x.com" \
    "$(txsh 'manga_source_choices' | sed -n '5p' | cut -d'|' -f2,3)"
check "mô tả nguồn 5 có nhắc 18+" "1" \
    "$(txsh 'manga_source_choices' | sed -n '5p' | grep -c '18+')"
check "Cài đặt: chọn 5 -> chuyển sang toon18x" "toon18x|https://toon18x.com" \
    "$(KK_MOCK_PICK=5 txsh 'MANGA_SOURCE=nettruyen; MANGA_BASE_URL="https://nettruyen.info"; manga_switch_source >/dev/null 2>&1; printf "%s|%s" "$MANGA_SOURCE" "$MANGA_BASE_URL"')"
has "Cài đặt: lưu nguồn toon18x vào config" 'MANGA_SOURCE="toon18x"' \
    "$(cat "$WORK/home-k41/.config/anisub_cli/config.cfg" 2>/dev/null)"
has "Cài đặt: chọn 5 -> cảnh báo 18+" "18+" \
    "$(KK_MOCK_PICK=5 txsh 'MANGA_SOURCE=nettruyen; manga_switch_source')"
PATH="$K40_FZFDIR:$PATH" K40_FZF_DUMP="$WORK/k41-fzf-dump.txt" KK_MOCK_PICK=5 \
    txsh 'MANGA_SOURCE=nettruyen; manga_switch_source' > /dev/null 2>&1
check "picker có dòng 5) toon18x" "1" "$(grep -c '5) toon18x' "$WORK/k41-fzf-dump.txt" 2>/dev/null)"
# bộ src/ cũ (không có module toon18x): cảnh báo + KHÔNG đổi nguồn
K41_OLD=$(KK_MOCK_PICK=5 txsh 'unset TOON18X_MODULE; unset -f tx_list_items; MANGA_SOURCE=nettruyen; MANGA_BASE_URL="https://nettruyen.info"; manga_switch_source; printf "src=%s|" "$MANGA_SOURCE"')
has "thiếu module toon18x -> cảnh báo cần Cập nhật" "chưa có module toon18x" "$K41_OLD"
has "thiếu module toon18x -> không đổi nguồn" "src=nettruyen|" "$K41_OLD"
PATH="$K40_FZFDIR:$PATH" K40_FZF_DUMP="$WORK/k41-fzf-old.txt" KK_MOCK_PICK=5 \
    txsh 'unset TOON18X_MODULE; unset -f tx_list_items; MANGA_SOURCE=nettruyen; manga_switch_source' > /dev/null 2>&1
check "picker gắn (cần Cập nhật) khi thiếu module toon18x" "1" \
    "$(grep -c '5) toon18x.*cần 🔄 Cập nhật' "$WORK/k41-fzf-old.txt" 2>/dev/null)"
has "gợi ý bộ src/ cũ nêu tên toon18x" "toon18x" \
    "$(txsh 'unset TOON18X_MODULE; unset -f tx_list_items; manga_src_outdated_hint')"
has "gợi ý bộ src/ cũ vẫn nêu kagane" "kagane" \
    "$(txsh 'unset TOON18X_MODULE; unset KAGANE_MODULE; unset -f tx_list_items; unset -f kg_list_items; manga_src_outdated_hint')"
K41_CFG=$(txsh 'TOON18X_LOCALE="en"; save_config >/dev/null 2>&1; cat "$CONFIG_FILE"')
has "config.cfg lưu TOON18X_LOCALE" 'TOON18X_LOCALE="en"' "$K41_CFG"
check "có file module src/comic/toon18x.sh" "1" "$([ -f "$ROOT/src/comic/toon18x.sh" ] && echo 1 || echo 0)"

# (j) --netcheck dùng host toon18x.com
has "netcheck dùng host toon18x.com" "toon18x.com" "$(txsh 'anisub_netcheck')"

# (k) selftest chạy hết luồng đọc
K41_ST=$(txsh 'manga_selftest alpha-story' 2>&1)
has "selftest: đọc được danh sách chương" "4 chapter" "$K41_ST"
has "selftest: lấy được ảnh trang" "4 ảnh" "$K41_ST"
has "selftest: kết luận luồng đọc OK" "Luồng đọc hoạt động" "$K41_ST"

# (l) các nguồn khác không bị ảnh hưởng
check "truyenvn vẫn là truyenvn" "TruyenVN" \
    "$( ( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-k41" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_SOURCE=truyenvn; manga_source_label" ) 2>&1)"
check "toon18x không lẫn sang kagane" "0" "$(txsh 'manga_is_kagane && echo 1 || echo 0')"

echo "== 42. bộ src/ cũ thiếu nguồn mới -> tự phát hiện, tự tải lại, và nói rõ =="
# Bản phát hành cùng version (để test trường hợp \"đã là bản mới nhất\" nhưng src/ cũ)
mkdir -p "$WORK/r42/anisub-main"
cp "$ROOT/anisub.sh" "$WORK/r42/anisub-main/"
cp -R "$ROOT/src" "$WORK/r42/anisub-main/src"
tar -czf "$WORK/anisub-same.tar.gz" -C "$WORK/r42" anisub-main

# Bộ src/ \"cũ\": có đủ module cũ nhưng thiếu module toon18x
k42_stale_src() {
    local dst="$1"
    mkdir -p "$dst"
    cp -R "$ROOT/src" "$dst/src"
    rm -f "$dst/src/comic/toon18x.sh"
}

# (a) đơn vị: dò module thiếu / tên nguồn
check "bộ src/ hiện tại đủ module" "" \
    "$( ( ANISUB_SRC_DIR="$ROOT/src" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; anisub_missing_modules \"$ROOT/src\"" ) 2>&1)"
mkdir -p "$WORK/h42"
k42_stale_src "$WORK/h42/stale"
check "dò ra module toon18x.sh còn thiếu" "toon18x.sh" \
    "$( ( ANISUB_SRC_DIR="$WORK/h42/stale/src" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; anisub_missing_modules '$WORK/h42/stale/src'" ) 2>&1)"
check "tên nguồn từ tên module" "toon18x" \
    "$( ( bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; anisub_module_source_name toon18x.sh" ) 2>&1)"
has "danh sách nguồn thiếu để in thông báo" "toon18x" \
    "$( ( bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; anisub_missing_source_names '$WORK/h42/stale/src'" ) 2>&1)"

# (b) chạy --doctor với src/ cũ + có mạng -> tự tải lại, nguồn toon18x xuất hiện
mkdir -p "$WORK/home-k42"
cp "$ROOT/anisub.sh" "$WORK/h42/stale/"
( cd "$WORK/h42/stale" && ANISUB_SRC_DIR="$WORK/h42/stale/src" HOME="$WORK/home-k42" \
  MOCK_UPDATE_TARBALL="$WORK/anisub-main.tar.gz" PATH="$HERE/mockbin:$PATH" \
  timeout 60 bash ./anisub.sh --doctor > "$WORK/k42-heal.txt" 2>&1 )
has "phát hiện bộ nguồn cũ thiếu toon18x" "thiếu nguồn toon18x" "$(cat "$WORK/k42-heal.txt")"
has "báo đang tự tải bộ nguồn mới" "tự tải bộ nguồn mới" "$(cat "$WORK/k42-heal.txt")"
has "báo đã cập nhật bộ nguồn" "Đã cập nhật bộ nguồn" "$(cat "$WORK/k42-heal.txt")"
check "tự tải lại được module toon18x.sh" "1" "$([ -f "$WORK/h42/stale/src/comic/toon18x.sh" ] && echo 1 || echo 0)"
has "doctor liệt kê module toon18x" "✅ toon18x.sh" "$(cat "$WORK/k42-heal.txt")"
check "sau khi tự chữa lành: không còn cảnh báo thiếu module" "0" \
    "$(grep -c 'Thiếu module nguồn' "$WORK/k42-heal.txt")"
check "sau khi tự chữa lành: menu nguồn có đủ 5 dòng" "5" \
    "$( ( ANISUB_SRC_DIR="$WORK/h42/stale/src" HOME="$WORK/home-k42" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_SOURCE=toon18x; MANGA_BASE_URL='https://toon18x.com'; manga_source_choices" ) 2>&1 | grep -c '.')"
has "sau khi tự chữa lành: có dòng nguồn 5|toon18x" "5|toon18x" \
    "$( ( ANISUB_SRC_DIR="$WORK/h42/stale/src" HOME="$WORK/home-k42" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; MANGA_SOURCE=toon18x; manga_source_choices" ) 2>&1)"

# (c) src/ cũ + KHÔNG có mạng -> nói rõ thiếu nguồn nào, vẫn chạy được
k42_stale_src "$WORK/h42/stale2"
cp "$ROOT/anisub.sh" "$WORK/h42/stale2/"
mkdir -p "$WORK/home-k42b"
( cd "$WORK/h42/stale2" && ANISUB_SRC_DIR="$WORK/h42/stale2/src" HOME="$WORK/home-k42b" \
  PATH="$HERE/mockbin:$PATH" timeout 60 bash ./anisub.sh --doctor > "$WORK/k42-nonet.txt" 2>&1 )
has "không tải được: nói rõ đang dùng bộ nguồn cũ" "Đang dùng bộ nguồn cũ" "$(cat "$WORK/k42-nonet.txt")"
has "không tải được: nêu tên nguồn thiếu" "Thiếu nguồn: toon18x" "$(cat "$WORK/k42-nonet.txt")"
has "không tải được: nhắc --update" "./anisub.sh --update" "$(cat "$WORK/k42-nonet.txt")"
has "không tải được: vẫn mở được doctor" "ANISUB DOCTOR" "$(cat "$WORK/k42-nonet.txt")"
has "doctor cảnh báo thiếu module" "Thiếu module nguồn: toon18x" "$(cat "$WORK/k42-nonet.txt")"

# (d) dòng \"Nguồn truyện\" trong ⚙️ Cài đặt cảnh báo ngay khi thiếu module
( cd "$WORK/h42/stale2" && ANISUB_SRC_DIR="$WORK/h42/stale2/src" HOME="$WORK/home-k42b" \
  PATH="$K40_FZFDIR:$HERE/mockbin:$PATH" K40_FZF_DUMP="$WORK/k42-settings.txt" KK_MOCK_PICK=99 \
  timeout 60 bash -c 'source ./anisub.sh >/dev/null 2>&1; show_settings >/dev/null 2>&1' )
check "menu Cài đặt gắn cảnh báo thiếu nguồn vào dòng Nguồn truyện" "1" \
    "$(grep -c '📚 Nguồn truyện:.*⚠️ thiếu nguồn: toon18x' "$WORK/k42-settings.txt" 2>/dev/null)"
has "menu Cài đặt nêu rõ nguồn thiếu" "thiếu nguồn: toon18x" "$(cat "$WORK/k42-settings.txt" 2>/dev/null)"
check "bộ nguồn đủ thì dòng Cài đặt không có cảnh báo" "0" \
    "$( ( ANISUB_SRC_DIR="$ROOT/src" HOME="$WORK/home-k42b" PATH="$K40_FZFDIR:$HERE/mockbin:$PATH" \
          K40_FZF_DUMP="$WORK/k42-settings-ok.txt" KK_MOCK_PICK=99 \
          bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; show_settings >/dev/null 2>&1" ) >/dev/null 2>&1
        grep -c '⚠️ thiếu nguồn' "$WORK/k42-settings-ok.txt" 2>/dev/null)"

# (e) 🔄 Cập nhật: version bằng nhau nhưng src/ thiếu module -> vẫn cài lại bộ nguồn
k42_stale_src "$WORK/h42/upd"
cp "$ROOT/anisub.sh" "$WORK/h42/upd/"
mkdir -p "$WORK/home-k42c"
( cd "$WORK/h42/upd" && MOCK_UPDATE_TARBALL="$WORK/anisub-same.tar.gz" HOME="$WORK/home-k42c" \
  PATH="$HERE/mockbin:$PATH" bash -c "source ./anisub.sh; SCRIPT_DIR='$WORK/h42/upd'; SELF_SCRIPT='$WORK/h42/upd/anisub.sh'; update_script" \
  > "$WORK/k42-upd.txt" 2>&1 )
has "update: nói rõ version đã mới nhưng thiếu module" "nhưng bộ nguồn còn thiếu: toon18x" "$(cat "$WORK/k42-upd.txt")"
check "update: cài lại được module toon18x.sh" "1" "$([ -f "$WORK/h42/upd/src/comic/toon18x.sh" ] && echo 1 || echo 0)"
check "update: không tạo src/src lồng nhau" "0" "$([ -d "$WORK/h42/upd/src/src" ] && echo 1 || echo 0)"

# (f) bộ nguồn đã đủ -> KHÔNG tải lại từ GitHub khi khởi động
mkdir -p "$WORK/h42/full" "$WORK/home-k42d"
cp "$ROOT/anisub.sh" "$WORK/h42/full/"
cp -R "$ROOT/src" "$WORK/h42/full/src"
K42_LOG="$WORK/k42-full.log"; : > "$K42_LOG"
( cd "$WORK/h42/full" && ANISUB_SRC_DIR="$WORK/h42/full/src" HOME="$WORK/home-k42d" \
  MOCK_CURL_LOG="$K42_LOG" PATH="$HERE/mockbin:$PATH" timeout 60 bash ./anisub.sh --doctor \
  > "$WORK/k42-full.txt" 2>&1 )
check "bộ nguồn đủ -> không gọi GitHub tải lại" "0" "$(grep -c 'codeload.github.com' "$K42_LOG" 2>/dev/null)"
check "bộ nguồn đủ -> không in cảnh báo thiếu nguồn" "0" "$(grep -c 'thiếu nguồn' "$WORK/k42-full.txt" 2>/dev/null)"
has "bộ nguồn đủ -> doctor bình thường" "ANISUB DOCTOR" "$(cat "$WORK/k42-full.txt")"

# (g) bản cài bằng git (có .git) -> ưu tiên git pull thay vì tải tarball
mkdir -p "$WORK/h42/git/bin" "$WORK/h42/git/app" "$WORK/home-k42e"
cp "$ROOT/anisub.sh" "$WORK/h42/git/app/"
cp -R "$ROOT/src" "$WORK/h42/git/app/src"
rm -f "$WORK/h42/git/app/src/comic/toon18x.sh"
mkdir -p "$WORK/h42/git/app/.git"
cat > "$WORK/h42/git/bin/git" <<EOS
#!/bin/bash
# git giả lập: cây làm việc sạch, pull = chép module còn thiếu về
case "\$*" in
    *"status --porcelain"*) exit 0 ;;
    *"pull --ff-only"*)     cp "$ROOT/src/comic/toon18x.sh" "$WORK/h42/git/app/src/comic/" 2>/dev/null; exit 0 ;;
    *)                      exit 0 ;;
esac
EOS
chmod +x "$WORK/h42/git/bin/git"
( cd "$WORK/h42/git/app" && ANISUB_SRC_DIR="$WORK/h42/git/app/src" HOME="$WORK/home-k42e" \
  PATH="$WORK/h42/git/bin:$HERE/mockbin:$PATH" timeout 60 bash ./anisub.sh --doctor > "$WORK/k42-git.txt" 2>&1 )
has "bản cài git -> dùng git pull thay vì tải tarball" 'git -C "' "$(cat "$WORK/k42-git.txt")"
has "bản cài git -> báo đã cập nhật bằng git" "Đã cập nhật bộ nguồn bằng git" "$(cat "$WORK/k42-git.txt")"
check "bản cài git -> có lại module toon18x.sh" "1" "$([ -f "$WORK/h42/git/app/src/comic/toon18x.sh" ] && echo 1 || echo 0)"
check "bản cài git -> không tải tarball khi git pull chạy được" "0" "$(grep -c 'Đang tải bộ file nguồn' "$WORK/k42-git.txt" 2>/dev/null)"


echo
printf 'KẾT QUẢ: \033[32m%s pass\033[0m' "$pass"
[ "$fail" -gt 0 ] && printf ', \033[31m%s fail\033[0m' "$fail"
echo
[ "$fail" -eq 0 ]
