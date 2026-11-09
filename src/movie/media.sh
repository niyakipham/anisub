# ═══════════════════════════════════════════════════════════════════════════════
# PHIM: TIỆN ÍCH MEDIA (tải / cắt / ghép video, mở link, xem file local)
# ═══════════════════════════════════════════════════════════════════════════════
# Tách riêng khỏi phần "nguồn phim" để code chính gọn hơn; các hàm ở đây chỉ dùng
# ffmpeg/curl nên không phụ thuộc KKPhim.

# Mở URL bằng trình duyệt mặc định (dùng cho trang phim / trang embed của KKPhim)
open_url() {
    local url="$1"
    [ -z "$url" ] && return 1
    echo "🌐 $url"
    if command -v xdg-open &> /dev/null; then
        xdg-open "$url" > /dev/null 2>&1 &
    elif command -v open &> /dev/null; then
        open "$url" > /dev/null 2>&1 &
    else
        echo "(Không tìm thấy xdg-open/open - hãy copy link và mở thủ công.)"
        sleep 2
    fi
}

# --- MEDIA PROCESSING FUNCTIONS ---
download_video() {
    local url="$1"
    local filename="$2"
    local folder="$DOWNLOAD_DIR/$(echo "$filename" | awk -F' - ' '{print $1}')"
    
    mkdir -p "$folder"
    safe_name=$(echo "$filename" | sed 's/[^a-zA-Z0-9 .-]/_/g')
    
    echo "Đang tải xuống: $safe_name... (nguồn: $SOURCE_NAME)"
    if command -v yt-dlp &> /dev/null; then
        yt-dlp --referer "$KKPHIM_REFERER" --user-agent "$KKPHIM_USER_AGENT" \
            "$url" -o "$folder/$safe_name.mp4"
    else
        ffmpeg -hide_banner -loglevel error -headers "$KKPHIM_FFMPEG_HEADERS" \
            -protocol_whitelist "file,http,https,tcp,tls,crypto" -allowed_extensions ALL \
            -i "$url" -c copy -bsf:a aac_adtstoasc "$folder/$safe_name.mp4"
    fi
    echo "Đã tải xong: $folder/$safe_name.mp4"
    sleep 2
}

cut_video_logic() {
    local input_url="$1"
    local mode="$2"
    local dest_dir="$DOWNLOAD_DIR/cut"
    mkdir -p "$dest_dir"

    # Link của $SOURCE_NAME là HLS trực tuyến: ffmpeg cần Referer + whitelist protocol
    local -a input_args=()
    case "$input_url" in
        http*)
            input_args=(-headers "$KKPHIM_FFMPEG_HEADERS"
                        -protocol_whitelist "file,http,https,tcp,tls,crypto"
                        -allowed_extensions ALL)
            ;;
    esac

    echo "=== CHẾ ĐỘ CẮT VIDEO (Fix lỗi hình ảnh) ==="
    echo "Lưu ý: Nhập chính xác thời gian trên trình phát đang xem."
    
    if [ "$mode" == "single" ]; then
        read -r -p "Nhập thời gian bắt đầu (VD: 00:10:30): " start_time
        read -r -p "Nhập thời gian kết thúc (VD: 00:11:00): " end_time
        output_name="cut_$(date +%s).mp4"
        
        echo "Đang xử lý (Re-encoding)..."
        ffmpeg "${input_args[@]}" -i "$input_url" -ss "$start_time" -to "$end_time" \
            -c:v libx264 -preset fast -crf 23 -c:a aac \
            "$dest_dir/$output_name" -hide_banner -loglevel error
        
        echo "Xong! File lưu tại: $dest_dir/$output_name"
    
    elif [ "$mode" == "multi" ]; then
        read -r -p "Số lượng đoạn cần cắt: " count
        for ((i=1; i<=count; i++)); do
            echo "--- Đoạn $i ---"
            read -r -p "Bắt đầu (HH:MM:SS): " start_t
            read -r -p "Kết thúc (HH:MM:SS): " end_t
            output_name="cut_${i}_$(date +%s).mp4"
            
            echo "Đang xử lý đoạn $i..."
            ffmpeg "${input_args[@]}" -i "$input_url" -ss "$start_t" -to "$end_t" \
                -c:v libx264 -preset fast -crf 23 -c:a aac \
                "$dest_dir/$output_name" -hide_banner -loglevel error

            echo "Đã lưu đoạn $i: $output_name"
        done
        echo "Hoàn tất cắt nhiều đoạn."
    fi
    sleep 3
}

