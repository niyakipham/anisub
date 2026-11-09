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

# Nạp các hàm của script (bỏ lời gọi "main" ở dòng cuối)
sed '$d' "$ROOT/anisub.sh" > "$WORK/lib.sh"
# shellcheck source=/dev/null
source "$WORK/lib.sh"

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
check "không còn gọi thẳng domain cũ" "0" "$(grep -c 'https://truyenvn\.shop' "$ROOT/anisub.sh")"
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
has "Cài đặt có mục bật/tắt dịch vụ đọc hộ" "Dịch vụ đọc hộ khi bị chặn" "$(grep -o 'Dịch vụ đọc hộ khi bị chặn' "$ROOT/anisub.sh" | head -1)"

echo "== 27. phiên bản & lối vào chẩn đoán =="
check "có nhãn phiên bản" "1" "$(printf '%s' "$ANISUB_VERSION" | grep -cE '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}[a-z0-9]*$')"
has "selftest in phiên bản để biết đang chạy bản nào" "anisub: $ANISUB_VERSION" "$(manga_selftest bocchi-the-rock 2>&1)"
check "CLI --version chạy được" "anisub $ANISUB_VERSION" "$(bash "$ROOT/anisub.sh" --version 2>/dev/null)"
has "menu truyện có mục chẩn đoán" "Kiểm tra đọc truyện (chẩn đoán)" "$(grep -o 'Kiểm tra đọc truyện (chẩn đoán)' "$ROOT/anisub.sh" | head -1)"


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
has "menu cài đặt có mục đổi nguồn" "Đổi nguồn truyện (nettruyen ⇄ truyenvn)" \
    "$(grep -o 'Đổi nguồn truyện (nettruyen ⇄ truyenvn)' "$ROOT/anisub.sh" | head -1)"
check "chẩn đoán ghi đúng nguồn" "1" \
    "$(nt manga_diagnose </dev/null 2>&1 | grep -c 'Chẩn đoán nguồn truyện tranh (nettruyen)')"
check "chẩn đoán đọc được trang chủ nettruyen" "1" \
    "$(nt manga_diagnose </dev/null 2>&1 | grep -c 'parse được 3 truyện')"
echo "== 32. bấm \"📚 Đọc Truyện Tranh\" phải mở được menu truyện =="
has "case menu chính dùng khớp mềm (nhãn nguồn đổi được)" '*"Đọc Truyện Tranh"*)' \
    "$(grep -o '\*"Đọc Truyện Tranh"\*)' "$ROOT/anisub.sh" | head -1)"
has "lời nhắc tìm kiếm theo nguồn, không hard-code TruyenVN" "cần tìm (%s)" \
    "$(grep -o 'cần tìm (%s)' "$ROOT/anisub.sh" | head -1)"
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


echo "== 33. chặn quảng cáo trong playlist m3u8 (KKPhim) =="
check "mặc định bật chặn quảng cáo" "1" "$(KKPHIM_AD_BLOCK=1 kkphim_ad_block_enabled && echo 1 || echo 0)"
check "tắt được bằng KKPHIM_AD_BLOCK=0" "0" "$(KKPHIM_AD_BLOCK=0 kkphim_ad_block_enabled && echo 1 || echo 0)"
check "ghép URL tuyệt đối (gốc /)" "https://cdn.phim.test/keys/k1.bin" \
    "$(kkphim_abs_url https://cdn.phim.test/hls/phim/high/index.m3u8 /keys/k1.bin)"
check "ghép URL tương đối theo thư mục playlist" "https://cdn.phim.test/hls/phim/high/002.ts" \
    "$(kkphim_abs_url https://cdn.phim.test/hls/phim/high/index.m3u8 002.ts)"
check "giữ nguyên URL tuyệt đối" "https://x.test/a.ts" \
    "$(kkphim_abs_url https://cdn.phim.test/hls/phim/high/index.m3u8 https://x.test/a.ts)"
