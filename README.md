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
《📺》- Thêm gợi ý từ khóa<br>
《📺》- Thêm data từ kkphim, nguồn ophim sang dạng cào<br>
《📖》- Tích hợp truyenvn ( manga thì đọc oke còn webtoon thì như hạch ) <br>
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
《📚》- **TruyenVN** — `https://truyenvn.shop` : đọc truyện tranh (cào HTML trực tiếp) <br>
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

> **Lưu ý:** link `.m3u8` của KKPhim được cấp theo từng lần gọi API và hết hạn sau vài phút,
> nên anisub luôn xin lại link khi bạn xem lại từ lịch sử, đổi server, hoặc khi trình phát
> chết ngay sau khi mở (sẽ có menu gợi ý "🔄 Lấy link mới").

<br>

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
