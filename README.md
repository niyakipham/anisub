<div align = center>
    <a href="https://discord.gg/AYbJ9MJez7">
<img alt="Dynamic JSON Badge" src="https://i.pinimg.com/736x/07/9d/5f/079d5fb88985798fe0f88d1731c1fa6d.jpg">
    </a>
</div>

<br>
<div align = center>
  <a href="#FEARTURE"><kbd> <br> FEARTURE <br> </kbd></a>&ensp;&ensp;
  <a href="#INSTALL"><kbd> <br> INSTALL <br> </kbd></a>&ensp;&ensp;
  <a href="#RUN"><kbd> <br> RUN <br> </kbd></a>&ensp;&ensp;
  <a href="#CONTACT"><kbd> <br> CONTACT <br> </kbd></a>&ensp;&ensp;
</div>
<br>

## Hi Everyone 👋

[![Anisub on J2TEAM Launch](https://launch.j2team.dev/badge/anisub/light)](https://launch.j2team.dev/products/anisub) <br>

### DONATE
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://buymeacoffee.com/niyakiphamn)
<br>

## DỰ KIẾN
《🔝》- Thêm level để leo rank<br>
《🪟》- Chạy trên windows<br>
## UPDATE
《🔒》- **DNS nhà mạng chặn e-hentai**: anisub tự hỏi IP qua **DNS-over-HTTPS** (cloudflare-dns.com → dns.google) rồi nối thẳng bằng `--resolve`, nhớ IP cho lần sau; tắt bằng `MANGA_DOH="off"`<br>
《🩺》- Thêm `./anisub.sh --netcheck [host]`: kiểm tra **từng lớp** DNS hệ thống → DoH → HTTPS/TLS để biết bị chặn ở đâu (DNS / IP / SNI), kèm cách sửa (`resolvectl`, VPN, proxy)<br>
《🧦》- Thêm `MANGA_PROXY` cho phần truyện (vd `socks5h://127.0.0.1:1080`); vẫn dùng được `export https_proxy=...` như curl<br>
《🌐》- **e-hentai không tải được (HTTP 000)** giờ nói rõ nguyên nhân theo mã lỗi curl (DNS / không kết nối / timeout / TLS) và cảnh báo e-hentai hay bị nhà mạng VN chặn; in **URL đầy đủ** thay vì `/?f_search=…`, và cho **bấm `1` để chuyển ngay sang nettruyen**; kết nối bị chặn giờ báo lỗi sau ~10s thay vì treo 30s<br>
《💾》- Sửa `save_config`: tự tạo `~/.config/anisub_cli` (trước đây lưu cài đặt **mất im lặng** nếu thư mục chưa có) và báo lỗi nếu không ghi được<br>
《🧾》- **📚 Đọc Truyện Tranh** giờ không im lặng nữa: nếu menu truyện không mở được, anisub nói rõ (đã vẽ menu chưa, fzf trả về gì), tự thử nạp/tải lại bộ nguồn ngay tại chỗ, và ghi lại dấu vết vào `~/.config/anisub_cli/cache/anisub-debug.log`<br>
《🩺》- `--doctor` in thêm môi trường (bash/fzf/TERM), commit git đang chạy + nhắc `git pull` khi chậm bản, và tình trạng các hàm chính (`manga_main_menu`, `fetch_chapter_list`, …)<br>
《🩺》- Sửa lỗi **không đọc được truyện tranh**: nếu máy chỉ có `anisub.sh` (thiếu `src/`) thì anisub **tự tải `src/` về** khi chạy, báo lỗi kèm cách sửa nếu không tải được, và có thêm `./anisub.sh --doctor` để chẩn đoán toàn bộ (module · phụ thuộc · nguồn truyện)<br>
《🔄》- Sửa **🔄 Cập nhật**: trước đây luôn báo "thiếu anisub.sh hoặc src/" (giải nén nhầm thư mục tạm) — giờ cập nhật đúng cả `anisub.sh` + `src/`<br>
《🔐》- `anisub.sh` được đặt quyền chạy (`chmod +x`) nên `./anisub.sh` chạy được ngay sau khi clone<br>
《📺》- Thêm gợi ý từ khóa<br>
《🧩》- Tách mã nguồn: `src/movie/` (nguồn phim) và `src/comic/` (nguồn truyện) — thêm nguồn mới chỉ cần thêm 1 file, code chính gọn còn ~1/6<br>
《🔞》- Thêm nguồn truyện **e-hentai** (`https://e-hentai.org`), mặc định xem tag `language:vietnamese`<br>
《🚫》- Gỡ tính năng chặn quảng cáo trong `.m3u8` (lọc playlist làm phim phát 3 giây lại khựng 3 giây): giờ phát thẳng link `.m3u8` gốc của KKPhim, mượt như trước<br>
《📺》- Thêm data từ kkphim, nguồn ophim sang dạng cào<br>
《📖》- Tích hợp truyenvn ( manga thì đọc oke còn webtoon thì như hạch ) <br>
《📖》- Đổi nguồn truyện sang `truyenvn.my`, sửa lỗi không tải được danh sách chapter / ảnh trang đọc<br>
《📖》- Sửa lỗi bấm **📚 Đọc Truyện Tranh** ở menu chính không mở được menu truyện (nhãn nguồn trong menu đổi thành động)<br>
《📖》- Chuyển nguồn truyện mặc định sang **nettruyen** (`nettruyen.info`): danh sách chapter đọc thẳng từ HTML, ảnh trang đọc trên `net.imgchapter.store`, có thêm `🔁 Đổi nguồn truyện` (nettruyen ⇄ truyenvn)<br>
《📖》- Truyện tranh: xem trước **ảnh bìa** khi chọn truyện, lấy **đủ danh sách chapter** (API `list-chapter`) và **ảnh trang đọc hiện ở mọi terminal**<br>
《✂》- Bổ sung cắt video 1 lần và cắt video nhiều lần<br>
《﬚》- Bổ sung tính năng ghép nhiều video với nhau <br>
#### Và còn nhiều tính năng khác!!! <br>
## FEARTURE

《👀》- Tìm kiếm Anime, hiển thị các bộ anime có cùng tư khóa liên quan <br>
《📺》- Ngoài ra bạn có thể xem được cả phim truyền hình từ Scripts này <br>
《✂》- Cắt video từ phút bao nhiêu đến phút bao nhiêu <br>
《🔗》- Tải video về thư mục tên Anime <br>
《👈》- Phát tập trước <br>
《👉》- Phát tập sau<br>

## NGUỒN PHIM

《🎬》- **KKPhim** — `https://kkphim.com` : tìm kiếm, danh mục, thông tin phim, server phụ đề và link `.m3u8` đều lấy từ API chính thức mà KKPhim công bố tại https://kkphim.com/api-document (base `https://phimapi.com`) <br>
《📚》- **nettruyen** — `https://nettruyen.info` : đọc truyện tranh (mặc định; cào HTML, danh sách chapter nằm sẵn trong trang, không cần API key) <br>
《📚》- **TruyenVN** — `https://truyenvn.my` : nguồn cũ, đổi lại được bằng `🔁 Đổi nguồn truyện` (cần API nội bộ `list-chapter`) <br>
《🔞》- **e-hentai** — `https://e-hentai.org` : gallery ảnh (18+), mặc định duyệt tag `language:vietnamese` <br>
《📂》- **Local Anidata** — `assets/aniw_export_2026-01-14.csv` : xem offline không cần mạng <br>

<br>

KKPhim đôi khi đổi domain frontend (`kkphim.com` ↔ `kkphim2.com`), khi đó chỉ cần sửa trong `~/.config/anisub_cli/config.cfg` (hoặc vào `⚙️ Cài đặt → 🎞 Nguồn phim`):

```shell
KKPHIM_SITE_URL="https://kkphim.com"   # trang web: poster, mở trình duyệt, Referer
KKPHIM_API_URL="https://phimapi.com"   # API RESTful của KKPhim
KKPHIM_CDN_URL="https://phimimg.com"   # CDN ảnh (dùng cho đường dẫn ảnh tương đối)
KKPHIM_REFERER="https://kkphim.com/"   # Referer gửi kèm khi phát / tải
KKPHIM_SEARCH_LIMIT="24"               # số kết quả mỗi trang
KKPHIM_DETAIL_TTL="600"                # giây cache thông tin phim
KKPHIM_SERVER_PREF="auto"              # auto | vietsub | long-tieng | thuyet-minh
```

**▶️ Phát phim.** Anisub phát **đúng link `.m3u8` gốc** mà API KKPhim trả về (kèm `Referer` /
`User-Agent` của `KKPHIM_REFERER`), không tải lại hay sửa playlist. Bản trước có thêm tính năng
"chặn quảng cáo" bằng cách lọc segment trong playlist, nhưng chính bước lọc đó làm phim phát 3 giây
lại khựng 3 giây, nên **đã gỡ hẳn** — quảng cáo (nếu có) nằm cùng CDN với phim và không thể bỏ
segment mà không làm hỏng luồng phát.


> **Lưu ý:** link `.m3u8` của KKPhim được cấp theo từng lần gọi API và hết hạn sau vài phút,
> nên anisub luôn xin lại link khi bạn xem lại từ lịch sử, đổi server, hoặc khi trình phát
> chết ngay sau khi mở (sẽ có menu gợi ý "🔄 Lấy link mới").

<br>

### 🔍 Tìm kiếm không ra phim?

Vào `⚙️ Cài đặt → 🎞 Nguồn phim (KKPhim) → 🩺 Kiểm tra kết nối & phụ thuộc`: anisub sẽ kiểm tra
`curl / grep / jq / fzf / awk / sed / chafa / perl`, thử gọi thật `phimapi.com/v1/api/tim-kiem`
và in mã HTTP + số kết quả nhận được (bản này chính là thứ bạn cần gửi kèm khi báo bug).

| Kết quả chẩn đoán | Nguyên nhân | Cách xử lý |
| --- | --- | --- |
| `HTTP 000` | máy không với được `phimapi.com` | kiểm tra mạng / DNS / proxy / VPN, thử mạng khác |
| `HTTP 403`, `429`, `5xx` | KKPhim chặn theo khu vực hoặc đang bảo trì | thử lại sau; nếu họ đổi host thì sửa `KKPHIM_API_URL` / `KKPHIM_SITE_URL` |
| `HTTP 200 · 0 kết quả` | từ khóa không khớp | thử gõ không dấu, hoặc tên tiếng Việt đầy đủ có dấu |
| fzf quá cũ (không có action `reload:`, cần `>= 0.19`) | `--bind` bị báo lỗi, cửa sổ tìm không mở | anisub **tự chuyển** sang chế độ nhập từ khóa 1 lần (Enter để tải danh sách, vẫn gõ để lọc trong kết quả) |

<br>

### 📚 Đọc truyện tranh (nettruyen)

Nguồn mặc định là **`https://nettruyen.info`** (banner của site tự ghi tên miền chính thức là
`nettruyenn.org`, đây là mirror — cứ `MANGA_BASE_URL` mà đổi khi domain thay đổi). Truyện nằm ở
`/truyen-<slug>`, chương ở `/truyen-<slug>/chuong-<n>` (`chuong-0`, `chuong-1.5` có thật), ảnh trang
đọc trên `https://net.imgchapter.store/<slug>/<chap>/page_<i>.jpg`.

Danh sách chương **nằm sẵn trong HTML** trang truyện (`#nt_listchapter`) nên không cần API/CSRF;
tìm kiếm dùng `/tim-kiem?keyword=…`, thể loại dùng `/the-loai/<slug>`.

```shell
MANGA_SOURCE="nettruyen"                       # nettruyen (mặc định) | truyenvn
MANGA_BASE_URL="https://nettruyen.info"        # nguồn truyện (đổi được khi site đổi domain)
MANGA_SEARCH_FEEDS="latest,trending,views"     # chỉ dùng cho nguồn truyenvn khi tìm
MANGA_SEARCH_PAGES="1"                         # số trang của mỗi bảng (1-5)
MANGA_IMAGE_SCALE="130"                        # % độ rộng ảnh so với terminal (100 = full)
MANGA_IMAGE_PROTOCOL="auto"                    # auto | symbols | kitty | sixel | iterm
MANGA_READER_PROXY="https://r.jina.ai"         # "" hoặc "off" để tắt (xem bên dưới)
MANGA_DOH="auto"                               # auto | off — tự hỏi IP qua DNS-over-HTTPS khi DNS nhà mạng chặn
MANGA_PROXY=""                                 # vd socks5h://127.0.0.1:1080 (v2rayN/clash/ssh -D); "" = dùng https_proxy
EHENTAI_TAG="language:vietnamese"              # tag mở ra đầu tiên của nguồn e-hentai
EHENTAI_CHUNK="20"                             # số trang ảnh gộp thành 1 "chapter" (5-100)
EHENTAI_COOKIE=""                              # cookie đăng nhập e-hentai (chỉ khi gallery cần)
```

Đổi nguồn không cần sửa file:
`⚙️ Cài đặt → 📚 Nguồn truyện → 🔁 Đổi nguồn truyện (nettruyen / truyenvn / e-hentai)`
(máy đang dùng config cũ chưa có `MANGA_SOURCE` sẽ tự chuyển sang nettruyen một lần).

**Ba chỗ hay hỏng và cách anisub xử lý** (áp dụng cho cả hai nguồn)

1. **Ảnh bìa khi chọn truyện** — mỗi dòng danh sách là `Tên|URL|slug|ảnh bìa`; fzf hiện
   khung preview bên phải (ảnh được cache ở `~/.config/anisub_cli/cache/manga-covers/`).
   Với nettruyen, bìa lấy từ `data-src` / `data-lazy-src` / `src` (`/images/<slug>.jpg`,
   `/storage/thumbnails/<slug>.jpg`) và được nhớ lại để bước chọn chapter cũng preview được.
2. **Danh sách chương trên nettruyen** — đọc thẳng HTML: mọi link `/truyen-<slug>/chuong-<n>`
   trong trang, gỡ trùng, sắp xếp tăng dần theo số chương (`1 < 1.5 < 2 < 10`), bỏ chapter của
   truyện khác lẫn trong sidebar. Trang đổi cấu trúc thì vẫn đọc được bằng `n`/`p` (link
   `Chap trước/Chap sau` ngay trên trang chapter) hoặc `Ctrl-G` để nhập số chapter.
   *(Nguồn truyenvn thì khác: trang chỉ nhúng 2 link `Đọc từ đầu` + `Chap mới nhất`, còn
   danh sách thật do JavaScript lấy từ `POST /webapi/stories/list-chapter`
   (body `story_id=…&routeName=story.detail`, header `X-CSRF-TOKEN` lấy từ
   `<meta name="csrf-token">`, có cookie phiên). anisub gọi đúng API đó, tự tải lại trang khi
   gặp `HTTP 419` (phiên của web chỉ sống 60 giây), API lỗi thì mới fallback về 2 chapter và
   cảnh báo rõ ra màn hình. Nếu trang không còn `"story_id"`, anisub suy id từ URL ảnh bìa
   (`/books/<id>/cover_*.jpg`); nếu slug trên URL khác slug trong link chapter thì tự dò slug
   xuất hiện nhiều nhất trong danh sách để không lẫn chapter của truyện khác.)*
3. **Ảnh trang đọc không hiện** — với nettruyen, anisub lấy mọi URL `/page_<i>.(jpg|png|webp)`
   trong trang đọc (ưu tiên `data-src`, rồi `data-lazy-src`, rồi `src`), sắp theo đúng số trang và
   bỏ logo/banner. Trang không trả ảnh thì thử **dịch vụ đọc hộ**, cuối cùng tự dò theo mẫu URL
   (`HEAD` từng `page_0..` và dừng sau 3 lần trượt).
   Với truyenvn, CDN ảnh (`*.imggo.net`) trả **403 với mọi request có
   `Referer`**, nên anisub tải ảnh **không kèm Referer** và kiểm tra magic bytes trước khi vẽ.
   Ngoài ra anisub không còn ép `sixel` cho mọi terminal: `MANGA_IMAGE_PROTOCOL=auto` tự nhận
   `kitty`/`sixel`/`iterm`, terminal lạ thì vẽ bằng ký tự (`symbols`) nên **luôn thấy hình**.

```shell
# xem nhanh mình đang ở giao thức nào
⚙️ Cài đặt → 📚 Nguồn truyện → 🖼️ Kiểu hiển thị ảnh     # hoặc sửa MANGA_IMAGE_PROTOCOL trong config.cfg
```

Sửa nhanh: `⚙️ Cài đặt → 📚 Nguồn truyện` (đổi domain / số bảng / số trang) hoặc
`🩺 Kiểm tra nhanh nguồn truyện` trong cùng menu — chẩn đoán sẽ in mã HTTP và số truyện
parse được từ trang thật.

Bộ thử nghiệm chạy offline (mock `curl`/`fzf` + HTML mẫu của cả hai nguồn, không cần mạng):

```shell
bash tests/run_tests.sh     # 230+ check: nettruyen (URL, tìm kiếm, chapter, ảnh page_N, tự dò ảnh, menu),
                           # truyenvn (API chapter 419/500, 4 kiểu tải, proxy), ảnh bìa, tìm kiếm,
                           # lịch sử / yêu thích, giao thức vẽ ảnh
```

> **Tìm kiếm dùng tham số nào?** Với nettruyen: `/tim-kiem?keyword=<từ khóa>` rồi lọc lại
> tại máy (site có lúc trả danh sách chung). Với `truyenvn.my`, `/tim-kiem` lọc thật ở server bằng
> **`?search=<từ khóa>`** (`?q=` / `?keyword=` bị bỏ qua, trả về cả 49k truyện).
> anisub gửi `?search=` trước; chỉ khi server không trả mục nào khớp mới quét thêm các bảng
> `m_orderby=latest|trending|views` rồi lọc **tại máy**; gõ dấu cách vẫn khớp
> (`bo chi` → `Bocchi`), không cần gõ dấu.
> Không thấy gì? vào `🔗 Mở bằng link / slug` và dán thẳng link truyện
> (`https://nettruyen.info/truyen-one-piece-dao-hai-tac`) là đọc được ngay; hoặc duyệt theo
> `🗂️ Thể loại`. Muốn tìm phủ nhiều truyện hơn thì tăng `MANGA_SEARCH_PAGES` lên `3`–`5`.
>
> Trong lúc đọc: `n` chap sau · `p` chap trước · `c` chọn chap khác · `r` tải lại ·
> `f` ⭐ · `q` thoát. Việc chuyển chap dựa vào link "Chap trước/Chap sau" của chính
> trang chapter, nên **không phụ thuộc** API danh sách chapter; `Ctrl-G` ở màn chọn
> chapter cho phép nhập thẳng số chapter muốn đọc (vd `120`, `9.5`).

**Bị chặn khi tải trang chapter?** Với nettruyen, anisub thử theo thứ tự: tải trực tiếp → dịch vụ
đọc hộ → tự dò mẫu URL ảnh, nên chỉ cần trang chapter còn mở được là sẽ ra ảnh.
Với TruyenVN, trang có lúc trả bản HTML rút gọn (không có `<img>`)
cho request "không giống trình duyệt". anisub tự thử lần lượt 4 kiểu tải:
`normal` → `minimal` (không cookie/referer) → `bot` (UA Googlebot) → **`proxy`**
(mặc định `https://r.jina.ai` đọc hộ bằng trình duyệt thật rồi trả markdown). Chỉ khi
kiểu trước không ra ảnh mới dùng kiểu sau. Tắt dịch vụ đọc hộ (không gửi link truyện ra
bên thứ ba): `⚙️ Cài đặt → 📚 Nguồn truyện → 🛡 Dịch vụ đọc hộ` hoặc đặt
`MANGA_READER_PROXY="off"` trong `~/.config/anisub_cli/config.cfg`.

**Bấm `📚 Đọc Truyện Tranh` mà không có gì xảy ra / menu truyện trống?** Gần như chắc là máy
đang thiếu thư mục `src/` (bản cài cũ chỉ có 1 file `anisub.sh`, hoặc `src/` bị xoá/di chuyển).
anisub sẽ tự tải `src/` về khi chạy; nếu mạng đang tắt thì chép lại cả repo. Kiểm tra bằng:

```shell
./anisub.sh --doctor        # in ra: script ở đâu · nạp module nào · thiếu gói gì · nguồn truyện nào
```

Chạy xong mà vẫn lỗi thì gửi nguyên kết quả:

```shell
./anisub.sh --doctor 2>&1 | tee anisub-doctor.txt
```

Kiểm tra nhanh toàn bộ luồng đọc: vào `📚 Truyện tranh` → **`🧪 Kiểm tra đọc truyện (chẩn đoán)`**
(kết quả được lưu vào `~/.config/anisub_cli/cache/manga-selftest.txt`), hoặc bằng **một lệnh**:

```shell
./anisub.sh --version                          # xem đang chạy bản nào
./anisub.sh --doctor                           # 🩺 kiểm tra module src/, phụ thuộc, nguồn truyện (tự tải src/ nếu thiếu)
./anisub.sh --netcheck e-hentai.org            # 🔒 bị chặn ở đâu: DNS hệ thống / DoH / IP / TLS — kèm cách sửa
tail -n 20 ~/.config/anisub_cli/cache/anisub-debug.log   # log mở menu truyện / lựa chọn của fzf
./anisub.sh --manga-selftest                   # tự chọn truyện mẫu theo nguồn đang dùng
./anisub.sh --manga-selftest one-piece-dao-hai-tac
# 1️⃣ trang truyện (HTTP + kích thước)  2️⃣ danh sách chapter (HTTP + số chapter)
# 3️⃣ trang chapter (số ảnh + link chap trước/sau)  4️⃣ tải thử 1 ảnh  5️⃣ chafa
```

| Kết quả | Nguyên nhân | Cách xử lý |
| --- | --- | --- |
| Bấm **📚 Đọc Truyện Tranh** nháy một cái rồi quay lại menu chính | fzf trả về rỗng (Esc, terminal quá thấp, hoặc fzf lỗi) | anisub đã báo rõ số lần fzf trả về; xem `~/.config/anisub_cli/cache/anisub-debug.log` (dòng `comic-menu:`) rồi gửi kèm khi báo lỗi |
| Bấm **📚 Đọc Truyện Tranh** không có gì xảy ra / menu truyện trống | thiếu thư mục `src/` (chỉ có `anisub.sh`, hoặc cập nhật dở) | chạy `./anisub.sh --doctor` (tự tải `src/` về); không có mạng thì `git clone https://github.com/NiyakiPham/anisub.git` |
| Đổi DNS rồi **vẫn** `HTTP 000` | nhà mạng chặn theo IP/SNI, không chỉ DNS | `./anisub.sh --netcheck e-hentai.org` để xem lớp nào bị chặn; DNS chặn thì anisub tự đi DoH, còn IP/SNI chặn thì cần VPN/proxy (`MANGA_PROXY`, `https_proxy`) |
| `HTTP 000` | không với được trang nguồn | anisub in kèm mã lỗi curl: `6` DNS (đổi DNS 1.1.1.1), `7` bị chặn/không kết nối, `28` timeout, `35/60` TLS. Với **e-hentai**: site hay bị nhà mạng VN chặn → bật VPN, hoặc bấm `1` để đổi sang nettruyen |
| `HTTP 403` / Cloudflare challenge | trang chặn client không phải trình duyệt | anisub đã gửi User-Agent trình duyệt; thử lại sau, hoặc đổi `MANGA_BASE_URL` sang domain mirror (nettruyen: `nettruyenn.org`, truyenvn: domain mới) |
| `❌ Không tìm thấy hình ảnh` khi đọc chapter nettruyen | trang đọc không trả `<img>` hoặc đổi host ảnh | chạy `./anisub.sh --manga-selftest <slug>`; xem `~/.config/anisub_cli/cache/manga-debug.txt`; bấm `o` để mở chapter bằng trình duyệt |
| `❌ Không lấy được danh sách chapter` | slug sai hoặc trang đổi layout | dùng `🔗 Mở bằng link / slug` dán link thật từ trình duyệt |
| Chỉ có ~2 chapter (đầu + cuối) | API `list-chapter` đổi đường dẫn / chặn | vẫn đọc được: chọn 1 chapter rồi dùng `n`/`p`, hoặc `Ctrl-G` để nhảy tới số chapter bất kỳ; chạy `./anisub.sh --manga-selftest <slug>` để xem HTTP của API |
| Trong chapter báo "Không tìm thấy hình ảnh" (anisub tự thử 4 kiểu: normal → minimal → bot → **dịch vụ đọc hộ**) | trang chapter trả bản không có `<img>` (Cloudflare / chỉ render bằng JS), hoặc site đổi markup | xem `~/.config/anisub_cli/cache/manga-debug.txt` (dòng `challenge:` và `img tags:`) — file này ghi HTTP, số thẻ `img`, số URL ảnh; gửi kèm khi báo lỗi. Trong lúc chờ, bấm `o` để mở chapter bằng trình duyệt |
| Không đọc được chapter / ảnh không hiện | chưa rõ bước hỏng | chạy `./anisub.sh --manga-selftest <slug>`: in ra HTTP + số chapter + số ảnh + tải thử 1 ảnh, chỉ đúng bước lỗi |
| Chọn truyện không thấy ảnh bìa | thiếu `chafa`, hoặc terminal không vẽ được ảnh | `sudo apt install chafa`; đổi `MANGA_IMAGE_PROTOCOL` sang `symbols` |
| Danh sách rỗng khi tìm | từ khóa quá ngắn / nằm ngoài các bảng đang quét | gõ ≥ 2 ký tự, tăng `MANGA_SEARCH_PAGES`, hoặc lọc theo `🗂️ Thể loại` |
| Ảnh đen / không hiện | thiếu `chafa`, hoặc giao thức vẽ ảnh không khớp terminal | `sudo apt install chafa` (hoặc `yay -S chafa`); đặt `MANGA_IMAGE_PROTOCOL=symbols` để chắc chắn thấy hình; `Enter` luôn mở ảnh bằng ứng dụng ngoài |

<br>


### 🔞 Đọc truyện trên e-hentai

Nguồn **`https://e-hentai.org`** (nội dung người lớn — 18+, bạn tự chịu trách nhiệm khi bật).
e-hentai là hệ **gallery ảnh**, nên anisub quy ước:

| Trên anisub | Trên e-hentai |
| --- | --- |
| 1 "truyện" | 1 gallery `https://e-hentai.org/g/<id>/<token>/` |
| 1 "chapter" | 1 nhóm trang ảnh (mặc định **20 trang**: `Trang 1–20/123`) |
| thể loại | tag (`language:vietnamese`, `language:vietnamese manga`, …) |

- **Danh sách mặc định** = tag `EHENTAI_TAG` (mặc định `language:vietnamese`) →
  `https://e-hentai.org/tag/language:vietnamese`. Đổi tag bằng
  `⚙️ Cài đặt → 📚 Nguồn truyện → 🏷 Tag mặc định (e-hentai)` hoặc chọn `🗂 Theo thể loại`.
- **Phân trang**: e-hentai dùng link `Next >` (`?next=<id>`) chứ không phải `?page=N`,
  nên menu duyệt của e-hentai tự đọc link "Next" từ trang vừa tải.
- **Đọc ảnh**: link ảnh thật chỉ có trong trang xem từng ảnh (`/s/<token>/<id>-<i>`, thẻ
  `<img id="img">`). Đọc 1 nhóm 20 trang = 20 request, anisub **cache** link ảnh ở
  `~/.config/anisub_cli/cache/ehentai/` nên lần sau mở lại gần như tức thì. Có delay
  `EHENTAI_DELAY` (mặc định 0.4s) giữa các request để không bị chặn "Excessive pageloads".
- **Gallery giới hạn/18+**: dán cookie đăng nhập vào
  `⚙️ Cài đặt → 📚 Nguồn truyện → 🍪 Cookie e-hentai` (F12 → Network → copy header `cookie`,
  thường có `ipb_member_id=…; ipb_pass_hash=…; sk=…`). Không có cookie vẫn xem được gallery
  công khai.
- **Lỗi hay gặp**: `Excessive pageloads` / IP bị khoá tạm → chờ 2-5 phút; trang báo cần đăng
  nhập → thêm cookie; `Không đọc được số trang của gallery` → kiểm tra lại link `/g/<id>/<token>/`.
- **Lịch sử / yêu thích** lưu gallery dạng `id/token` nên mở lại đúng gallery, đúng nhóm trang.

Gõ tay từ dòng lệnh:

```shell
MANGA_SOURCE=ehentai MANGA_BASE_URL=https://e-hentai.org ./anisub.sh --manga-selftest "https://e-hentai.org/g/4313400/7fcc76c845/"
```

### 🧩 Cấu trúc mã nguồn (src/)

Code đã tách khỏi 1 file duy nhất để dễ bảo trì. `anisub.sh` chỉ còn phần cấu hình, tiện ích,
lịch sử/yêu thích, cài đặt, menu chính và **bộ nạp module**:

```text
anisub.sh                 # khởi động + menu chính + nạp src/ (anisub_load_sources)
src/movie/kkphim.sh       # nguồn phim KKPhim: API, danh mục, server, tập, phát phim
src/movie/media.sh        # tải / cắt / ghép video, mở link, xem file local
src/comic/core.sh         # engine đọc truyện dùng chung (HTTP, ảnh, fzf, khung đọc, menu)
src/comic/nettruyen.sh    # nguồn nettruyen.info
src/comic/truyenvn.sh     # nguồn truyenvn.my
src/comic/ehentai.sh      # nguồn e-hentai.org
```

- Mọi file `src/movie/*.sh` và `src/comic/*.sh` được nạp tự động (theo tên file) —
  **thêm nguồn mới chỉ cần thêm 1 file**, không sửa `anisub.sh`.
- Chạy ở nơi khác (hoặc nhúng vào script khác): đặt `ANISUB_SRC_DIR=/duong/dan/src`.
- Nếu thiếu `src/` (ví dụ chỉ tải mỗi `anisub.sh`), anisub báo rõ và dừng — hãy clone cả repo.
- `🔄 Cập nhật` tải archive `main` của GitHub rồi cập nhật **cả** `anisub.sh` và `src/`.
- Test offline: `bash tests/run_tests.sh` (không cần mạng, mọi request đi qua `tests/mockbin`).

## INSTALL

UBUNTU
```shell
sudo apt install ffmpeg curl grep yt-dlp fzf pup jq mawk cut chafa mpv
```
Nếu có gói nào chưa đưọc cài đặt thì bạn cài riêng ra nhé <br>

ARCH LINUX
```shell
yay -S ffmpeg curl grep yt-dlp fzf pup manga-tui jq awk cutafa chafa mpv
```

## RUN

> ⚠️ Anisub giờ gồm nhiều file (`anisub.sh` + `src/`). Hãy **clone cả repo**, đừng tải mỗi
> `anisub.sh`: `git clone https://github.com/NiyakiPham/anisub.git && cd anisub`

Cấp quyền cho file
```shell
chmod +x anisub.sh
```

Chạy File
```shell
./anisub.sh
```

<br>

Nếu bạn đang dùng bashrc thì vào file bashrc, ở đây mình dùng zshrc các ví dụ bạn đang dùng bashrc thì nano bash hay vim,... sau đó gán lệnh này vô

```shell
alias anisub='bash $HOME/anilink/anisub.sh'
```
<br>

- Các bạn lưu File anisub.sh ở đâu thì trỏ nó đến đường dẫn đó nhé
- Lệnh alias cho phép ngụy trang câu lệnh ( do mình lười viết file install )
- Sau khi các bạn gán lệnh này vô bashrc hay zshrc thì khởi động lại máy cho chắc ăn
- Bạn mở terminal rồi gõ anisub
<br>
CHÚC CÁC BẠN THÀNH CÔNG

## CONTACT
Nếu trong quá trình thực hiện mà bạn gặp lỗi gì hãy liên hệ với mình qua FB. Cảm ơn các bạn đã đọc bài viết này, nếu thấy project này thú vị đừng quên cho mình xin một sao trên github để mình có động lực ra nhiều tính năng hay cho project này nha. CẢM ƠN CÁC CẬU

## LƯU Ý
WEB MÀ MÌNH ĐANG SỬ DỤNG CÓ CHỨA QC BỌN LÀM WEB TÍNH CẢ RỒI NÓ SẼ CHÈN MỘT SRC NHÚNG VÀO TỆP M3U8 KHI ĐẾN MỘT KHOẢNG TIME NÀO ĐÓ NÓ SẼ HIỆN QC NÊN NẾU BẠN CỐ TÌNH SKIP THÌ NÓ SẼ CHO CÁC BẠN XEM LẠI TỪ ĐÂU