check "link không phải m3u8 -> phát nguyên" "https://cdn.phim.test/vod/phim.mp4" \
    "$(KKPHIM_AD_BLOCK=1 kkphim_play_url https://cdn.phim.test/vod/phim.mp4)"

KKPHIM_AD_BLOCK=1 kkphim_play_url "https://cdn.phim.test/hls/phim/master.m3u8" > "$WORK/adfree.path" 2>/dev/null
adfree_file=$(cat "$WORK/adfree.path")
check "bật chặn -> trả về file playlist đã lọc" "1" "$(printf '%s' "$adfree_file" | grep -c 'anisub-adfree-.*\.m3u8$')"
check "file đã lọc tồn tại" "1" "$([ -s "$adfree_file" ] && echo 1 || echo 0)"
check "mặc định chọn variant ĐẦU TIÊN (low/, giống trình phát cũ)" "1" "$(grep -c 'hls/phim/low/002.ts' "$adfree_file")"
check "giữ đủ 3 segment phim" "3" "$(grep -cE '^https?://.*\.ts' "$adfree_file")"
check "bỏ segment preroll (ads.adtag.vn)" "0" "$(grep -ci 'preroll' "$adfree_file")"
check "bỏ segment quảng cáo (quangcao.vn)" "0" "$(grep -ci 'quangcao' "$adfree_file")"
check "bỏ marker CUE-OUT/CUE-IN" "0" "$(grep -c 'EXT-X-CUE' "$adfree_file")"
check "bỏ marker SCTE35" "0" "$(grep -ci 'SCTE35' "$adfree_file")"
check "giữ #EXT-X-ENDLIST" "1" "$(grep -c '#EXT-X-ENDLIST' "$adfree_file")"
check "#EXT-X-KEY được tuyệt đối hoá" "1" "$(grep -c 'URI="https://cdn.phim.test/keys/k1.bin"' "$adfree_file")"
check "query ?ad=0 không bị coi là quảng cáo" "1" "$(grep -c '003.ts?token=abc&ad=0' "$adfree_file")"
check "tên chứa 'media'/'shadow' không bị xoá nhầm" "1" "$(grep -c 'media/shadow/003.ts' "$adfree_file")"
check "tắt chặn -> trả lại link gốc" "https://cdn.phim.test/hls/phim/master.m3u8" \
    "$(KKPHIM_AD_BLOCK=0 kkphim_play_url https://cdn.phim.test/hls/phim/master.m3u8)"
check "tải playlist lỗi -> phát link gốc (không chặn được)" "https://manga-offline.test/x.m3u8" \
    "$(KKPHIM_AD_BLOCK=1 kkphim_play_url https://manga-offline.test/x.m3u8)"
rm -f "$adfree_file"

: > "$MOCK_CURL_LOG"
KKPHIM_AD_BLOCK=1 KKPHIM_AD_VARIANT=max kkphim_play_url "https://cdn.phim.test/hls/phim/master.m3u8" >/dev/null 2>&1
check "KKPHIM_AD_VARIANT=max -> lấy variant nặng nhất" "1" "$(grep -c 'high/index.m3u8' "$MOCK_CURL_LOG")"
: > "$MOCK_CURL_LOG"
KKPHIM_AD_BLOCK=1 kkphim_play_url "https://cdn.phim.test/hls/phim/master.m3u8" >/dev/null 2>&1
check "mặc định (first) -> chỉ tải variant đầu" "1" "$(grep -c 'low/index.m3u8' "$MOCK_CURL_LOG")"
kkphim_play_url "https://cdn.phim.test/hls/phim/aesnoiv.m3u8" > "$WORK/aes.out" 2>/dev/null
check "AES-128 không kèm IV -> không lọc (tránh hỏng phim)" "https://cdn.phim.test/hls/phim/aesnoiv.m3u8" "$(cat "$WORK/aes.out")"

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
has "cài đặt có mục chặn quảng cáo" "Chặn quảng cáo trong m3u8" \
    "$(grep -o 'Chặn quảng cáo trong m3u8' "$ROOT/anisub.sh" | head -1)"
