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
            
            action=$(echo -e "Next\nPrevious\nSelect\nDownloads\nEdit" | fzf --prompt="Đang phát: Tập $current_episode_number $download_status: ")

            
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
            "Edit")
               
                if ! command -v yt-dlp &> /dev/null; then
                    echo "yt-dlp could not be found. Please install it via your package manager." >&2
                    
                    mpv "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                    mpv_pid=$!
                    continue
                fi
                
                
                kill "$mpv_pid"
                episode_title=$(get_episode_title "$anime_url" "$current_episode_number")
                
                read -r -p "Nhập thời gian bắt đầu (phút): " start_time
                
                read -r -p "Nhập thời gian kết thúc (phút): " end_time

               
                anime_dir=$(echo "$anime_url" | awk -F'/' '{print $NF}')

               
                if [ ! -d "$HOME/Downloads/anime/$anime_dir" ]; then
                  mkdir -p "$HOME/Downloads/anime/$anime_dir"
                fi

                
                edit_count=1
                while true; do
                    output_file="$HOME/Downloads/anime/$anime_dir/edit${edit_count}.mp4"
                    if [[ ! -f "$output_file" ]]; then
                        break
                    fi
                    edit_count=$((edit_count + 1))
                done

                
                echo "Đang cắt video từ phút $start_time đến phút $end_time..."
                yt-dlp --download-sections "*${start_time}-${end_time}" -o "$output_file" "$current_link"

                echo "Video đã được cắt và lưu tại: $output_file"
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


while true; do
    selected_option=$(echo -e "Manga Read\nPlay Anime" | fzf --prompt="Chọn chức năng: ")

    case "$selected_option" in
        "Manga Read")
            manga-tui lang --set 'vi'
            echo "Đã thiết lập ngôn ngữ manga-tui thành 'vi'."
            exit 0
            ;;
        "Play Anime")
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
        *)
            echo "Lựa chọn không hợp lệ." >&2
            ;;
    esac
done
}

play_anime
