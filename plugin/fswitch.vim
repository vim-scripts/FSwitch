" ============================================================================
" File:        fswitch.vim
"
" Description: Vim global plugin that provides decent companion source file
"              switching
"
" Maintainer:  Derek Wyatt <derek at myfirstnamemylastname dot org>
"
" Last Change: March 23rd 2009
"
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================

if exists("g:disable_fswitch")
    finish
endif

" Version
let s:fswitch_version = '0.9.0'

" Get the path separator right
let s:os_slash = &ssl == 0 && (has("win16") || has("win32") || has("win64")) ? '\' : '/'

" Default locations - appended to buffer locations unless otherwise specified
let s:fswitch_global_locs = '.' . s:os_slash

"
" s:FSGetAlternateFilename
"
" Takes the path, name and extension of the file in the current buffer and
" applies the location to it.  If the location is a regular expression pattern
" then it will split that up and apply it accordingly.  If the location pattern
" is actually an explicit relative path or an implicit one (default) then it
" will simply apply that to the file directly.
"
function! s:FSGetAlternateFilename(filepath, filename, newextension, location, mustmatch)
    let parts = split(a:location, ':')
    if len(parts) == 2 && parts[0] == 'reg'
        if strlen(parts[1]) < 3
            throw 'Bad substitution pattern "' . a:location . '".'
        else
            let resep = strpart(parts[1], 0, 1)
            let regex = split(strpart(parts[1], 1), resep)
            if len(regex) < 2 || len(regex) > 3
                throw 'Bad substitution pattern "' . a:location . '".'
            else
                let pat = regex[0]
                let sub = regex[1]
                let flags = ''
                if len(regex) == 3
                    let flags = regex[2]
                endif
                if a:mustmatch == 1 && match(a:filepath, pat) == -1
                    let path = ""
                else
                    let path = substitute(a:filepath, pat, sub, flags) . s:os_slash .
                                \ a:filename . '.' . a:newextension
                endif
            endif
        endif
    elseif len(parts) == 2 && parts[0] == 'rel'
        let path = a:filepath . s:os_slash . parts[1] . 
                      \ s:os_slash . a:filename . '.' . a:newextension
    elseif len(parts) == 2 && parts[0] == 'abs'
        let path = parts[1] . s:os_slash . a:filename . '.' . a:newextension
    elseif len(parts) == 1 " This is the default relative path
        let path = a:filepath . s:os_slash . a:location . 
                      \ s:os_slash . a:filename . '.' . a:newextension
    endif

    return simplify(path)
endfunction

"
" s:SetVariables
"
" There are two variables that need to be set in the buffer in order for things
" to work correctly.  Because we're using an autocmd to set things up we need to
" be sure that the user hasn't already set them for us explicitly so we have
" this function just to check and make sure.  If the user's autocmd runs after
" ours then they will override the value anyway.
"
function! s:SetVariables(dst, locs)
    if !exists("b:fswitchdst")
        let b:fswitchdst = a:dst
    endif
    if !exists("b:fswitchlocs")
        let b:fswitchlocs = a:locs
    endif
endfunction

"
" FSwitch
"
" This is the only externally accessible function and is what we use to switch
" to the alternate file.
"
function! FSwitch(filename, precmd)
    let fullpath = expand(a:filename . ':p:h')
    let ext = expand(a:filename . ':e')
    let justfile = expand(a:filename . ':t:r')
    if !exists("b:fswitchdst")
        throw 'b:fswitchdst not set - read :help fswitch'
    endif
    let extensions = split(b:fswitchdst, ',')
    let locations = []
    if exists("b:fswitchlocs")
        let locations = split(b:fswitchlocs, ',')
    endif
    if !exists("b:fsdisablegloc") || b:fsdisablegloc == 0
        let locations += split(s:fswitch_global_locs, ',')
    endif
    if len(locations) == 0
        throw "There are no locations defined (see :h fswitchlocs and :h fsdisablegloc)"
    endif
    let mustmatch = 1
    if exists("b:fsneednomatch") && b:fsneednomatch != 0
        let mustmatch = 0
    endif
    let newpath = ''
    let firstNonEmptyPath = ''
    for currentExt in extensions
        for loc in locations
            let newpath = s:FSGetAlternateFilename(fullpath, justfile, currentExt, loc, mustmatch)
            if newpath != '' && firstNonEmptyPath == ''
                let firstNonEmptyPath = newpath
            endif
            let newpath = glob(newpath)
            if filereadable(newpath)
                break
            endif
        endfor
        if filereadable(newpath)
            break
        endif
    endfor
    let openfile = 1
    if !filereadable(newpath)
        if exists("b:fsnonewfiles") || exists("g:fsnonewfiles")
            let openfile = 0
        else
            let newpath = firstNonEmptyPath
        endif
    endif
    if openfile == 1
        if newpath != ''
            if strlen(a:precmd) != 0
                execute a:precmd
            endif
            execute 'edit ' . fnameescape(newpath)
        else
            echoerr "Alternate has evaluated to nothing.  See :h fswitch-empty for more info."
        endif
    else
        echoerr "No alternate file found.  'fsnonewfiles' is set which denies creation."
    endif
endfunction

"
" The autocmds we set up to set up the buffer variables for us.
"
augroup fswitch_au_group
    au!
    au BufEnter,BufWinEnter *.h call s:SetVariables('cpp,c', 'reg:/include/src/,reg:/include.*/src/,../src')
    au BufEnter,BufWinEnter *.c call s:SetVariables('h', 'reg:/src/include/,reg:|src|include/**|,../include')
    au BufEnter,BufWinEnter *.cpp call s:SetVariables('h', 'reg:/src/include/,reg:|src|include/**|,../include')
augroup END

"
" The mappings used to do the good work
"
com! FSHere       :call FSwitch('%', '')
com! FSRight      :call FSwitch('%', 'wincmd l')
com! FSSplitRight :call FSwitch('%', 'vsplit \| wincmd l')
com! FSLeft       :call FSwitch('%', 'wincmd h')
com! FSSplitLeft  :call FSwitch('%', 'vsplit \| wincmd h')
com! FSAbove      :call FSwitch('%', 'wincmd k')
com! FSSplitAbove :call FSwitch('%', 'split \| wincmd k')
com! FSBelow      :call FSwitch('%', 'wincmd j')
com! FSSplitBelow :call FSwitch('%', 'split \| wincmd j')

