#!/bin/bash

# --- CONFIGURATION & DATA FILES ---
CONFIG_DIR="$HOME/.config/anisub_cli"
CONFIG_FILE="$CONFIG_DIR/config.cfg"
HISTORY_FILE="$CONFIG_DIR/history.log"
FAVORITES_FILE="$CONFIG_DIR/favorites.txt"
SCRIPT_URL="https://raw.githubusercontent.com/NiyakiPham/anisub/main/anisub.sh"

# Detect script location to find the local CSV file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DATA_FILE="$SCRIPT_DIR/assets/aniw_export_2026-01-14.csv"

# --- DEFAULTS ---
DEFAULT_PLAYER="mpv"
DEFAULT_DOWNLOAD_DIR="$HOME/Downloads/anime"
PLAYER=""
DOWNLOAD_DIR=""

# --- UTILITY FUNCTIONS ---
ensure_config_dir() {
    mkdir -p "$CONFIG_DIR"
}

load_config() {
    ensure_config_dir
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "PLAYER=$DEFAULT_PLAYER" > "$CONFIG_FILE"
        echo "DOWNLOAD_DIR=$DEFAULT_DOWNLOAD_DIR" >> "$CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
    PLAYER=${PLAYER:-$DEFAULT_PLAYER}
    DOWNLOAD_DIR=${DOWNLOAD_DIR:-$DEFAULT_DOWNLOAD_DIR}
    mkdir -p "$DOWNLOAD_DIR"
    touch "$HISTORY_FILE" "$FAVORITES_FILE"
}

save_config() {
    echo "PLAYER=$PLAYER" > "$CONFIG_FILE"
    echo "DOWNLOAD_DIR=$DOWNLOAD_DIR" >> "$CONFIG_FILE"
    echo "Cấu hình đã được lưu."
    sleep 1
}

check_dependencies() {
    local missing_deps=()
    local deps=("ffmpeg" "curl" "grep" "yt-dlp" "fzf" "pup" "jq" "awk" "cut" "sed")
    echo "Kiểm tra các phụ thuộc..."
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "LỖI: Thiếu các phụ thuộc sau: ${missing_deps[*]}"
        echo "Vui lòng cài đặt chúng."
        exit 1
    fi
}

# --- HISTORY FUNCTIONS ---
add_to_history() {
    local anime_name="$1"
    local episode_number="$2"
    local link="$3"
    sed -i "/|${anime_name}|${episode_number}|/d" "$HISTORY_FILE"
    echo "$(date +%Y-%m-%d\ %H:%M:%S)|${anime_name}|${episode_number}|${link}" >> "$HISTORY_FILE"
}

show_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo "Lịch sử xem trống."
        sleep 2
        return
    fi
    selected_history=$(tac "$HISTORY_FILE" | fzf --prompt="Lịch sử xem: " --delimiter='|' --with-nth=1,2,3)
    if [ -n "$selected_history" ]; then
        local link=$(echo "$selected_history" | cut -d'|' -f4)
        local anime_name=$(echo "$selected_history" | cut -d'|' -f2)
        local episode_number=$(echo "$selected_history" | cut -d'|' -f3)
        echo "Đang phát lại: $anime_name - Tập $episode_number..."
        "$PLAYER" "$link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window
    fi
}

# --- FAVORITES FUNCTIONS ---
add_to_favorites() {
    local anime_name="$1"
    local anime_url="$2"
    if grep -q "|$anime_url\$" "$FAVORITES_FILE"; then
        echo "'$anime_name' đã có trong danh sách yêu thích."
    else
        echo "$anime_name|$anime_url" >> "$FAVORITES_FILE"
        echo "'$anime_name' đã thêm vào danh sách yêu thích."
    fi
    sleep 2
}

show_favorites() {
    if [ ! -s "$FAVORITES_FILE" ]; then
        echo "Danh sách yêu thích trống."
        sleep 2
        return 1
    fi
    selected_favorite=$(fzf --prompt="Chọn anime yêu thích: " < "$FAVORITES_FILE")
    if [ -n "$selected_favorite" ]; then
        echo "$selected_favorite" | cut -d'|' -f2
        return 0
    else
        return 1
    fi
}

