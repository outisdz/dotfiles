if status is-interactive
    # Commands to run in interactive sessions can go here
    echo ''
    fastfetch
    echo ''
    
end

alias ll="eza -lh"
alias la="eza -lah"
alias lt="eza -lh --sort newest"
alias lat="eza -lah --sort newest"
alias myip="curl ifconfig.io/ip"

set -gx PATH /usr/local/bin /usr/bin /bin /usr/local/sbin /usr/sbin /sbin $HOME/.local/bin $HOME/bin

#starship init fish | source
# rustup shell setup
if not contains "$HOME/.cargo/bin" $PATH
    # Prepending path in case a system-installed rustc needs to be overridden
    set -x PATH "$HOME/.cargo/bin" $PATH
end

