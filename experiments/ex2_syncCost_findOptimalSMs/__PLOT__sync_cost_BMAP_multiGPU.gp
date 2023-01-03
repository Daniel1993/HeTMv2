set terminal dumb

# ARG1 --> location of the data
# ARG2 --> output file

set grid ytics
set fit results

# stats <FILENAME_HERE> using <COL_NB_HERE> nooutput
# available: STATS_max, STATS_min (check other measures)

if (ARG2[strlen(ARG2)-2:] eq 'tex') {
    set terminal cairolatex size 2.80,2.0
    set output sprintf("%s_%s.tex", ARG2[:strlen(ARG2)-4], ARG3)
} else { if (ARG2[strlen(ARG2)-2:] eq 'pdf') {
    set terminal pdf size 5,4
    set output sprintf("%s_%s.pdf", ARG2[:strlen(ARG2)-4], ARG3)
} else { if (ARG2[strlen(ARG2)-2:] eq 'jpg') {
    set terminal jpeg enhanced large size 800,560
    set output sprintf("%s_%s.jpg", ARG2[:strlen(ARG2)-4], ARG3)
    # set xtics rotate by 20
} else {
    set terminal pngcairo noenhanced size 800,560
    set output sprintf("%s_%s.png", ARG2[:strlen(ARG2)-4], ARG3)
}}}

set ylabel "Throughput" font ",14" tc lt 0 #offset 2.7,-0.0
set xlabel "Nb. Blocks" font ",14" tc lt 0 #offset 2.7,-0.0
set key left

plot \
     sprintf("%s/BMAP_1GPU_w%s.avg", ARG1, ARG3)              using 3:18 notitle with linespoints linecolor rgbcolor "#FF0000" pt 1 lw 2 ps 0.8, \
     sprintf("%s/CPUonly_w%s.avg", ARG1, ARG3) using ($0*61-60):18 notitle with linespoints linecolor rgbcolor "#13FF03" dashtype '-' pt 6 lw 1 ps 0.8, \
     sprintf("%s/GPUonly_w%s.avg", ARG1, ARG3) using 3:18 notitle with linespoints linecolor rgbcolor "#13C3C3" dashtype '-' pt 4 lw 1 ps 0.8, \
     1/0 with linespoints linecolor rgbcolor "#FF0000"  pt 1 lw 3 ps 1 ti "SHeTM 1GPU", \
     1/0 with linespoints linecolor rgbcolor "#13FF03"  dashtype '-' pt 6 lw 3 ps 1 ti "CPU only", \
     1/0 with linespoints linecolor rgbcolor "#13C3C3"  dashtype '-' pt 4 lw 3 ps 1 ti "GPU only" \


