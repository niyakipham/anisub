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
: > "$MOCK_CURL_LOG"; : > "$MOCK_FZF_LOG"; : > "$MOCK_READ_LOG"
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
check "MANGA_BASE_URL mặc định" "https://truyenvn.my" "$MANGA_BASE_URL"
check "feeds mặc định" "latest,trending,views" "$MANGA_SEARCH_FEEDS"
check "pages mặc định" "1" "$MANGA_SEARCH_PAGES"
save_config > /dev/null
has "config.cfg lưu MANGA_BASE_URL" 'MANGA_BASE_URL="https://truyenvn.my"' "$(cat "$CONFIG_FILE")"
mkdir -p "$WORK/home2/.config/anisub_cli"
printf 'PLAYER="mpv"\n' > "$WORK/home2/.config/anisub_cli/config.cfg"   # config cũ, chưa có key manga
( HOME="$WORK/home2" bash -c "source '$WORK/lib.sh' >/dev/null 2>&1; load_config >/dev/null 2>&1; [ \"\$MANGA_BASE_URL\" = https://truyenvn.my ]" ) \
    && ok "config cũ thiếu key -> vẫn dùng default" || bad "config cũ thiếu key" "https://truyenvn.my" "khác"

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

echo
printf 'KẾT QUẢ: \033[32m%s pass\033[0m' "$pass"
[ "$fail" -gt 0 ] && printf ', \033[31m%s fail\033[0m' "$fail"
echo
[ "$fail" -eq 0 ]
