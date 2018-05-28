" TODO: process stdout and stderr separately

" initialize global variables
let g:lightline#git#status = [0, 0, 0]
let g:lightline#git#status#indicator_added = '+'
let g:lightline#git#status#indicator_modified = '!'
let g:lightline#git#status#indicator_deleted = '-'
let s:file_whitelist = {}

augroup lightline#git
    autocmd!
    autocmd BufEnter * call s:query_git()
    autocmd BufWrite * call s:query_git()
augroup END

function! s:job_stdout(job_id, data, event) dict
    " Couldn't get 'join' to insert linebreaks so '\n' is my token
    " for line breaks. The chance of it appearing in actual programs is
    " minimal
    let l:self.output = l:self.output . join(a:data, '\n')
endfunction

function! s:job_stderr(job_id, data, event) dict
    let l:self.output = l:self.output . join(a:data, '\n')
endfunction

function! s:job_exit(job_id, data, event) dict
    call s:update_status(l:self.output)
endfunction

function! s:query_git()
    let l:filename = expand('%:f')
    if l:filename !=# ''
        let l:cmd = 'git diff --compact-summary --word-diff=porcelain ' .
        \           '--no-color --no-ext-diff -U0 -- ' . l:filename
        let l:callbacks = {
        \       'on_stdout': function('s:job_stdout'),
        \       'on_stderr': function('s:job_stderr'),
        \       'on_exit': function('s:job_exit')
        \ }
        let l:job_id = jobstart(l:cmd, extend({'output': ''}, l:callbacks))
    endif
endfunction

function! s:modified_count(hunks)
    let l:modified = 0
    for l:hunk in a:hunks
        for l:line in split(l:hunk, '\~')
            let l:plus = 0
            let l:minus = 0
            for l:chunk in split(l:line, '\\n')
                let l:firstchar  = l:chunk[0]
                if l:firstchar ==# '+'
                    let l:plus = l:plus + 1
                elseif l:firstchar ==# '-'
                    let l:minus = l:minus + 1
                endif
            endfor
            if l:plus !=# 0 && l:minus !=# 0
                let l:modified = l:modified + 1
            endif
        endfor
    endfor
    return l:modified
endfunction

function! s:str2nr(str)
    return empty(str2nr(a:str)) ? 0 : str2nr(a:str)
endfunction

function! s:track_file(git_raw_output)
    " Nothing has changed since last commit/file in a git repo but not in git
    " tree
    if a:git_raw_output ==# ''
        return 0
    " If file is readonly or that the dir is not a git repo
    else
        let l:orphan = !&modifiable
        \ || split(a:git_raw_output, '\\n')[0] ==# 'Not a git repository'
        if l:orphan
            return 0
        else
            return 1
        endif
    endif
endfunction

function! s:update_status(git_raw_output)
    let l:curr_full_path = expand('%:p')
    let s:file_whitelist[l:curr_full_path] = s:track_file(a:git_raw_output)

    if s:file_whitelist[l:curr_full_path] ==# 1
        let l:split_diff = split(a:git_raw_output, '@@')
        let l:nhunks = (len(l:split_diff) - 1) / 2

        let l:header = l:split_diff[0]
        let l:hunks = []
        for l:idx in range(1, l:nhunks)
            call add(l:hunks, l:split_diff[2 * l:idx])
        endfor

        let l:modified = s:modified_count(l:hunks)
        let l:change_summary = split(l:header, '\\n')[1]
        let l:regex = '\v[^,]+, ((\d+) [a-z]+\(\+\)[, ]*)?((\d+) [a-z]+\(-\))?'
        let l:matched =  matchlist(l:change_summary, l:regex)
        let l:insertions = s:str2nr(l:matched[2])
        let l:deletions = s:str2nr(l:matched[4])
        let l:added = l:insertions - l:modified
        let l:deleted = l:deletions - l:modified
        let g:lightline#git#status = [l:added, l:modified, l:deleted]
    endif
    call lightline#update()
endfunction

function! lightline#git#get_status()
    let [l:added, l:modified, l:deleted] = g:lightline#git#status
    let l:curr_full_path = expand('%:p')
    if get(s:file_whitelist, l:curr_full_path)
        return g:lightline#git#status#indicator_added . ' ' . l:added . ' ' .
        \      g:lightline#git#status#indicator_modified . ' ' . l:modified . ' ' .
        \      g:lightline#git#status#indicator_deleted . ' ' . l:deleted
    else
        return ''
    endif
endfunction
