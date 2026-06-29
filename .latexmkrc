$out_dir = '.latexbuild';
$aux_dir = '.latexbuild';

$pdf_mode = 4;
$lualatex = 'lualatex -synctex=1 -interaction=nonstopmode -file-line-error %O %S';

$success_cmd = 'cp .latexbuild/main.pdf main.pdf';