autoload -U add-zsh-hook

ZLE_RPROMPT_INDENT=0

hexagon::style() {
	zstyle $@[1,3] $3 && return
	[[ $1 == -a ]] && set -A $3 ${@:4} || : ${(P)3::=$4}
}

hexagon::escape() {
	local text=$1

	if [[ -o promptsubst ]]; then
		text=${text//'\'/'\\'}
		text=${text//'$'/'\$'}
		text=${text//'`'/'\`'}
	fi

	[[ -o promptpercent ]] && text=${text//'%'/'%%'}
	[[ -o promptbang ]] && text=${text//'!'/'!!'}

	print -rn -- $text
}

hexagon::color() {
	(($# == 2)) && print -rn -- %F{$1}$2%f
}

hexagon::duration() {
	local seconds=$1
	local days=$((seconds / 86400))
	local hours=$((seconds / 3600 % 24))
	local minutes=$((seconds / 60 % 60))
	local seconds=$((seconds % 60))

	local color label
	if ((days > 0)); then
		hexagon::style -s ':hexagon:duration:day' color red
		label=${days}d
	elif ((hours > 0)); then
		hexagon::style -s ':hexagon:duration:hour' color white
		label=${hours}h
	elif ((minutes > 0)); then
		hexagon::style -s ':hexagon:duration:minute' color green
		label=${minutes}m
	elif ((seconds > 0)); then
		hexagon::style -s ':hexagon:duration:second' color green
		label=${seconds}s
	fi

	hexagon::color $color $label
}

zmodload zsh/datetime

hexagon::command_start() {
	hexagon_command_start=$EPOCHSECONDS
}

add-zsh-hook preexec hexagon::command_start

hexagon_timer() {
	[[ -n $hexagon_command_start ]] || return

	local threshold
	hexagon::style -s ':hexagon:timer' threshold 5

	local elapsed=$(( EPOCHSECONDS - hexagon_command_start ))
	((elapsed > threshold)) && hexagon::duration $elapsed
}

hexagon_jobs() {
	(( $#jobstates )) || return

	local color symbol
	hexagon::style -s ':hexagon:jobs' color blue
	hexagon::style -s ':hexagon:jobs' symbol ⚙

	hexagon::color $color "%(1j.%j.-)$symbol"
}

hexagon_git_elapsed() {
	[[ -n $hexagon_git[commit_time] ]] || return

	local seconds_since_last_commit=$((EPOCHSECONDS - hexagon_git[commit_time]))
	hexagon::duration $seconds_since_last_commit
}

hexagon_git_branch() {
	local color
	hexagon::style -s ':hexagon:git:branch' color 242

	hexagon::color $color $hexagon_git[branch]
}

hexagon_git_status() {
	local color symbol
	if [[ -n $hexagon_git[dirty] ]]; then
		hexagon::style -s ':hexagon:git:status:dirty' color red
		hexagon::style -s ':hexagon:git:status:dirty' symbol ⬡
	else
		hexagon::style -s ':hexagon:git:status:clean' color green
		hexagon::style -s ':hexagon:git:status:clean' symbol ⬢
	fi

	hexagon::color $color $symbol
}

hexagon_git_remote() {
	(( hexagon_git[ahead] == 0 && hexagon_git[behind] == 0 )) && return

	local ahead behind color
	hexagon::style -s ':hexagon:git:remote' ahead ⇡
	hexagon::style -s ':hexagon:git:remote' behind ⇣
	hexagon::style -s ':hexagon:git:remote' color default

	(( hexagon_git[behind] == 0 )) && hexagon::color $color $ahead && return
	(( hexagon_git[ahead] == 0 )) && hexagon::color $color $behind && return

	hexagon::color $color "$ahead $behind"
}

hexagon_git_stash() {
	(( hexagon_git[stash] == 0 )) && return

	local color symbol
	hexagon::style -s ':hexagon:git:stash' color 242
	hexagon::style -s ':hexagon:git:stash' symbol ≡

	hexagon::color $color $hexagon_git[stash]$symbol
}

hexagon_git() {
	local report=$(git status --porcelain=v2 --branch --show-stash --ignore-submodules 2>/dev/null)

	[[ -z $report ]] && return

	local -A hexagon_git

	local line
	for line in ${(f)report}; do
		case $line in
			'# branch.head '*) hexagon_git[branch]=$(hexagon::escape ${line#'# branch.head '}) ;;
			'# branch.oid '*) hexagon_git[sha]=${line#'# branch.oid '} ;;
			'# branch.ab '*)
				local ab=${line#'# branch.ab +'}
				hexagon_git[ahead]=${ab%% -*}
				hexagon_git[behind]=${ab##*-}
				;;
			'# stash '*) hexagon_git[stash]=${line#'# stash '} ;;
			'# '*) ;;
			'1 '?'.'* | '2 '?'.'*) ;;
			*) hexagon_git[dirty]=1; break ;;
		esac
	done

	if [[ $hexagon_git[branch] == '(detached)' ]]; then
		local tag=$(git describe --tags --exact-match 2>/dev/null)
		hexagon_git[branch]=$(hexagon::escape ${tag:-${hexagon_git[sha][1,7]}})
	fi

	hexagon_git[commit_time]=$(git log -1 --format=%ct 2>/dev/null)

	local -a components
	hexagon::style -a ':hexagon:git' components remote branch elapsed status

	local output=$(
		for component in $components; do
			hexagon_git_$component
			print -n '\0'
		done
	)

	print -rn -- ${(j: :)${(0)output}}
}

hexagon_exit() {
	[[ $exit_code == (0|130|141) ]] && return

	local symbol color
	hexagon::style -s ':hexagon:exit' symbol ‣
	hexagon::style -s ':hexagon:exit' color red

	hexagon::color $color $symbol$exit_code
}

typeset -gA hexagon_parts

hexagon::run() {
	for component; do
		print -rn -- $component$'\0'
		hexagon_$component
		print -n '\0'
	done
}

hexagon::store() {
	# Drop the empty field after the trailing NUL.
	local -a pairs=("${(@0)1}")
	hexagon_parts+=("${(@)pairs[1,-2]}")
}

hexagon::draw() {
	local -a parts
	local component
	for component in $hexagon_components; do
		parts+=(${hexagon_parts[$component]})
	done

	RPROMPT=${(j: :)parts}
}

# A job can't be cancelled, so prompts that arrive during one queue a single rerun.
hexagon::async() {
	# The callback only fires under ZLE.
	[[ -o zle ]] && (( $#hexagon_async )) || return

	if (( hexagon_async_fd )); then
		hexagon_async_rerun=1
		return
	fi

	unset hexagon_async_rerun

	# Write the output at once, so the callback can't freeze typing.
	exec {hexagon_async_fd}< <(print -rn -- "$(hexagon::run $hexagon_async)")
	zle -F $hexagon_async_fd hexagon::async_done
}

hexagon::async_stop() {
	(( hexagon_async_fd )) || return
	zle -F $hexagon_async_fd
	exec {hexagon_async_fd}<&-
	unset hexagon_async_fd
}

hexagon::async_done() {
	hexagon::store "$(<&$1)"
	hexagon::async_stop
	hexagon::draw
	zle reset-prompt

	[[ -n $hexagon_async_rerun ]] && hexagon::async
}

hexagon::render() {
	local exit_code=$?

	local -a components async
	hexagon::style -a ':hexagon' components timer jobs git
	hexagon::style -a ':hexagon' async git
	hexagon_components=($components)
	hexagon_async=(${components:*async})

	# Drop cached and pending async results from another directory.
	if [[ $PWD != $hexagon_pwd ]]; then
		hexagon_parts=()
		hexagon::async_stop
		hexagon_pwd=$PWD
	fi

	hexagon::store "$(hexagon::run ${components:|async})"

	unset hexagon_command_start

	local color format
	hexagon::style -s ':hexagon:path' color blue
	hexagon::style -s ':hexagon:path' format %2~

	PROMPT="$(hexagon::color $color $format) "
	hexagon::draw
	hexagon::async
}

add-zsh-hook precmd hexagon::render
