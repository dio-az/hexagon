autoload -U add-zsh-hook

hexagon::color() {
  (($# - 2)) || echo -n %F{$1}$2%f
}

hexagon::format() {
  local seconds=$1
  local days=$((seconds / 60 / 60 / 24))
  local hours=$((seconds / 60 / 60 % 24))
  local minutes=$((seconds / 60 % 60))
  local seconds=$((seconds % 60))

  local -a human=()
  local color

  ((days > 0)) && human+=${days}d && color=red
  ((hours > 0)) && human+=${hours}h && : ${color:=white}
  ((minutes > 0)) && human+=${minutes}m
  ((seconds > 0)) && human+=${seconds}s && : ${color:=green}

  hexagon::color $color $human[1]
}

zmodload zsh/datetime

hexagon::command_start() {
  hexagon_command_start=$EPOCHSECONDS
}

add-zsh-hook preexec hexagon::command_start

hexagon_timer() {
  [[ -n $hexagon_command_start ]] || return

  local elapsed=$(( EPOCHSECONDS - hexagon_command_start ))
  ((elapsed > 5)) && hexagon::format $elapsed
}

hexagon_jobs() {
  (( $#jobstates )) && hexagon::color blue '⚙ %(1j.%j.-)'
}

hexagon_git_time() {
  [[ -z $hexagon_git[commit_time] ]] && hexagon::color default welcome && return

  local seconds_since_last_commit=$((EPOCHSECONDS - hexagon_git[commit_time]))

  hexagon::format $seconds_since_last_commit
}

hexagon_git_head() {
  hexagon::color 242 $hexagon_git[head]
}

hexagon_git_status() {
  [[ -z $hexagon_git[dirty] ]] && hexagon::color green ⬢ || hexagon::color red ⬡
}

hexagon_git_remote() {
  local unpushed=⇡
  local unpulled=⇣

  (( hexagon_git[ahead] == 0 && hexagon_git[behind] == 0 )) && return
  (( hexagon_git[behind] == 0 )) && echo -n $unpushed && return
  (( hexagon_git[ahead]  == 0 )) && echo -n $unpulled && return

  echo -n $unpushed $unpulled
}

hexagon_git() {
  local report=$(git status --porcelain=v2 --branch --ignore-submodules 2>/dev/null)

  [[ -z $report ]] && return

  local -A hexagon_git
  local line
  for line in ${(f)report}; do
    case $line in
      '# branch.head '*) hexagon_git[head]=${line#'# branch.head '} ;;
      '# branch.oid '*) hexagon_git[sha]=${line#'# branch.oid '} ;;
      '# branch.ab '*)
        local ab=${line#'# branch.ab +'}
        hexagon_git[ahead]=${ab%% -*}
        hexagon_git[behind]=${ab##*-}
        ;;
      '# '*) ;;
      *) hexagon_git[dirty]=1 ;;
    esac
  done

  if [[ $hexagon_git[head] == '(detached)' ]]; then
    local tag=$(git describe --tags --exact-match 2>/dev/null)
    hexagon_git[head]=${tag:-${hexagon_git[sha][1,7]}}
  fi

  hexagon_git[commit_time]=$(git log -1 --format=%ct 2>/dev/null)

  echo -n $(hexagon_git_remote) $(hexagon_git_head) $(hexagon_git_time) $(hexagon_git_status)
}

hexagon::render() {
  local -a output=(
    $(hexagon_timer)
    $(hexagon_jobs)
    $(hexagon_git)
  )

  unset hexagon_command_start

  RPROMPT=${(ps. .)output}
}

PROMPT=$(hexagon::color blue "%2~ ")

add-zsh-hook precmd hexagon::render
