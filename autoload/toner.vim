" toner.vim - toning vim highlight colors
" License and details: <../doc/toner.txt>.


let s:defaults = { 'dimension': 'h', 'parts': ['fg'], 'group': '.', 'amount': 2 }
let s:state = deepcopy(s:defaults)

let s:dimensions = ['h', 's', 'l']
let s:parts = ['fg', 'bg']

""
" [h s l] [fg] [bg] [. *] [GROUP] [AMOUNT]
"
func! toner#toner(bang, ...)
  if a:bang == '!'
    let s:state = deepcopy(s:defaults)
  elseif a:0
    let new_parts = []
    for arg in a:000
      if arg =~ '^\d\+$'
        let s:state.amount = str2nr(arg)
      elseif index(s:dimensions, arg) > -1
        let s:state.dimension = arg
      elseif index(s:parts, arg) > -1
        call add(new_parts, arg)
      else
        let s:state.group = arg
      endif
    endfor
    if len(new_parts)
      let s:state.parts = new_parts
    endif
  endif
  echo printf("Toner: group: %s, parts: [%s], dimension: %s, amount: %s",
        \ s:state.group, join(s:state.parts, ', '),
        \ s:state.dimension, s:state.amount)
endfunc


func! toner#tone(multiplier)
  let dim = s:state.dimension
  let parts = s:state.parts
  let amount = s:state.amount * a:multiplier
  let groups = toner#getSelectedGroups()
  for group in groups
    call s:lib.rotate(group, dim, parts, amount)
  endfor
  if len(groups) == 1
    echo printf("Tone %s: %s on [%s] by %s",
          \ group, join(parts, ', '), dim, amount)
  endif
endfunc

func! toner#set(settings)
  let groups = toner#getSelectedGroups()
  for group in groups
    let cmd = printf('hi %s %s', group, a:settings)
    exec cmd
    echo cmd
  endfor
endfunc


