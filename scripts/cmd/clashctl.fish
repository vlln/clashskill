function clashctl
    if test -z "$argv"
        bash -i -c 'clashctl'
        return
    end

    set suffix $argv[1]
    set argv $argv[2..-1]

    switch $suffix
        case '*'
            bash -i -c "clashctl $suffix $argv"
    end
end
