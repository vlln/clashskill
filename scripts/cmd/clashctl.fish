function clashctl
    if test -z "$argv"
        bash -i -c 'clashctl'
        return
    end

    bash -i -c 'clashctl "$@"' bash $argv
end
