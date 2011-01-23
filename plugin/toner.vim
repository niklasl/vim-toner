" toner.vim - toning vim highlight colors
" License and details: <../doc/toner.txt>.

command! -bang -nargs=* Toner call toner#toner("<bang>", <f-args>)
command! -nargs=0 TonerIncr call toner#tone(1)
command! -nargs=0 TonerDecr call toner#tone(-1)
command! -nargs=* TonerSet call toner#set(<q-args>)
command! -nargs=0 TonerShow echo toner#getGroupAtPosition() . toner#getSettings('.')
command! -nargs=0 TonerCopy call toner#copy()
command! -nargs=? TonerPaste call toner#paste(<f-args>)
command! -nargs=0 TonerSave call toner#save()

command! -bang -nargs=* TonerMap call toner#map(<f-args>, <bang>0)
command! -nargs=0 TonerUnmap call toner#unmap()

