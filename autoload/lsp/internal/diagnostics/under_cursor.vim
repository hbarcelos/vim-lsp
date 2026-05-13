" Returns a diagnostic object, or empty dictionary if no diagnostics are
" available.
" options = {
"   'server': '',        " optional
"   'line_fallback': v:false,
" }
function! lsp#internal#diagnostics#under_cursor#get_diagnostic(...) abort
    let l:options = get(a:000, 0, {})
    let l:server = get(l:options, 'server', '')
    let l:bufnr = bufnr('%')

    if !lsp#internal#diagnostics#state#_is_enabled_for_buffer(l:bufnr)
        return {}
    endif

    let l:uri = lsp#utils#get_buffer_uri(l:bufnr)

    let l:diagnostics_by_server = lsp#internal#diagnostics#state#_get_all_diagnostics_grouped_by_server_for_uri(l:uri)
    let l:diagnostics = []
    if empty(l:server)
        for l:item in values(l:diagnostics_by_server)
            let l:diagnostics += lsp#utils#iterable(l:item['params']['diagnostics'])
        endfor
    else
        if has_key(l:diagnostics_by_server, l:server)
            let l:diagnostics = lsp#utils#iterable(l:diagnostics_by_server[l:server]['params']['diagnostics'])
        endif
    endif

    let l:line = line('.')
    let l:col = col('.')

    return lsp#internal#diagnostics#under_cursor#_get_closest_diagnostic(l:diagnostics, l:line, l:col, l:options)
endfunction

" Returns a diagnostic object, or empty dictionary if no diagnostics are
" available.
function! lsp#internal#diagnostics#under_cursor#_get_closest_diagnostic(diagnostics, line, col, ...) abort
    let l:options = get(a:000, 0, {})
    let l:closest_diagnostic = {}
    let l:closest_distance = -1

    for l:diagnostic in a:diagnostics
        let [l:start_line, l:start_col] = lsp#utils#position#lsp_to_vim('%', l:diagnostic['range']['start'])
        let [l:end_line, l:end_col] = lsp#utils#position#lsp_to_vim('%', l:diagnostic['range']['end'])

        if (a:line > l:start_line || (a:line == l:start_line && a:col >= l:start_col)) &&
              \ (a:line < l:end_line || (a:line == l:end_line && a:col < l:end_col))
            let l:distance = abs(l:start_col - a:col)
            if l:closest_distance < 0 || l:distance < l:closest_distance
                let l:closest_diagnostic = l:diagnostic
                let l:closest_distance = l:distance
            endif
        endif
    endfor

    if !empty(l:closest_diagnostic) || !get(l:options, 'line_fallback', v:false)
        return l:closest_diagnostic
    endif

    return s:get_first_diagnostic_on_line(a:diagnostics, a:line)
endfunction

function! s:get_first_diagnostic_on_line(diagnostics, line) abort
    let l:first_diagnostic = {}
    let l:first_line = -1
    let l:first_col = -1

    for l:diagnostic in a:diagnostics
        let [l:start_line, l:start_col] = lsp#utils#position#lsp_to_vim('%', l:diagnostic['range']['start'])
        let [l:end_line, l:end_col] = lsp#utils#position#lsp_to_vim('%', l:diagnostic['range']['end'])

        if !s:diagnostic_overlaps_line(a:line, l:start_line, l:start_col, l:end_line, l:end_col)
            continue
        endif

        if empty(l:first_diagnostic) ||
              \ l:start_line < l:first_line ||
              \ (l:start_line == l:first_line && l:start_col < l:first_col)
            let l:first_diagnostic = l:diagnostic
            let l:first_line = l:start_line
            let l:first_col = l:start_col
        endif
    endfor

    return l:first_diagnostic
endfunction

function! s:diagnostic_overlaps_line(line, start_line, start_col, end_line, end_col) abort
    if a:line < a:start_line || a:line > a:end_line
        return v:false
    endif

    if a:start_line == a:end_line
        return a:end_col > a:start_col
    endif

    if a:line == a:end_line
        return a:end_col > 1
    endif

    return v:true
endfunction