merge_video_logic() {
    local cut_dir="$DOWNLOAD_DIR/cut"
    local merge_dir="$DOWNLOAD_DIR/merged"
    mkdir -p "$merge_dir"
    
    if [ -z "$(ls -A "$cut_dir")" ]; then
        echo "Thư mục '$cut_dir' trống. Hãy cắt video trước."
        sleep 2
        return
    fi

    echo "Chọn các video để ghép (TAB để chọn nhiều, ENTER xác nhận):"
    cd "$cut_dir" || return
    selected_files=$(find . -maxdepth 1 -name "*.mp4" | sed 's|^\./||' | fzf -m --prompt="Chọn file để ghép > ")
    
    if [ -z "$selected_files" ]; then
        return
    fi

    list_txt="$cut_dir/merge_list.txt"
    > "$list_txt"
    
    echo "File đã chọn:"
    while IFS= read -r file; do
        echo "file '$file'" >> "$list_txt"
        echo " - $file"
    done <<< "$selected_files"
    
    output_name="merged_$(date +%s).mp4"
    echo "Đang ghép video..."
    ffmpeg -f concat -safe 0 -i "$list_txt" -c copy "$merge_dir/$output_name" -hide_banner -loglevel error
    
    rm "$list_txt"
    echo "Xong! Video ghép lưu tại: $merge_dir/$output_name"
    sleep 3
}

# --- LOCAL FILE HANDLER ---
play_anidata_local() {
    echo "Kiểm tra dữ liệu Local tại: $LOCAL_DATA_FILE"
    
    if [ ! -f "$LOCAL_DATA_FILE" ]; then
        echo "Đang tải dữ liệu mới..."
        local data_url="https://raw.githubusercontent.com/niyakipham/anisub/refs/heads/main/assets/aniw_export_2026-01-14.csv"
        mkdir -p "$SCRIPT_DIR/assets"
        curl -L "$data_url" -o "$LOCAL_DATA_FILE"
        if [ ! -f "$LOCAL_DATA_FILE" ]; then
            echo "Lỗi: Không tải được file dữ liệu."
            sleep 2; return
        fi
    fi

    local anime_list=$(sed '1d;s/"//g' "$LOCAL_DATA_FILE" | awk -F',' '{print $1}' | sort -u)
    local selected_anime=$(echo "$anime_list" | fzf --prompt="[Local] Chọn Anime: ")
    if [ -z "$selected_anime" ]; then return; fi

    local episodes=$(grep "^\"${selected_anime}\"," "$LOCAL_DATA_FILE" | sed 's/"//g' | awk -F',' '{print "Tập " $2 "|" $4}')
    if [ -z "$episodes" ]; then
         episodes=$(grep "^${selected_anime}," "$LOCAL_DATA_FILE" | sed 's/"//g' | awk -F',' '{print "Tập " $2 "|" $4}')
    fi

    local selected_line=$(echo "$episodes" | fzf --prompt="Chọn tập: " --delimiter='|' --with-nth=1)
    if [ -n "$selected_line" ]; then
         local ep_name=$(echo "$selected_line" | cut -d'|' -f1)
         local link=$(echo "$selected_line" | cut -d'|' -f2 | tr -d '[:space:]')
         
         add_to_history "$selected_anime (Local)" "$ep_name" "$link"
         manage_currently_playing "$selected_anime" "$ep_name" "$link" "$episodes" "local_file"
    fi
}
