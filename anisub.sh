#!/bin/bash

play_anime() {

    select_anime() {
        local keyword="$1"
        local anime_list

        anime_list=$(
            curl -s "https://ophim17.cc/tim-kiem?keyword=$keyword" |
            pup '.ml-4 > a attr{href}' |
            awk '{print "https://ophim17.cc" $0}' |
            while IFS= read -r link; do
                title=$(curl -s "$link" | pup 'h1 text{}')
                printf '%s\n' "$link@@@$title"
            done |
            awk -F '@@@' '{print NR ". " $2 " (" $1 ")"}'
        )

        if [[ -z "$anime_list" ]] || [[ "$anime_list" == "Not Found" ]]; then
            echo "Không tìm thấy anime nào với từ khóa '$keyword'."
            return 1
        fi

        selected_anime=$(echo "$anime_list" | fzf --prompt="Chọn anime: ")
        if [[ -z "$selected_anime" ]]; then
            echo "Không có anime nào được chọn."
            return 1
        fi

        echo "$selected_anime" | sed 's/.*(\(.*\))/\1/'
    }

    get_episode_list_from_url() {
        local url="$1"
        local html_content
        local episode_data

        html_content=$(curl -s "$url")
        if [[ -z "$html_content" ]]; then
            echo "Không thể tải nội dung từ URL: $url" >&2
            return 1
        fi

        episode_data=$(echo "$html_content" | pup 'script json{}' | jq -r '.[].text | @text' | grep -oE '"(http|https)://[^"]*index.m3u8"' | sed 's/"//g')

        if [[ -z "$episode_data" ]]; then
            echo "Không tìm thấy danh sách tập phim cho URL: $url" >&2
            return 1
        fi

        local i=1
        while IFS= read -r link; do
            printf "%s|%s\n" "$i" "$link"
            i=$((i + 1))
        done <<< "$episode_data"
    }

    get_episode_list() {
        get_episode_list_from_url "$1"
    }

    get_episode_title() {
        local episode_url="$1"
        local episode_number="$2"
        local episode_title

        episode_title=$(curl -s "$episode_url" | pup ".ep-name text{}" | sed -n "${episode_number}p")

        if [[ -z "$episode_title" ]]; then
            episode_title="Episode $episode_number"
        fi

        echo "$episode_title"
    }

    play_video() {
        local selected_anime="$1"
        local anime_url
        local episode_data
        local selected_episode
        local link
        local anime_name

        anime_url=$(echo "$selected_anime" | sed 's/.*(\(.*\))/\1/')
        anime_name=$(echo "$selected_anime" | sed 's/^[^(]*(\([^)]*\)) \+//;s/ ([^ ]*)$//')

        episode_data=$(get_episode_list "$anime_url")
        if [[ -z "$episode_data" ]]; then
            echo "Không tìm thấy danh sách tập phim." >&2
            return 1
        fi

        play_video_with_menu "$selected_anime" "$anime_url" "$episode_data" "$anime_name"
    }

    play_video_with_menu() {
        local selected_anime="$1"
        local anime_url="$2"
        local episode_data="$3"
        local anime_name="$4"
        local selected_episode
        local current_episode_number
        local current_link
        local action
        local next_episode_number
        local next_link
        local previous_episode_number
        local previous_link
        local episode_title
        local mpv_pid
        local download_status=""
        local anime_dir

        selected_episode=$(echo "$episode_data" | fzf --prompt="Chọn tập phim: " --preview 'echo {2}')
        if [[ -z "$selected_episode" ]]; then
            echo "Không có tập nào được chọn." >&2
            return 1
        fi

        current_episode_number=$(echo "$selected_episode" | cut -d'|' -f1)
        current_link=$(echo "$selected_episode" | cut -d'|' -f2)

        while true; do
            echo "Đang phát tập $current_episode_number..."
            mpv "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
            mpv_pid=$!

            while kill -0 "$mpv_pid" 2> /dev/null; do
                action=$(echo -e "Next\nPrevious\nSelect\nDownloads\nCut Video\nGrafting" | fzf --prompt="Đang phát: Tập $current_episode_number $download_status: ")
                download_status=""

                case "$action" in
                    "Next")
                        kill "$mpv_pid"
                        next_episode_number=$((current_episode_number + 1))
                        next_link=$(echo "$episode_data" | grep "^$next_episode_number|" | cut -d'|' -f2)
                        if [[ -z "$next_link" ]]; then
                            echo "Không có tập tiếp theo." >&2
                            next_episode_number=$current_episode_number
                        else
                            current_episode_number=$next_episode_number
                            current_link=$next_link
                            echo "Đang phát tập $current_episode_number..."
                            mpv "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                            mpv_pid=$!
                        fi
                        ;;
                    "Previous")
                        kill "$mpv_pid"
                        previous_episode_number=$((current_episode_number - 1))
                        previous_link=$(echo "$episode_data" | grep "^$previous_episode_number|" | cut -d'|' -f2)
                        if [[ -z "$previous_link" || "$previous_episode_number" -lt 1 ]]; then
                            echo "Không có tập trước đó." >&2
                            previous_episode_number=$current_episode_number
                        else
                            current_episode_number=$previous_episode_number
                            current_link=$previous_link
                            echo "Đang phát tập $current_episode_number..."
                            mpv "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                            mpv_pid=$!
                        fi
                        ;;
                    "Select")
                        kill "$mpv_pid"
                        selected_episode=$(echo "$episode_data" | fzf --prompt="Chọn tập phim: " --preview 'echo {2}')
                        if [[ -z "$selected_episode" ]]; then
                            echo "Không có tập nào được chọn." >&2
                        else
                            current_episode_number=$(echo "$selected_episode" | cut -d'|' -f1)
                            current_link=$(echo "$selected_episode" | cut -d'|' -f2)
                            echo "Đang phát tập $current_episode_number..."
                            mpv "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                            mpv_pid=$!
                        fi
                        ;;
                    "Downloads")
                        kill "$mpv_pid"
                        anime_dir=$(echo "$anime_url" | awk -F'/' '{print $NF}')
                        episode_title=$(get_episode_title "$anime_url" "$current_episode_number")
                        if [ ! -d "$HOME/Downloads/anime/$anime_dir" ]; then
                            mkdir -p "$HOME/Downloads/anime/$anime_dir"
                        fi
                        download_status="(yt $current_link)"
                        echo "Đang tải tập $current_episode_number - $episode_title vào thư mục $anime_dir..."
                        yt-dlp -o "$HOME/Downloads/anime/$anime_dir/$episode_title.%(ext)s" "$current_link"
                        download_status="(Video đã được tải xuống tại $HOME/Downloads/anime/$anime_dir)"
                        mpv "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                        mpv_pid=$!
                        ;;
                    "Cut Video")
                        kill "$mpv_pid"
                        if ! command -v yt-dlp &> /dev/null; then
                            echo "yt-dlp không được tìm thấy. Vui lòng cài đặt nó thông qua trình quản lý gói của bạn." >&2
                            mpv "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                            mpv_pid=$!
                            continue
                        fi
                        cut_option=$(echo -e "Cắt 1 lần\nCắt nhiều lần" | fzf --prompt="Chọn chế độ cắt: ")
                        case "$cut_option" in
                            "Cắt 1 lần")
                                read -r -p "Nhập thời gian bắt đầu (phút): " start_time
                                read -r -p "Nhập thời gian kết thúc (phút): " end_time
                                if [ ! -d "$HOME/Downloads/anime/cut" ]; then
                                    mkdir -p "$HOME/Downloads/anime/cut"
                                fi
                                output_file="$HOME/Downloads/anime/cut/cut_$(date +%s).mp4"
                                echo "Đang cắt video từ phút $start_time đến phút $end_time..."
                                yt-dlp --download-sections "*${start_time}-${end_time}" -o "$output_file" "$current_link"
                                echo "Video đã được cắt và lưu tại: $output_file"
                                ;;
                            "Cắt nhiều lần")
                                read -r -p "Nhập số lượng phân đoạn muốn cắt: " num_segments
                                if [ ! -d "$HOME/Downloads/anime/cut" ]; then
                                    mkdir -p "$HOME/Downloads/anime/cut"
                                fi
                                for ((i=1; i<=num_segments; i++)); do
                                    echo "Phân đoạn $i:"
                                    read -r -p "Nhập thời gian bắt đầu (phút): " start_time
                                    read -r -p "Nhập thời gian kết thúc (phút): " end_time
                                    output_file="$HOME/Downloads/anime/cut/cut_${i}_$(date +%s).mp4"
                                    echo "Đang cắt video từ phút $start_time đến phút $end_time..."
                                    yt-dlp --download-sections "*${start_time}-${end_time}" -o "$output_file" "$current_link"
                                    echo "Phân đoạn $i đã được cắt và lưu tại: $output_file"
                                done
                                ;;
                            *)
                                echo "Lựa chọn không hợp lệ." >&2
                                ;;
                        esac
                        ;;
                    "Grafting")
                        kill "$mpv_pid"
                        grafting_option=$(echo -e "Ghép 1 lần\nGhép nhiều lần" | fzf --prompt="Chọn chế độ ghép: ")
                        case "$grafting_option" in
                            "Ghép 1 lần")
                                read -r -p "Bạn muốn ghép bao nhiêu video lại với nhau: " num_videos
                                video_files=()
                                for ((i=1; i<=num_videos; i++)); do
                                    video_files+=("$(find "$HOME/Downloads/anime/cut" -type f -name "*.mp4" | fzf --prompt="Chọn video $i: ")")
                                done
                                if [ ! -d "$HOME/Downloads/anime/grafting" ]; then
                                    mkdir -p "$HOME/Downloads/anime/grafting"
                                fi
                                output_file="$HOME/Downloads/anime/grafting/grafted_$(date +%s).mp4"
                                echo "Đang ghép video..."
                                ffmpeg -f concat -safe 0 -i <(for f in "${video_files[@]}"; do echo "file '$f'"; done) -c copy "$output_file"
                                echo "Video đã được ghép và lưu tại: $output_file"
                                ;;
                            "Ghép nhiều lần")
                                read -r -p "Bạn muốn tạo bao nhiêu vòng lặp ghép: " num_loops
                                for ((loop=1; loop<=num_loops; loop++)); do
                                    echo "Vòng lặp ghép thứ $loop:"
                                    read -r -p "Bạn muốn ghép bao nhiêu video lại với nhau: " num_videos
                                    video_files=()
                                    for ((i=1; i<=num_videos; i++)); do
                                        video_files+=("$(find "$HOME/Downloads/anime/cut" -type f -name "*.mp4" | fzf --prompt="Chọn video $i: ")")
                                    done
                                    if [ ! -d "$HOME/Downloads/anime/grafting" ]; then
                                        mkdir -p "$HOME/Downloads/anime/grafting"
                                    fi
                                    output_file="$HOME/Downloads/anime/grafting/grafted_loop${loop}_$(date +%s).mp4"
                                    echo "Đang ghép video..."
                                    ffmpeg -f concat -safe 0 -i <(for f in "${video_files[@]}"; do echo "file '$f'"; done) -c copy "$output_file"
                                    echo "Video đã được ghép và lưu tại: $output_file"
                                done
                                ;;
                            *)
                                echo "Lựa chọn không hợp lệ." >&2
                                ;;
                        esac
                        ;;
                    "")
                        kill "$mpv_pid"
                        echo "Thoát"
                        exit 0
                        ;;
                    *)
                        echo "Lựa chọn không hợp lệ." >&2
                        ;;
                esac
            done
        done
    }

    play_video_from_url() {
        local url="$1"
        local episode_data
        local selected_episode
        local link
        local anime_name

        episode_data=$(get_episode_list_from_url "$url")
        if [[ -z "$episode_data" ]]; then
            echo "Không tìm thấy danh sách tập phim." >&2
            return 1
        fi

        anime_name=$(echo "$url" | awk -F'/' '{print $5}')
        selected_anime="$anime_name ($url)"
        play_video_with_menu "$selected_anime" "$url" "$episode_data" "$anime_name"
    }

    play_anidata() {
        # URL của file CSV
        CSV_URL="https://raw.githubusercontent.com/toilamsao/anidata/refs/heads/main/data.csv"

        # Tải nội dung CSV và loại bỏ dấu ngoặc kép
        CSV_CONTENT=$(curl -s "$CSV_URL" | sed 's/"//g')

        # Lấy danh sách các anime duy nhất từ cột 'name', bỏ qua dòng tiêu đề
        ANIME_NAMES=$(echo "$CSV_CONTENT" | sed '1d' | cut -d',' -f1 | sort -u)

        # Hiển thị danh sách anime để người dùng chọn bằng fzf
        SELECTED_ANIME=$(echo "$ANIME_NAMES" | fzf --prompt="Chọn anime muốn xem: ")

        # Kiểm tra xem người dùng có chọn anime hay không
        if [ -z "$SELECTED_ANIME" ]; then
            echo "Không có anime nào được chọn."
            exit 1
        fi

        # Lọc các tập và link tương ứng với anime được chọn
        EPISODES=$(echo "$CSV_CONTENT" | awk -F',' -v anime="$SELECTED_ANIME" '$1 == anime {print $2 " | " $3}')

        # Hiển thị danh sách tập và link để người dùng chọn bằng fzf
        SELECTED_EPISODE=$(echo "$EPISODES" | fzf --prompt="Chọn tập muốn xem: ")

        # Kiểm tra xem người dùng có chọn tập hay không
        if [ -z "$SELECTED_EPISODE" ]; then
            echo "Không có tập nào được chọn."
            exit 1
        fi

        # Trích xuất link từ dòng được chọn
        LINK=$(echo "$SELECTED_EPISODE" | awk -F' \\| ' '{print $2}')

        # Phát video bằng mpv
        mpv "$LINK"
    }

    while true; do
        selected_option=$(echo -e "Manga Read\nPlay Anime" | fzf --prompt="Chọn chức năng: ")

        case "$selected_option" in
            "Manga Read")
                manga-tui lang --set 'vi'
                echo "Đã thiết lập ngôn ngữ manga-tui thành 'vi'."
                exit 0
                ;;
            "Play Anime")
                selected_source=$(echo -e "ophim\nAnidata" | fzf --prompt="Chọn nguồn: ")
                case "$selected_source" in
                    "ophim")
                        while true; do
                            echo -n "Tìm kiếm anime:"
                            read -r input
                            if [[ -z "$input" ]]; then
                                echo "Tìm kiếm anime:"
                            else
                                break
                            fi
                        done

                        if [[ "$input" =~ ^https?:// ]]; then
                            play_video_from_url "$input"
                        else
                            anime_name_encoded=$(echo "$input" | sed 's/ /+/g')
                            selected_anime=$(select_anime "$anime_name_encoded")
                            if [[ $? -ne 0 ]]; then
                                exit 1
                            fi
                            play_video "$selected_anime"
                        fi
                        ;;
                    "Anidata")
                        play_anidata
                        ;;
                    *)
                        echo "Lựa chọn không hợp lệ." >&2
                        ;;
                esac
                ;;
            *)
                echo "Lựa chọn không hợp lệ." >&2
                ;;
        esac
    done
}

play_anime
