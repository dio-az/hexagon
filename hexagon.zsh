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
  [[ 0 -ne $(jobs | wc -l) ]] && hexagon::color blue '⚙ %(1j.%j.-)'
}

hexagon_git_time() {
  local last_commit=$(git log -1 --pretty=format:'%at' 2> /dev/null)

  [[ -z $last_commit ]] && hexagon::color default welcome && return

  local seconds_since_last_commit=$((EPOCHSECONDS - last_commit))

  hexagon::format $seconds_since_last_commit
}

hexagon_git_branch() {
  hexagon::color 242 $(git symbolic-ref --short HEAD 2> /dev/null || git rev-parse --short HEAD)
}

hexagon_git_status() {
  [[ -z $(git status --porcelain --ignore-submodules | grep '^.[^ ]') ]] \
  && hexagon::color green ⬢ || hexagon::color red ⬡
}

hexagon_git_remote() {
  local unpushed=⇡
  local unpulled=⇣
  local local_commit=$(git rev-parse @ 2> /dev/null)
  local remote_commit=$(git rev-parse @{u} 2> /dev/null)

  [[ $local_commit == @ || $local_commit == $remote_commit ]] && return

  local common_base=$(git merge-base @ @{u} 2> /dev/null)

  [[ $common_base == $remote_commit ]] && echo -n $unpushed && return
  [[ $common_base == $local_commit ]]  && echo -n $unpulled && return

  echo -n $unpushed $unpulled
}

hexagon_git() {
  git rev-parse --git-dir &> /dev/null || return

  $(git rev-parse --is-bare-repository 2> /dev/null) && hexagon::color blue ⬢ && return

  echo -n $(hexagon_git_remote) $(hexagon_git_branch) $(hexagon_git_time) $(hexagon_git_status)
}

hexagon::render() {
  local -a output=(
    $(hexagon_timer)
    $(hexagon_jobs)
    $(hexagon_git)
  )

  unset hexagon_command_start

  PROMPT=$(hexagon::color blue "%2~ ")
  RPROMPT=${(ps. .)output}
}

add-zsh-hook precmd hexagon::render