func! toner#getSelectedGroups()
  let selected = s:state.group
  if selected == '.'
    return [ toner#getGroupAtPosition() ]
  elseif s:state.group == '*'
    return toner#getAllGroups()
  else
    return [ s:state.group ]
  endif
endfunc

func! toner#getAllGroups()
  redir => highlights
  silent hi
  redir END
  let groups = []
  for line in split(highlights, '\n')
      if line =~ '\v^\w*>.+gui(fg|bg)'
        let name = matchstr(line, '^\w*')
        call add(groups, name)
      endif
  endfor
  return groups
endfunc

func! toner#getGroupAtPosition()
  let group = synIDattr(synIDtrans(synID(line("."), col("."), 1)), "name")
  if group == ''
    let group = 'Normal'
  endif
  return group
endfunc

func! toner#getSettings(group)
  let groupId = hlID(a:group == '.'? toner#getGroupAtPosition() : a:group)
  let settings = ''
  for part in ['fg', 'bg']
    let value = synIDattr(groupId, part.'#')
    if value != ''
      let settings .= printf(' gui%s=%s', part, value)
    endif
  endfor
  let fontattrs = []
  for attr in ['bold', 'italic', 'reverse', 'standout', 'underline', 'undercurl']
    if synIDattr(groupId, attr)
      call add(fontattrs, attr)
    endif
  endfor
  if len(fontattrs)
    let settings .= ' gui=' . join(fontattrs, ',')
  endif
  return settings
endfunc


let s:hlcopy = ''

func! toner#copy(...)
  let s:hlcopy = toner#getSettings(a:0? a:1 : '.')
  return s:hlcopy
endfunc

func! toner#paste(...)
  let group = toner#getGroupAtPosition()
  let hlcopy = s:hlcopy
  if hlcopy != ''
    if ! a:0 || a:1 != '_'
      call toner#copy()
    endif
    exec printf('hi %s %s', group, hlcopy)
  endif
  return s:hlcopy
endfunc


func! toner#save()
  redir => highlights
  silent hi
  redir END
  if 0 " opt. file...
    "exec 'sp ' . fname
  else
    wincmd n
  endif
  silent put! =highlights
  silent g/^\l\l/d
  silent g/ cleared$/d
  silent g/ links to /d
  silent %s/\<xxx //g
  silent %s/^\(.\)/hi \1/g
  if 1 " skip term settings
    silent %s/ \w\?term\w*=\S\+//g
  endif
  0
  silent put! ='hi clear'
  silent put ='set background=' " TODO: curr_l <= 0.5? 'dark' : 'light'
  silent put ='let g:colors_name = \"\"'
  setfiletype vim
endfunc

let s:mappings = {}

func! toner#map(incrmap, decrmap, force)
  let curr_mappings = {}
  for mapping in [a:incrmap, a:decrmap]
    let current = maparg(mapping, 'n')
    let curr_mappings[mapping] = current
  endfor
  if !a:force && count(values(curr_mappings), '') != 2
    echohl WarningMsg
    echo "Mappings already exist (add ! to override)"
    echohl None
    return
  endif
  let s:mappings = curr_mappings
  exec "nnoremap ". a:incrmap ." :TonerIncr<CR>"
  exec "nnoremap ". a:decrmap ." :TonerDecr<CR>"
endfunc

func! toner#unmap()
  for [key, value] in items(s:mappings)
    if value == ''
      exec "nunmap " . key
    else
      exec printf("nnoremap %s %s", key, value)
    endif
  endfor
endfunc

""
" This lib part is from huerotation.vim (Vim Script #2283) by Yukihiro
" Nakadaira. See <http://www.vim.org/scripts/script.php?script_id=2283>.
"

let s:lib = {}

func s:lib.rotate(group, dimension, parts, amount)
  let hl = ''
  for part in a:parts
    let current = synIDattr(hlID(a:group), part.'#')
    if current != ''
      let value = self.rotate_hex(a:dimension, current, a:amount)
      let hl .= printf(' gui%s=%s', part, value)
    endif
  endfor
  if hl != ''
    exec 'hi ' . a:group . hl
  endif
endfunc

func s:lib.rotate_hex(dimension, color, amount)
  let [_0, x, r, g, b; _] = matchlist(a:color, '\v(#)?(\x\x)(\x\x)(\x\x)')
  let r = str2nr(r, 16)
  let g = str2nr(g, 16)
  let b = str2nr(b, 16)
  let [r, g, b] = self.rotate_rgb(a:dimension, r, g, b, a:amount)
  return printf("%s%02X%02X%02X", x, r, g, b)
endfunc

"" TODO
" was rotate_hue_rgb. Now saturation and light don't rotate (but instead
" have a floor and ceiling), but the amount ratio might be quite off.
" Should do my math here..
"
func s:lib.rotate_rgb(dimension, r, g, b, amount)
  let [h, s, l] = self.rgb2hsl(a:r, a:g, a:b)
  let values = {'h': h, 's': s, 'l': l}
  let value = values[a:dimension]
  if a:dimension == 'h'
    let value = value + a:amount / 360.0
    while value > 1
      let value = value - 1.0
    endwhile
    while value < 0
      let value = value + 1.0
    endwhile
  else
    let value = value + a:amount / 100.0
    if value > 1
      let value = 1
    elseif value < 0
      let value = 0
    endif
  endif
  let values[a:dimension] = value
  return self.hsl2rgb(values.h, values.s, values.l)
endfunc

func s:lib.rgb2hsl(r, g, b)
  let var_r = a:r / 255.0
  let var_g = a:g / 255.0
  let var_b = a:b / 255.0

  let var_min = self.min([var_r, var_g, var_b])
  let var_max = self.max([var_r, var_g, var_b])
  let del_max = var_max - var_min

  let l = (var_max + var_min) / 2.0

  if del_max == 0
    let h = 0.0
    let s = 0.0
  else
    if l < 0.5
      let s = del_max / (var_max + var_min)
    else
      let s = del_max / ((2.0 - var_max) - var_min)
    endif

    let del_r = ((var_max - var_r) / 6.0 + del_max / 2.0) / del_max
    let del_g = ((var_max - var_g) / 6.0 + del_max / 2.0) / del_max
    let del_b = ((var_max - var_b) / 6.0 + del_max / 2.0) / del_max

    if var_r == var_max
      let h = del_b - del_g
    elseif var_g == var_max
      let h = (1.0 / 3.0) + del_r - del_b
    elseif var_b == var_max
      let h = (2.0 / 3.0) + del_g - del_r
    endif

    if h < 0
      let h = h + 1.0
    endif

    if h > 1
      let h = h - 1.0
    endif
  endif

  return [h, s, l]
endfunc

func s:lib.hsl2rgb(h, s, l)
  let [h, s, l] = [a:h, a:s, a:l]
  if s == 0
    let r = l * 255.0
    let g = l * 255.0
    let b = l * 255.0
  else
    if l < 0.5
      let var_2 = l * (1.0 + s)
    else
      let var_2 = (l + s) - s * l
    endif
    let var_1 = 2.0 * l - var_2
    let r = 255.0 * self.hue2rgb(var_1, var_2, h + (1.0 / 3.0))
    let g = 255.0 * self.hue2rgb(var_1, var_2, h)
    let b = 255.0 * self.hue2rgb(var_1, var_2, h - (1.0 / 3.0))
  endif
  return [float2nr(r), float2nr(g), float2nr(b)]
endfunc

func s:lib.hue2rgb(v1, v2, vh)
  let [v1, v2, vh] = [a:v1, a:v2, a:vh]
  if vh < 0
    let vh = vh + 1.0
  endif
  if vh > 1
    let vh = vh - 1.0
  endif
  if 6.0 * vh < 1
    return v1 + ((v2 - v1) * 6.0 * vh)
  elseif 2.0 * vh < 1
    return v2
  elseif 3.0 * vh < 2
    return v1 + ((v2 - v1) * (2.0 / 3.0 - vh) * 6.0)
  endif
  return v1
endfunc

" NOTE: max() and min() don't work for Float..
func s:lib.max(lst)
  let a = a:lst[0]
  for n in a:lst
    if a < n
      let a = n
    endif
  endfor
  return a
endfunc

func s:lib.min(lst)
  let a = a:lst[0]
  for n in a:lst
    if a > n
      let a = n
    endif
  endfor
  return a
endfunc

