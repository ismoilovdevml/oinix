#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias grep='grep --color=auto'
alias ip='ip -color=auto'

PS1='\[\e[38;2;23;147;209m\]\u@\h\[\e[0m\] \[\e[1m\]\w\[\e[0m\] \$ '

export EDITOR=nano

# Show a short welcome banner on the live medium only
if [[ -e /run/archiso/bootmnt ]] && [[ -z "${OINIX_BANNER_SHOWN:-}" ]]; then
    export OINIX_BANNER_SHOWN=1
    command -v fastfetch >/dev/null 2>&1 && fastfetch
fi
