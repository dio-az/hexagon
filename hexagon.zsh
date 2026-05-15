autoload -U add-zsh-hook

ZLE_RPROMPT_INDENT=0

hexagon::style() {
	zstyle $@[1,3] $3 && return
	[[ $1 == -a ]] && set -A $3 ${@:4} || : ${(P)3::=$4}
}

hexagon::sanitize() {
	print -n -- ${${1//'$'/}//\`/}
}

hexagon::color() {
	(($# == 2)) && print -n %F{$1}$2%f
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

hexagon_git() {
	local report=$(git status --porcelain=v2 --branch --show-stash --ignore-submodules 2>/dev/null)

	[[ -z $report ]] && return

	local -A hexagon_git

	local line
	for line in ${(f)report}; do
		case $line in
			'# branch.head '*) hexagon_git[branch]=$(hexagon::sanitize ${line#'# branch.head '}) ;;
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
		hexagon_git[branch]=$(hexagon::sanitize ${tag:-${hexagon_git[sha][1,7]}})
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

	print -n ${(j: :)${(0)output}}
}

hexagon::render() {
	local -a components
	hexagon::style -a ':hexagon' components timer jobs git

	local output=$(
		for component in $components; do
			hexagon_$component
			print -n '\0'
		done
	)

	unset hexagon_command_start

	local color format
	hexagon::style -s ':hexagon:path' color blue
	hexagon::style -s ':hexagon:path' format %2~

	PROMPT="$(hexagon::color $color $format) "
	RPROMPT=${(j: :)${(0)output}}
}

add-zsh-hook precmd hexagon::render