# --- SETTINGS & UPDATE ---
show_settings() {
    while true; do
        setting_option=$(echo -e "Trình phát hiện tại: $PLAYER\nThư mục tải xuống: $DOWNLOAD_DIR\nĐặt lại trình phát\nĐặt lại thư mục tải xuống\nQuay lại" | fzf --prompt="Cài đặt: ")
        case "$setting_option" in
            "Đặt lại trình phát")
                read -r -p "Nhập trình phát mới: " new_player
                if command -v "$new_player" &> /dev/null; then
                    PLAYER="$new_player"
                    save_config
                else
                    echo "Lỗi: Trình phát không tồn tại."
                    sleep 2
                fi
                ;;
            "Đặt lại thư mục tải xuống")
                read -r -p "Nhập thư mục mới: " new_dir
                DOWNLOAD_DIR="$new_dir"
                mkdir -p "$DOWNLOAD_DIR"
                save_config
                ;;
            "Quay lại") break ;;
            *) ;;
        esac
    done
}

update_script() {
    echo "Đang kiểm tra cập nhật..."
    local latest_script=$(curl -s "$SCRIPT_URL")
    if [ -z "$latest_script" ]; then
        echo "Lỗi kết nối mạng."
        sleep 2
        return
    fi
    if ! diff -q "$0" <(echo "$latest_script") >/dev/null; then
        read -r -p "Có phiên bản mới. Cập nhật? (y/n) " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "$latest_script" > "$0"
            echo "Đã cập nhật. Vui lòng chạy lại."
            exit 0
        fi
    else
        echo "Đang dùng phiên bản mới nhất."
    fi
    sleep 2
}