has "config lưu KKPHIM_AD_BLOCK" 'KKPHIM_AD_BLOCK="' "$(save_config >/dev/null; cat "$CONFIG_FILE")"


echo "== 34. playlist kiểu live -> chuẩn hoá VOD (sửa lỗi phát 3s lại khựng 3s) =="
KKPHIM_AD_BLOCK=1 kkphim_play_url "https://cdn.phim.test/hls/phim/live.m3u8" > "$WORK/live.path" 2>/dev/null
live_file=$(cat "$WORK/live.path")
check "playlist thiếu ENDLIST -> thêm ENDLIST" "1" "$(grep -c '#EXT-X-ENDLIST' "$live_file")"
check "thêm PLAYLIST-TYPE:VOD" "1" "$(grep -c '#EXT-X-PLAYLIST-TYPE:VOD' "$live_file")"
check "giữ nguyên MEDIA-SEQUENCE gốc (IV của AES + byterange)" "1" "$(grep -c '^#EXT-X-MEDIA-SEQUENCE:120$' "$live_file")"
check "giữ nguyên DISCONTINUITY-SEQUENCE gốc" "1" "$(grep -c '^#EXT-X-DISCONTINUITY-SEQUENCE:4$' "$live_file")"
check "chèn #EXT-X-DISCONTINUITY tại chỗ cắt (gốc có 1, giờ 2)" "2" "$(grep -c '^#EXT-X-DISCONTINUITY$' "$live_file")"
check "DISCONTINUITY đứng TRƯỚC #EXTINF của segment kế tiếp" "#EXT-X-DISCONTINUITY" \
    "$(grep -B2 'seg-121.ts' "$live_file" | head -1)"
check "bỏ segment quảng cáo trong playlist live" "0" "$(grep -ci 'adtag' "$live_file")"
check "giữ 3 segment phim" "3" "$(grep -cE '^https?://.*\.ts' "$live_file")"
check "giữ #EXT-X-DISCONTINUITY gốc + chèn thêm ở chỗ cắt" "2" "$(grep -c '^#EXT-X-DISCONTINUITY$' "$live_file")"
check "VOD sẵn rồi thì không nhân đôi ENDLIST" "1" \
    "$(KKPHIM_AD_BLOCK=1 kkphim_play_url https://cdn.phim.test/hls/phim/master.m3u8 2>/dev/null | xargs grep -c '#EXT-X-ENDLIST')"
kkphim_ad_report "https://cdn.phim.test/hls/phim/live.m3u8" > "$WORK/adreport.txt" 2>&1
check "chẩn đoán chạy được" "0" "$?"
has "chẩn đoán đếm segment giữ/bỏ" "giữ 3 / bỏ 1" "$(cat "$WORK/adreport.txt")"
has "chẩn đoán chỉ ra playlist gốc kiểu live" "LIVE/thiếu ENDLIST" "$(cat "$WORK/adreport.txt")"
has "chẩn đoán liệt kê segment bị bỏ" "ads.adtag.vn/preroll/ad120.ts" "$(cat "$WORK/adreport.txt")"
check "lưu playlist gốc để đối chiếu" "1" "$([ -s "${CACHE_DIR}/kkphim-playlist-original.m3u8" ] && echo 1 || echo 0)"
check "lưu playlist đã lọc để đối chiếu" "1" "$([ -s "${CACHE_DIR}/kkphim-playlist-filtered.m3u8" ] && echo 1 || echo 0)"
has "CLI --kkphim-ad-debug chạy được" "giữ 3 / bỏ 1" \
    "$(bash "$ROOT/anisub.sh" --kkphim-ad-debug "https://cdn.phim.test/hls/phim/live.m3u8" 2>&1)"

echo
printf 'KẾT QUẢ: \033[32m%s pass\033[0m' "$pass"
[ "$fail" -gt 0 ] && printf ', \033[31m%s fail\033[0m' "$fail"
echo
[ "$fail" -eq 0 ]