# --- CORE FUNCTIONS ---
play_anime() {

    # Logic cũ cho OPhim (Giữ nguyên)
    select_anime() {
        local keyword="$1"
        local anime_list
        anime_list=$(curl -s "https://ophim17.cc/tim-kiem?keyword=$keyword" | pup '.ml-4 > a attr{href}' | awk '{print "https://ophim17.cc" $0}' | while read l; do t=$(curl -s "$l" | pup 'h1 text{}'); echo "$l@@@$t"; done | awk -F '@@@' '{print NR ". " $2 " (" $1 ")"}')
        if [[ -z "$anime_list" ]]; then return 1; fi
        echo "$anime_list" | fzf --prompt="Chọn anime: " | sed 's/.*(\(.*\))/\1/'
    }

    get_episode_list_from_url() {
        local html=$(curl -s "$1")
        [ -z "$html" ] && return 1
        echo "$html" | pup 'script json{}' | jq -r '.[].text | @text' | grep -oE '"(http|https)://[^"]*index.m3u8"' | sed 's/"//g' | awk '{print NR "|" $0}'
    }

    get_episode_title() {
        local t=$(curl -s "$1" | pup ".ep-name text{}" | sed -n "${2}p" | tr -d '[:space:]')
        [ -z "$t" ] && t="Tap_$2"
        echo "$t" | tr -d '/\:*?"<>|'
    }

    play_video() {
        local selected_line="$1"
        local url=$(echo "$selected_line" | sed 's/.*(\(.*\))/\1/')
        local name=$(echo "$selected_line" | sed 's/^[^(]*(\([^)]*\)) \+//;s/ ([^ ]*)$//')
        local eps=$(get_episode_list_from_url "$url")
        [ -z "$eps" ] && { echo "Lỗi tải tập phim."; return 1; }
        
        # OPhim play menu... (Giản lược để tập trung vào anidata)
        local sel_ep=$(echo "$eps" | fzf --prompt="Chọn tập: ")
        if [ -n "$sel_ep" ]; then
             local ep_num=$(echo "$sel_ep" | cut -d'|' -f1)
             local ep_link=$(echo "$sel_ep" | cut -d'|' -f2)
             add_to_history "$name" "$ep_num" "$ep_link"
             "$PLAYER" "$ep_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window
        fi
    }
    
    play_video_from_url() {
        local url="$1"
        # Quick fallback name extraction
        local name=$(echo "$url" | awk -F'/' '{print $5}')
        local eps=$(get_episode_list_from_url "$url")
        [ -z "$eps" ] && return 1
        local sel_ep=$(echo "$eps" | fzf --prompt="Chọn tập: ")
        [ -n "$sel_ep" ] && "$PLAYER" "$(echo "$sel_ep" | cut -d'|' -f2)"
    }

    # --- HÀM MỚI: Xử lý file local CSV có cột Link là m3u8 ---
    play_anidata_local() {
        echo "Đang kiểm tra dữ liệu Anidata tại: $LOCAL_DATA_FILE"
        
        # Kiểm tra file tồn tại chưa
        if [ ! -f "$LOCAL_DATA_FILE" ]; then
            echo "Không tìm thấy file: $LOCAL_DATA_FILE"
            echo "Đang thử tải về bản mới nhất..."
            curl -L "https://raw.githubusercontent.com/niyakipham/anisub/refs/heads/main/assets/aniw_export_2026-01-14.csv" -o "$LOCAL_DATA_FILE"
            if [ ! -f "$LOCAL_DATA_FILE" ]; then
                echo "Lỗi: Không thể tải hoặc tìm thấy file dữ liệu."
                sleep 2
                return
            fi
            echo "Đã tải dữ liệu mới."
        fi

        # 1. Làm sạch CSV: Loại bỏ dấu ngoặc kép "" để dễ xử lý bằng awk
        # Cấu trúc: name,episodes,url,link
        # awk tách dấu phẩy (,) -> Cột 1=Name, Cột 2=Ep, Cột 4=Link M3U8
        
        # Lấy danh sách Anime (Cột 1)
        local ANIME_LIST=$(sed '1d;s/"//g' "$LOCAL_DATA_FILE" | awk -F',' '{print $1}' | sort -u)
        
        local SELECTED_ANIME=$(echo "$ANIME_LIST" | fzf --prompt="[Local] Chọn Anime: ")
        
        if [ -z "$SELECTED_ANIME" ]; then
            return
        fi

        # Lấy danh sách tập của Anime đã chọn (Lọc theo tên, lấy cột 2 và 4)
        # Sử dụng delimiter @@ để hiển thị trong fzf cho đẹp
        local EPISODES=$(sed 's/"//g' "$LOCAL_DATA_FILE" | grep "^$SELECTED_ANIME," | awk -F',' '{print $2 " @@ " $4}')
        
        # Chọn tập phim
        # Hiển thị: Tập 1 @@ https://...m3u8
        # Chỉ hiển thị phần tên tập ($1) trong preview hoặc chọn
        local SELECTED_LINE=$(echo "$EPISODES" | fzf --prompt="Chọn tập phim: " --with-nth=1)

        if [ -z "$SELECTED_LINE" ]; then
            return
        fi

        # Tách Link (phần sau @@) và Tên tập (phần trước @@)
        local EP_NAME=$(echo "$SELECTED_LINE" | awk -F' @@ ' '{print $1}')
        local PLAY_LINK=$(echo "$SELECTED_LINE" | awk -F' @@ ' '{print $2}' | tr -d '[:space:]')

        if [ -z "$PLAY_LINK" ]; then
             echo "Lỗi: Không tìm thấy link M3U8 trong dữ liệu."
             sleep 2
             return
        fi

        echo "------------------------------------------------"
        echo "Anime: $SELECTED_ANIME"
        echo "Tập:   $EP_NAME"
        echo "Link:  $PLAY_LINK"
        echo "------------------------------------------------"

        # Thêm vào lịch sử và phát
        add_to_history "$SELECTED_ANIME (Local)" "$EP_NAME" "$PLAY_LINK"
        "$PLAYER" "$PLAY_LINK" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window --force-window=immediate
    }

    # --- MAIN LOOP ---
    while true; do
        selected_option=$(echo -e "Tìm kiếm Anime (OPhim)\nXem từ file (Anidata Local)\nLịch sử xem\nDanh sách yêu thích\nCài đặt\nCập nhật Script\nThoát" | fzf --prompt="MENU CHÍNH: ")

        case "$selected_option" in
            "Tìm kiếm Anime (OPhim)")
                while true; do
                    read -r -p "Nhập tên hoặc URL: " input
                    [ -n "$input" ] && break
                done
                if [[ "$input" =~ ^https?:// ]]; then
                    play_video_from_url "$input"
                else
                    sel=$(select_anime "$(echo "$input" | sed 's/ /+/g')")
                    [ $? -eq 0 ] && play_video "$sel"
                fi
                ;;
            "Xem từ file (AniW data)")
                play_anidata_local
                ;;
            "Lịch sử xem") show_history ;;
            "Danh sách yêu thích") 
                f=$(show_favorites)
                [ $? -eq 0 ] && play_video_from_url "$f"
                ;;
            "Cài đặt") show_settings ;;
            "Cập nhật Script") update_script ;;
            "Thoát"|"") exit 0 ;;
            *) ;;
        esac
    done
}

# --- START ---
clear
echo "Khởi động..."
check_dependencies
load_config
play_anime
